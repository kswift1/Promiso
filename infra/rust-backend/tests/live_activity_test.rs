use chrono::{DateTime, Duration, Utc};
use http_body_util::BodyExt;
use promiso_backend::errors::AppError;
use promiso_backend::models::live_activity::{
    LiveActivityJob, LiveActivityJobPayload, LiveActivityJobStatus, LiveActivityJobType,
    LiveActivityParticipant, LiveActivitySender, UpdateScheduleLiveActivityRequest,
};
use promiso_backend::models::notification::{FcmMessage, NotificationType, PushResult, PushSender};
use promiso_backend::models::schedule::Schedule;
use promiso_backend::services::live_activity_service::{
    LiveActivityJobScheduler, ScheduledLiveActivityJob,
};
use promiso_backend::services::{live_activity_service, vote_live_activity_service};
use sqlx::PgPool;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

async fn insert_test_user(pool: &PgPool, id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(id)
    .bind(nickname)
    .bind(nickname)
    .bind(format!("provider-{id}"))
    .bind(format!("{id}@test.com"))
    .execute(pool)
    .await
    .expect("Failed to insert test user");
}

async fn create_test_group(pool: &PgPool, creator_id: &str, name: &str) -> Uuid {
    let group_id: (Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, description, image_url, last_activity_at) \
         VALUES ($1, UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6)), 10, NULL, NULL, NOW()) \
         RETURNING id",
    )
    .bind(name)
    .fetch_one(pool)
    .await
    .expect("Failed to insert test group");

    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')")
        .bind(group_id.0)
        .bind(creator_id)
        .execute(pool)
        .await
        .expect("Failed to add host to group");

    group_id.0
}

async fn add_member_to_group(pool: &PgPool, group_id: Uuid, user_id: &str) {
    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')")
        .bind(group_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to add member to group");
}

async fn insert_group_schedule(
    pool: &PgPool,
    host_id: &str,
    group_id: Uuid,
    title: &str,
    start_at: DateTime<Utc>,
    tracking_minutes: Option<i16>,
    minimum_participants: i16,
) -> Uuid {
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO schedules (schedule_type, user_id, title, emoji, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline, tracking_start_minutes_before) \
         VALUES ('group'::schedule_type, $1, $2, '📅', $3, $4, $5, TRUE, $3, $6) \
         RETURNING id",
    )
    .bind(host_id)
    .bind(title)
    .bind(start_at)
    .bind(group_id)
    .bind(minimum_participants)
    .bind(tracking_minutes)
    .fetch_one(pool)
    .await
    .expect("Failed to insert schedule");

    row.0
}

async fn accept_schedule(pool: &PgPool, schedule_id: Uuid, user_id: &str) {
    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) \
         VALUES ($1, $2, 'accepted'::vote_status)",
    )
    .bind(schedule_id)
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to insert accepted vote");
}

async fn vote_schedule(pool: &PgPool, schedule_id: Uuid, user_id: &str, status: &str) {
    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) \
         VALUES ($1, $2, $3::vote_status)",
    )
    .bind(schedule_id)
    .bind(user_id)
    .bind(status)
    .execute(pool)
    .await
    .expect("Failed to insert vote");
}

async fn register_push_to_start_token(pool: &PgPool, user_id: &str, device_id: &str, token: &str) {
    let device: (Uuid,) = sqlx::query_as(
        "INSERT INTO devices (user_id, device_id, platform) VALUES ($1, $2, 'ios') RETURNING id",
    )
    .bind(user_id)
    .bind(device_id)
    .fetch_one(pool)
    .await
    .expect("Failed to insert device");

    sqlx::query(
        "INSERT INTO live_activity_endpoints (device_id, push_to_start_token) VALUES ($1, $2)",
    )
    .bind(device.0)
    .bind(token)
    .execute(pool)
    .await
    .expect("Failed to insert live activity endpoint");
}

async fn register_notification_token(pool: &PgPool, user_id: &str, device_id: &str, token: &str) {
    let device: (Uuid,) = sqlx::query_as(
        "INSERT INTO devices (user_id, device_id, platform) VALUES ($1, $2, 'ios') RETURNING id",
    )
    .bind(user_id)
    .bind(device_id)
    .fetch_one(pool)
    .await
    .expect("Failed to insert device");

    sqlx::query(
        "INSERT INTO notification_endpoints (device_id, provider, token) VALUES ($1, 'fcm', $2)",
    )
    .bind(device.0)
    .bind(token)
    .execute(pool)
    .await
    .expect("Failed to insert notification endpoint");
}

