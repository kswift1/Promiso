use chrono::{DateTime, Duration, Utc};
use promiso_backend::models::live_activity::{
    LiveActivityJob, LiveActivityJobPayload, LiveActivityJobStatus, LiveActivityJobType,
    LiveActivityParticipant, LiveActivitySender, UpdateScheduleLiveActivityRequest,
};
use promiso_backend::models::notification::{FcmMessage, NotificationType, PushResult, PushSender};
use promiso_backend::models::schedule::Schedule;
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
        sender_state.push_to_start_calls[0].1["aps"]["content-state"]["pending_count"],
        serde_json::json!(1)
    );
    assert_eq!(
        sender_state.push_to_start_calls[0].1["aps"]["content-state"]["accepted_members"][0]["id"],
        serde_json::json!("host_vote_start")
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