async fn load_jobs(pool: &PgPool, schedule_id: Uuid) -> Vec<LiveActivityJob> {
    sqlx::query_as::<_, LiveActivityJob>(
        "SELECT * FROM live_activity_jobs WHERE schedule_id = $1 ORDER BY created_at",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await
    .expect("Failed to load jobs")
}

async fn load_schedule(pool: &PgPool, schedule_id: Uuid) -> Schedule {
    sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_one(pool)
        .await
        .expect("Failed to load schedule")
}

async fn insert_job(
    pool: &PgPool,
    schedule_id: Uuid,
    job_type: LiveActivityJobType,
    scheduled_at: DateTime<Utc>,
    payload: Option<LiveActivityJobPayload>,
) {
    sqlx::query(
        "INSERT INTO live_activity_jobs (schedule_id, job_type, scheduled_at, payload) \
         VALUES ($1, $2, $3, $4)",
    )
    .bind(schedule_id)
    .bind(job_type)
    .bind(scheduled_at)
    .bind(payload.map(|payload| serde_json::to_value(payload).expect("payload encode")))
    .execute(pool)
    .await
    .expect("Failed to insert job");
}

async fn insert_job_returning_id(
    pool: &PgPool,
    schedule_id: Uuid,
    job_type: LiveActivityJobType,
    scheduled_at: DateTime<Utc>,
    payload: Option<LiveActivityJobPayload>,
) -> Uuid {
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO live_activity_jobs (schedule_id, job_type, scheduled_at, payload) \
         VALUES ($1, $2, $3, $4) \
         RETURNING id",
    )
    .bind(schedule_id)
    .bind(job_type)
    .bind(scheduled_at)
    .bind(payload.map(|payload| serde_json::to_value(payload).expect("payload encode")))
    .fetch_one(pool)
    .await
    .expect("Failed to insert job");

    row.0
}

#[derive(Clone)]
struct MockLiveActivityJobScheduler {
    calls: Arc<Mutex<Vec<ScheduledLiveActivityJob>>>,
    should_fail: bool,
}

impl MockLiveActivityJobScheduler {
    fn succeed() -> Self {
        Self {
            calls: Arc::new(Mutex::new(Vec::new())),
            should_fail: false,
        }
    }

    fn fail() -> Self {
        Self {
            calls: Arc::new(Mutex::new(Vec::new())),
            should_fail: true,
        }
    }

    fn calls(&self) -> Vec<ScheduledLiveActivityJob> {
        self.calls.lock().unwrap().clone()
    }
}

#[async_trait::async_trait]
impl LiveActivityJobScheduler for MockLiveActivityJobScheduler {
    async fn enqueue_live_activity_job(
        &self,
        job: ScheduledLiveActivityJob,
    ) -> Result<(), AppError> {
        if self.should_fail {
            return Err(AppError::Internal("cloud task enqueue failed".to_string()));
        }

        self.calls.lock().unwrap().push(job);
        Ok(())
    }
}

#[derive(Default)]
struct MockLiveActivitySender {
    state: Arc<Mutex<MockLiveActivityState>>,
}

#[derive(Default)]
struct MockLiveActivityState {
    created_channels: usize,
    push_to_start_calls: Vec<(String, serde_json::Value)>,
    broadcast_calls: Vec<(String, serde_json::Value)>,
}

impl MockLiveActivitySender {
    fn new() -> Self {
        Self::default()
    }

    fn state(&self) -> MockLiveActivityStateSnapshot {
        let state = self.state.lock().unwrap();
        MockLiveActivityStateSnapshot {
            created_channels: state.created_channels,
            push_to_start_calls: state.push_to_start_calls.clone(),
            broadcast_calls: state.broadcast_calls.clone(),
        }
    }
}

struct MockLiveActivityStateSnapshot {
    created_channels: usize,
    push_to_start_calls: Vec<(String, serde_json::Value)>,
    broadcast_calls: Vec<(String, serde_json::Value)>,
}

#[derive(Default)]
struct FailingPushToStartLiveActivitySender {
    state: Arc<Mutex<MockLiveActivityState>>,
}

impl FailingPushToStartLiveActivitySender {
    fn new() -> Self {
        Self::default()
    }
}

#[async_trait::async_trait]
impl LiveActivitySender for MockLiveActivitySender {
    async fn create_channel(&self) -> Result<String, promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state.created_channels += 1;
        Ok("channel-test-1".to_string())
    }

    async fn send_push_to_start(
        &self,
        push_to_start_token: &str,
        payload: &serde_json::Value,
    ) -> Result<(), promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state
            .push_to_start_calls
            .push((push_to_start_token.to_string(), payload.clone()));
        Ok(())
    }

    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &serde_json::Value,
    ) -> Result<(), promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state
            .broadcast_calls
            .push((channel_id.to_string(), payload.clone()));
        Ok(())
    }
}

#[async_trait::async_trait]
impl LiveActivitySender for FailingPushToStartLiveActivitySender {
    async fn create_channel(&self) -> Result<String, promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state.created_channels += 1;
        Ok("channel-test-fail".to_string())
    }

    async fn send_push_to_start(
        &self,
        push_to_start_token: &str,
        payload: &serde_json::Value,
    ) -> Result<(), promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state
            .push_to_start_calls
            .push((push_to_start_token.to_string(), payload.clone()));
        Err(promiso_backend::errors::AppError::Internal(
            "push to start failed".to_string(),
        ))
    }

    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &serde_json::Value,
    ) -> Result<(), promiso_backend::errors::AppError> {
        let mut state = self.state.lock().unwrap();
        state
            .broadcast_calls
            .push((channel_id.to_string(), payload.clone()));
        Ok(())
    }
}

#[derive(Default)]
struct MockPushSender {
    calls: Arc<Mutex<Vec<(Vec<String>, FcmMessage)>>>,
}

impl MockPushSender {
    fn new() -> Self {
        Self::default()
    }

    fn calls(&self) -> Vec<(Vec<String>, FcmMessage)> {
        self.calls.lock().unwrap().clone()
    }
}

#[async_trait::async_trait]
impl PushSender for MockPushSender {
    async fn send_multicast(&self, tokens: &[String], message: &FcmMessage) -> PushResult {
        self.calls
            .lock()
            .unwrap()
            .push((tokens.to_vec(), message.clone()));

        PushResult {
            success: true,
            success_count: tokens.len() as i32,
            failure_count: 0,
            delivered_tokens: tokens.to_vec(),
        }
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn sync_schedule_jobs_creates_pending_start_job(pool: PgPool) {
    insert_test_user(&pool, "host_sync", "호스트").await;
    insert_test_user(&pool, "member_sync", "멤버").await;
    let group_id = create_test_group(&pool, "host_sync", "라이브액티비티 그룹").await;
    add_member_to_group(&pool, group_id, "member_sync").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_sync",
        group_id,
        "실시간 공유 일정",
        Utc::now() + Duration::minutes(20),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_sync").await;
    accept_schedule(&pool, schedule_id, "member_sync").await;

    live_activity_service::sync_schedule_jobs(&pool, schedule_id)
        .await
        .expect("sync should succeed");

    let jobs = load_jobs(&pool, schedule_id).await;
    assert_eq!(jobs.len(), 1);
    assert_eq!(jobs[0].job_type, LiveActivityJobType::Start);
    assert_eq!(jobs[0].status, LiveActivityJobStatus::Pending);
    assert!(jobs[0].scheduled_at <= Utc::now());
}

#[sqlx::test(migrations = "./migrations")]
async fn sync_schedule_jobs_enqueues_cloud_task_for_created_start_job(pool: PgPool) {
    insert_test_user(&pool, "host_task", "호스트").await;
    insert_test_user(&pool, "member_task", "멤버").await;
    let group_id = create_test_group(&pool, "host_task", "태스크 그룹").await;
    add_member_to_group(&pool, group_id, "member_task").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_task",
        group_id,
        "태스크 예약 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_task").await;
    accept_schedule(&pool, schedule_id, "member_task").await;

    let scheduler = MockLiveActivityJobScheduler::succeed();
    live_activity_service::sync_schedule_jobs_with_scheduler(&pool, &scheduler, schedule_id)
        .await
        .expect("sync should enqueue cloud task");

    let jobs = load_jobs(&pool, schedule_id).await;
    let pending_start_jobs: Vec<_> = jobs
        .iter()
        .filter(|job| {
            job.job_type == LiveActivityJobType::Start
                && job.status == LiveActivityJobStatus::Pending
        })
        .collect();
    assert_eq!(pending_start_jobs.len(), 1);

    let calls = scheduler.calls();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].id, pending_start_jobs[0].id);
    assert_eq!(calls[0].schedule_id, schedule_id);
    assert_eq!(calls[0].job_type, LiveActivityJobType::Start);
    assert_eq!(calls[0].scheduled_at, pending_start_jobs[0].scheduled_at);
}

#[sqlx::test(migrations = "./migrations")]
async fn sync_schedule_jobs_does_not_leave_pending_job_when_cloud_task_enqueue_fails(pool: PgPool) {
    insert_test_user(&pool, "host_task_fail", "호스트").await;
    insert_test_user(&pool, "member_task_fail", "멤버").await;
    let group_id = create_test_group(&pool, "host_task_fail", "태스크 실패 그룹").await;
    add_member_to_group(&pool, group_id, "member_task_fail").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_task_fail",
        group_id,
        "태스크 실패 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_task_fail").await;
    accept_schedule(&pool, schedule_id, "member_task_fail").await;

    let scheduler = MockLiveActivityJobScheduler::fail();
    let error =
        live_activity_service::sync_schedule_jobs_with_scheduler(&pool, &scheduler, schedule_id)
            .await
            .expect_err("sync should fail when cloud task enqueue fails");
    assert!(matches!(error, AppError::Internal(_)));

    let pending_start_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) \
         FROM live_activity_jobs \
         WHERE schedule_id = $1 \
           AND job_type = 'start'::live_activity_job_type \
           AND status = 'pending'::live_activity_job_status",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("Failed to count pending start jobs");
    assert_eq!(pending_start_count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn process_due_start_job_stores_channel_and_schedules_followups(pool: PgPool) {
    insert_test_user(&pool, "host_start", "호스트").await;
    insert_test_user(&pool, "member_start", "멤버").await;
    let group_id = create_test_group(&pool, "host_start", "라이브액티비티 그룹").await;
    add_member_to_group(&pool, group_id, "member_start").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_start",
        group_id,
        "시작 테스트 일정",
        Utc::now() + Duration::minutes(20),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_start").await;
    accept_schedule(&pool, schedule_id, "member_start").await;
    register_push_to_start_token(&pool, "host_start", "host-device", "token-host").await;
    register_push_to_start_token(&pool, "member_start", "member-device", "token-member").await;

    live_activity_service::sync_schedule_jobs(&pool, schedule_id)
        .await
        .expect("sync should succeed");

    let live_sender = MockLiveActivitySender::new();
    let push_sender = MockPushSender::new();
    live_activity_service::process_due_jobs(&pool, &live_sender, &push_sender)
        .await
        .expect("job processing should succeed");

    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(
        schedule.live_activity_channel_id.as_deref(),
        Some("channel-test-1")
    );
    assert!(schedule.live_activity_started_at.is_some());

    let jobs = load_jobs(&pool, schedule_id).await;
    assert_eq!(
        jobs.iter()
            .filter(|job| job.status == LiveActivityJobStatus::Pending)
            .count(),
        2
    );
    assert!(jobs
        .iter()
        .any(|job| job.job_type == LiveActivityJobType::End
            && job.status == LiveActivityJobStatus::Pending));
    assert!(jobs
        .iter()
        .any(|job| job.job_type == LiveActivityJobType::Nudge
            && job.status == LiveActivityJobStatus::Pending));

    let sender_state = live_sender.state();
    assert_eq!(sender_state.created_channels, 1);
    assert_eq!(sender_state.push_to_start_calls.len(), 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_live_activity_job_processes_only_requested_due_job(pool: PgPool) {
    insert_test_user(&pool, "host_dispatch", "호스트").await;
    insert_test_user(&pool, "member_dispatch", "멤버").await;
    let group_id = create_test_group(&pool, "host_dispatch", "디스패치 그룹").await;
    add_member_to_group(&pool, group_id, "member_dispatch").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_dispatch",
        group_id,
        "디스패치 일정",
        Utc::now() + Duration::minutes(20),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_dispatch").await;
    accept_schedule(&pool, schedule_id, "member_dispatch").await;
    register_push_to_start_token(&pool, "host_dispatch", "host-dispatch-device", "token-host")
        .await;
    register_push_to_start_token(
        &pool,
        "member_dispatch",
        "member-dispatch-device",
        "token-member",
    )
    .await;

    let job_id = insert_job_returning_id(
        &pool,
        schedule_id,
        LiveActivityJobType::Start,
        Utc::now() - Duration::minutes(1),
        None,
    )
    .await;

    let live_sender = MockLiveActivitySender::new();
    let push_sender = MockPushSender::new();
    let result = live_activity_service::dispatch_live_activity_job(
        &pool,
        &live_sender,
        &push_sender,
        job_id,
    )
    .await
    .expect("requested job dispatch should succeed");

    assert!(result.processed);
    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(
        schedule.live_activity_channel_id.as_deref(),
        Some("channel-test-1")
    );

    let jobs = load_jobs(&pool, schedule_id).await;
    let dispatched_job = jobs.iter().find(|job| job.id == job_id).unwrap();
    assert_eq!(dispatched_job.status, LiveActivityJobStatus::Succeeded);
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_live_activity_all_arrived_schedules_end_job(pool: PgPool) {
    insert_test_user(&pool, "host_eta", "호스트").await;
    insert_test_user(&pool, "member_eta", "멤버").await;
    let group_id = create_test_group(&pool, "host_eta", "ETA 그룹").await;
    add_member_to_group(&pool, group_id, "member_eta").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_eta",
        group_id,
        "ETA 테스트 일정",
        Utc::now() + Duration::minutes(40),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_eta").await;
    accept_schedule(&pool, schedule_id, "member_eta").await;

    sqlx::query(
        "UPDATE schedules SET live_activity_channel_id = $1, live_activity_started_at = NOW() WHERE id = $2",
    )
    .bind("channel-test-eta")
    .bind(schedule_id)
    .execute(&pool)
    .await
    .expect("Failed to update schedule live activity state");

    let live_sender = MockLiveActivitySender::new();
    let response = live_activity_service::update_schedule_live_activity(
        &pool,
        &live_sender,
        schedule_id,
        "host_eta",
        UpdateScheduleLiveActivityRequest {
            channel_id: "channel-test-eta".to_string(),
            participants: vec![
                LiveActivityParticipant {
                    id: "host_eta".to_string(),
                    name: "호스트".to_string(),
                    estimated_arrival_minutes: Some(0),
                },
                LiveActivityParticipant {
                    id: "member_eta".to_string(),
                    name: "멤버".to_string(),
                    estimated_arrival_minutes: Some(0),
                },
            ],
            tracking_duration_minutes: Some(30),
        },
    )
    .await
    .expect("eta update should succeed");

    assert!(response.success);

    let sender_state = live_sender.state();
    assert_eq!(sender_state.broadcast_calls.len(), 1);
    assert_eq!(sender_state.broadcast_calls[0].0, "channel-test-eta");
    assert_eq!(
        sender_state.broadcast_calls[0].1["aps"]["alert"]["title"],
        serde_json::json!("✅ 모두 도착!")
    );

    let jobs = load_jobs(&pool, schedule_id).await;
    assert!(jobs
        .iter()
        .any(|job| job.job_type == LiveActivityJobType::End
            && job.status == LiveActivityJobStatus::Pending));
}

#[sqlx::test(migrations = "./migrations")]
async fn regression_update_schedule_live_activity_reverts_end_job_when_all_arrived_state_clears(
    pool: PgPool,
) {
    insert_test_user(&pool, "host_eta_revert", "호스트").await;
    insert_test_user(&pool, "member_eta_revert", "멤버").await;
    let group_id = create_test_group(&pool, "host_eta_revert", "ETA 되돌림 그룹").await;
    add_member_to_group(&pool, group_id, "member_eta_revert").await;

    let start_at = Utc::now() + Duration::minutes(40);
    let schedule_id = insert_group_schedule(
        &pool,
        "host_eta_revert",
        group_id,
        "ETA 되돌림 일정",
        start_at,
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_eta_revert").await;
    accept_schedule(&pool, schedule_id, "member_eta_revert").await;

    sqlx::query(
        "UPDATE schedules SET live_activity_channel_id = $1, live_activity_started_at = NOW() WHERE id = $2",
    )
    .bind("channel-test-eta-revert")
    .bind(schedule_id)
    .execute(&pool)
    .await
    .expect("Failed to update schedule live activity state");

    let live_sender = MockLiveActivitySender::new();
    live_activity_service::update_schedule_live_activity(
        &pool,
        &live_sender,
        schedule_id,
        "host_eta_revert",
        UpdateScheduleLiveActivityRequest {
            channel_id: "channel-test-eta-revert".to_string(),
            participants: vec![
                LiveActivityParticipant {
                    id: "host_eta_revert".to_string(),
                    name: "호스트".to_string(),
                    estimated_arrival_minutes: Some(0),
                },
                LiveActivityParticipant {
                    id: "member_eta_revert".to_string(),
                    name: "멤버".to_string(),
                    estimated_arrival_minutes: Some(0),
                },
            ],
            tracking_duration_minutes: Some(30),
        },
    )
    .await
    .expect("all arrived update should succeed");

    live_activity_service::update_schedule_live_activity(
        &pool,
        &live_sender,
        schedule_id,
        "host_eta_revert",
        UpdateScheduleLiveActivityRequest {
            channel_id: "channel-test-eta-revert".to_string(),
            participants: vec![
                LiveActivityParticipant {
                    id: "host_eta_revert".to_string(),
                    name: "호스트".to_string(),
                    estimated_arrival_minutes: Some(0),
                },
                LiveActivityParticipant {
                    id: "member_eta_revert".to_string(),
                    name: "멤버".to_string(),
                    estimated_arrival_minutes: Some(5),
                },
            ],
            tracking_duration_minutes: Some(30),
        },
    )
    .await
    .expect("reverted eta update should succeed");

    let pending_end_jobs: Vec<LiveActivityJob> = load_jobs(&pool, schedule_id)
        .await
        .into_iter()
        .filter(|job| {
            job.job_type == LiveActivityJobType::End && job.status == LiveActivityJobStatus::Pending
        })
        .collect();
    assert_eq!(
        pending_end_jobs.len(),
        1,
        "pending end job should be restored"
    );
    assert!(
        pending_end_jobs[0].scheduled_at >= start_at + Duration::minutes(30) - Duration::minutes(1),
        "all-arrived override should be reverted to the default end time"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn process_due_nudge_job_sends_location_sharing_push(pool: PgPool) {
    insert_test_user(&pool, "host_nudge", "호스트").await;
    insert_test_user(&pool, "member_nudge", "멤버").await;
    let group_id = create_test_group(&pool, "host_nudge", "넛지 그룹").await;
    add_member_to_group(&pool, group_id, "member_nudge").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_nudge",
        group_id,
        "넛지 테스트 일정",
        Utc::now() + Duration::minutes(15),
        Some(30),
        2,
    )
    .await;
    accept_schedule(&pool, schedule_id, "host_nudge").await;
    accept_schedule(&pool, schedule_id, "member_nudge").await;
    register_push_to_start_token(&pool, "host_nudge", "host-device", "token-host").await;
    register_push_to_start_token(&pool, "member_nudge", "member-device", "token-member").await;
    register_notification_token(&pool, "host_nudge", "host-device-fcm", "fcm-host").await;
    register_notification_token(&pool, "member_nudge", "member-device-fcm", "fcm-member").await;

    sqlx::query(
        "UPDATE schedules SET live_activity_channel_id = $1, live_activity_started_at = NOW() WHERE id = $2",
    )
    .bind("channel-test-nudge")
    .bind(schedule_id)
    .execute(&pool)
    .await
    .expect("Failed to mark schedule started");

    insert_job(
        &pool,
        schedule_id,
        LiveActivityJobType::Nudge,
        Utc::now() - Duration::minutes(1),
        None,
    )
    .await;

    let live_sender = MockLiveActivitySender::new();
    let push_sender = MockPushSender::new();
    live_activity_service::process_due_jobs(&pool, &live_sender, &push_sender)
        .await
        .expect("nudge job should succeed");

    let calls = push_sender.calls();
    assert_eq!(calls.len(), 1);
    assert_eq!(
        calls[0].1.notification_type,
        NotificationType::LocationSharingReminder
    );
    assert_eq!(calls[0].0.len(), 2);

    let schedule = load_schedule(&pool, schedule_id).await;
    assert!(schedule.live_activity_nudge_sent_at.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn start_vote_live_activity_stores_channel_and_sends_push_to_start(pool: PgPool) {
    insert_test_user(&pool, "host_vote_start", "호스트").await;
    insert_test_user(&pool, "member_vote_start", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_start", "투표 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_start").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_start",
        group_id,
        "투표 시작 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    sqlx::query("UPDATE schedules SET is_confirmed = FALSE WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .expect("Failed to reset confirmed flag");

    register_push_to_start_token(
        &pool,
        "host_vote_start",
        "host-vote-device",
        "vote-token-host",
    )
    .await;
    register_push_to_start_token(
        &pool,
        "member_vote_start",
        "member-vote-device",
        "vote-token-member",
    )
    .await;

    let live_sender = MockLiveActivitySender::new();
    let response = vote_live_activity_service::start_vote_live_activity(
        &pool,
        &live_sender,
        None,
        schedule_id,
        "host_vote_start",
    )
    .await
    .expect("vote live activity should start");

    assert_eq!(response.success_count, 2);
    assert_eq!(response.failure_count, 0);
    assert_eq!(response.channel_id.as_deref(), Some("channel-test-1"));

    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(
        schedule.vote_live_activity_channel_id.as_deref(),
        Some("channel-test-1")
    );
    assert!(schedule.vote_live_activity_started_at.is_some());

    let sender_state = live_sender.state();
    assert_eq!(sender_state.push_to_start_calls.len(), 2);
    assert_eq!(
        sender_state.push_to_start_calls[0].1["aps"]["attributes-type"],
        serde_json::json!("VoteActivityAttributes")
    );
    assert_eq!(
        sender_state.push_to_start_calls[0].1["aps"]["content-state"]["pendingCount"],
        serde_json::json!(1)
    );
    assert_eq!(
        sender_state.push_to_start_calls[0].1["aps"]["content-state"]["acceptedMembers"][0]["id"],
        serde_json::json!("host_vote_start")
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn regression_start_vote_live_activity_without_targets_does_not_mutate_host_vote(
    pool: PgPool,
) {
    insert_test_user(&pool, "host_vote_no_targets", "호스트").await;
    insert_test_user(&pool, "member_vote_no_targets", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_no_targets", "투표 토큰 없음 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_no_targets").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_no_targets",
        group_id,
        "투표 토큰 없음 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    sqlx::query("UPDATE schedules SET is_confirmed = FALSE WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .expect("Failed to reset confirmed flag");

    let live_sender = MockLiveActivitySender::new();
    let response = vote_live_activity_service::start_vote_live_activity(
        &pool,
        &live_sender,
        None,
        schedule_id,
        "host_vote_no_targets",
    )
    .await
    .expect("vote live activity should return without targets");

    assert_eq!(response.success_count, 0);
    assert!(response.channel_id.is_none());

    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(schedule.is_confirmed, Some(false));
    let host_vote_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2",
    )
    .bind(schedule_id)
    .bind("host_vote_no_targets")
    .fetch_one(&pool)
    .await
    .expect("Failed to count host votes");
    assert_eq!(
        host_vote_count.0, 0,
        "host vote must not be persisted on no-target return"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn regression_start_vote_live_activity_syncs_schedule_jobs_after_host_vote_confirms(
    pool: PgPool,
) {
    insert_test_user(&pool, "host_vote_sync", "호스트").await;
    insert_test_user(&pool, "member_vote_sync", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_sync", "투표 동기화 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_sync").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_sync",
        group_id,
        "투표 동기화 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    sqlx::query("UPDATE schedules SET is_confirmed = FALSE WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .expect("Failed to reset confirmed flag");
    vote_schedule(&pool, schedule_id, "member_vote_sync", "accepted").await;

    register_push_to_start_token(
        &pool,
        "host_vote_sync",
        "host-vote-sync-device",
        "vote-sync-token-host",
    )
    .await;
    register_push_to_start_token(
        &pool,
        "member_vote_sync",
        "member-vote-sync-device",
        "vote-sync-token-member",
    )
    .await;

    let live_sender = MockLiveActivitySender::new();
    let push_sender = MockPushSender::new();
    vote_live_activity_service::start_vote_live_activity(
        &pool,
        &live_sender,
        Some(&push_sender),
        schedule_id,
        "host_vote_sync",
    )
    .await
    .expect("vote live activity should start");

    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(schedule.is_confirmed, Some(true));

    let pending_start_jobs: Vec<LiveActivityJob> = load_jobs(&pool, schedule_id)
        .await
        .into_iter()
        .filter(|job| {
            job.job_type == LiveActivityJobType::Start
                && job.status == LiveActivityJobStatus::Pending
        })
        .collect();
    assert_eq!(
        pending_start_jobs.len(),
        1,
        "confirming through vote live activity should resync schedule live activity jobs"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn regression_start_vote_live_activity_failure_does_not_persist_host_vote(pool: PgPool) {
    insert_test_user(&pool, "host_vote_fail", "호스트").await;
    insert_test_user(&pool, "member_vote_fail", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_fail", "투표 실패 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_fail").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_fail",
        group_id,
        "투표 실패 일정",
        Utc::now() + Duration::minutes(90),
        Some(30),
        2,
    )
    .await;
    sqlx::query("UPDATE schedules SET is_confirmed = FALSE WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .expect("Failed to reset confirmed flag");

    register_push_to_start_token(
        &pool,
        "host_vote_fail",
        "host-vote-fail-device",
        "vote-fail-token-host",
    )
    .await;
    register_push_to_start_token(
        &pool,
        "member_vote_fail",
        "member-vote-fail-device",
        "vote-fail-token-member",
    )
    .await;

    let live_sender = FailingPushToStartLiveActivitySender::new();
    let error = vote_live_activity_service::start_vote_live_activity(
        &pool,
        &live_sender,
        None,
        schedule_id,
        "host_vote_fail",
    )
    .await
    .expect_err("vote live activity should fail when every push-to-start send fails");
    assert!(matches!(
        error,
        promiso_backend::errors::AppError::Internal(_)
    ));

    let schedule = load_schedule(&pool, schedule_id).await;
    assert_eq!(schedule.is_confirmed, Some(false));
    let host_vote_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2",
    )
    .bind(schedule_id)
    .bind("host_vote_fail")
    .fetch_one(&pool)
    .await
    .expect("Failed to count host votes");
    assert_eq!(
        host_vote_count.0, 0,
        "host vote must not be persisted when all push-to-start sends fail"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn broadcast_vote_state_if_active_marks_vote_activity_finished(pool: PgPool) {
    insert_test_user(&pool, "host_vote_broadcast", "호스트").await;
    insert_test_user(&pool, "member_vote_broadcast", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_broadcast", "투표 브로드캐스트 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_broadcast").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_broadcast",
        group_id,
        "투표 브로드캐스트 일정",
        Utc::now() + Duration::minutes(45),
        Some(30),
        2,
    )
    .await;
    vote_schedule(&pool, schedule_id, "host_vote_broadcast", "accepted").await;
    vote_schedule(&pool, schedule_id, "member_vote_broadcast", "declined").await;

    sqlx::query(
        "UPDATE schedules SET vote_live_activity_channel_id = $1, vote_live_activity_started_at = NOW() \
         WHERE id = $2",
    )
    .bind("vote-channel-broadcast")
    .bind(schedule_id)
    .execute(&pool)
    .await
    .expect("Failed to mark vote live activity started");

    let live_sender = MockLiveActivitySender::new();
    let response = vote_live_activity_service::broadcast_vote_state_if_active(
        &pool,
        &live_sender,
        schedule_id,
    )
    .await
    .expect("vote broadcast should succeed")
    .expect("vote activity should be active");

    assert!(response.content_state.is_finalized);
    assert_eq!(response.content_state.pending_count, 0);

    let sender_state = live_sender.state();
    assert_eq!(sender_state.broadcast_calls.len(), 1);
    assert_eq!(
        sender_state.broadcast_calls[0].1["aps"]["event"],
        serde_json::json!("end")
    );
    assert_eq!(
        sender_state.broadcast_calls[0].1["aps"]["alert"]["title"],
        serde_json::json!("투표가 마감되었습니다")
    );

    let schedule = load_schedule(&pool, schedule_id).await;
    assert!(schedule.vote_live_activity_channel_id.is_none());
    assert!(schedule.vote_live_activity_finalized_at.is_some());
    assert!(schedule.vote_live_activity_ended_at.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn finalize_vote_live_activity_ends_with_host_alert(pool: PgPool) {
    insert_test_user(&pool, "host_vote_finalize", "호스트").await;
    insert_test_user(&pool, "member_vote_finalize", "멤버").await;
    let group_id = create_test_group(&pool, "host_vote_finalize", "투표 마감 그룹").await;
    add_member_to_group(&pool, group_id, "member_vote_finalize").await;

    let schedule_id = insert_group_schedule(
        &pool,
        "host_vote_finalize",
        group_id,
        "투표 마감 일정",
        Utc::now() + Duration::minutes(60),
        Some(30),
        2,
    )
    .await;
    vote_schedule(&pool, schedule_id, "host_vote_finalize", "accepted").await;

    sqlx::query(
        "UPDATE schedules SET vote_live_activity_channel_id = $1, vote_live_activity_started_at = NOW() \
         WHERE id = $2",
    )
    .bind("vote-channel-finalize")
    .bind(schedule_id)
    .execute(&pool)
    .await
    .expect("Failed to mark vote live activity started");

    let live_sender = MockLiveActivitySender::new();
    let response = vote_live_activity_service::finalize_vote_live_activity(
        &pool,
        &live_sender,
        schedule_id,
        "host_vote_finalize",
    )
    .await
    .expect("vote finalize should succeed");

    assert!(response.content_state.is_finalized);
    assert_eq!(response.content_state.pending_count, 1);

    let sender_state = live_sender.state();
    assert_eq!(sender_state.broadcast_calls.len(), 1);
    assert_eq!(
        sender_state.broadcast_calls[0].1["aps"]["alert"]["title"],
        serde_json::json!("호스트가 투표를 마감했습니다")
    );

    let schedule = load_schedule(&pool, schedule_id).await;
    assert!(schedule.vote_live_activity_channel_id.is_none());
    assert!(schedule.vote_live_activity_finalized_at.is_some());
    assert!(schedule.vote_live_activity_ended_at.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn widget_eta_requires_auth_token_header(pool: PgPool) {
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt;

    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");

    let config = promiso_backend::config::Config::from_env();
    let app = promiso_backend::routes::create_router(pool, &config);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/live-activity/widget/eta")
                .header("content-type", "application/json")
                .header("x-user-id", "user_123")
                .body(Body::from(
                    serde_json::json!({
                        "scheduleId": Uuid::new_v4(),
                        "channelId": "channel-test",
                        "participants": [{
                            "id": "user_123",
                            "name": "테스터",
                            "estimatedArrivalMinutes": 5
                        }],
                        "trackingDurationMinutes": 30
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .expect("request should complete");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let body_text = String::from_utf8(body.to_vec()).expect("body should be utf8");
    assert!(body_text.contains("X-Auth-Token header is required"));
}
