//! Schedules 도메인 비즈니스 규칙 테스트

use chrono::{DateTime, NaiveDate, TimeZone, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::models::notification::{FcmMessage, PushResult, PushSender};
use promiso_backend::models::schedule::*;
use promiso_backend::services::schedule_service;
use sqlx::PgPool;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

// ============================================================
// 테스트 헬퍼
// ============================================================

async fn insert_test_user(pool: &PgPool, id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', 'test-uid', 'test@test.com')",
    )
    .bind(id)
    .bind(nickname)
    .bind(nickname)
    .execute(pool)
    .await
    .expect("Failed to insert test user");
}

async fn create_test_group(pool: &PgPool, creator_id: &str, name: &str) -> Uuid {
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, description, image_url, last_activity_at) \
         VALUES ($1, UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6)), 10, NULL, NULL, NOW()) \
         RETURNING id",
    )
    .bind(name)
    .fetch_one(pool)
    .await
    .expect("Failed to create test group");

    // 생성자를 admin으로 추가 (groups 테이블에 host_uid 없음, group_members로 관리)
    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')")
        .bind(row.0)
        .bind(creator_id)
        .execute(pool)
        .await
        .expect("Failed to add creator as admin");

    row.0
}

async fn add_member_to_group(pool: &PgPool, group_id: Uuid, user_id: &str) {
    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')")
        .bind(group_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to add member to group");
}

async fn register_test_device(pool: &PgPool, user_id: &str, device_id: &str, fcm_token: &str) {
    let device: (Uuid,) = sqlx::query_as(
        "INSERT INTO devices (user_id, device_id, platform) \
         VALUES ($1, $2, 'ios') \
         RETURNING id",
    )
    .bind(user_id)
    .bind(device_id)
    .fetch_one(pool)
    .await
    .expect("Failed to register test device");

    sqlx::query(
        "INSERT INTO notification_endpoints (device_id, provider, token) \
         VALUES ($1, 'fcm', $2)",
    )
    .bind(device.0)
    .bind(fcm_token)
    .execute(pool)
    .await
    .expect("Failed to register test notification endpoint");
}

struct MockPushSender {
    calls: Arc<Mutex<Vec<(Vec<String>, FcmMessage)>>>,
}

impl MockPushSender {
    fn new() -> Self {
        Self {
            calls: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn call_count(&self) -> usize {
        self.calls.lock().unwrap().len()
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

fn make_group_schedule_request(
    group_id: Uuid,
    title: &str,
    start_at: DateTime<Utc>,
) -> CreateScheduleRequest {
    CreateScheduleRequest {
        schedule_type: ScheduleType::Group,
        group_id: Some(group_id),
        title: title.to_string(),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at,
        end_at: None,
        location: None,
        minimum_participants: Some(2),
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    }
}

fn make_personal_schedule_request(title: &str, start_at: DateTime<Utc>) -> CreateScheduleRequest {
    CreateScheduleRequest {
        schedule_type: ScheduleType::Personal,
        group_id: None,
        title: title.to_string(),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    }
}

fn make_recurring_request(
    title: &str,
    frequency: RecurrenceFrequency,
) -> CreateRecurringScheduleRequest {
    CreateRecurringScheduleRequest {
        title: title.to_string(),
        emoji: None,
        description: None,
        start_time: TimeComponents {
            hour: 10,
            minute: 0,
        },
        end_time: None,
        location: None,
        reminder_minutes_before: None,
        frequency,
        days_of_week: None,
        day_of_month: None,
        series_start_date: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
        series_end_date: None,
    }
}

fn future_time(hours: i64) -> DateTime<Utc> {
    Utc::now() + chrono::Duration::hours(hours)
}

fn past_time(hours: i64) -> DateTime<Utc> {
    Utc::now() - chrono::Duration::hours(hours)
}

// ============================================================
// 그룹일정 - 생성
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_success(pool: PgPool) {
    insert_test_user(&pool, "user1", "유저1").await;
    let group_id = create_test_group(&pool, "user1", "테스트그룹").await;

    let req = make_group_schedule_request(group_id, "팀 회의", future_time(24));
    let result = schedule_service::create_schedule(&pool, "user1", req).await;

    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.title, "팀 회의");
    assert_eq!(response.group_id, Some(group_id));
    // min_participants=2, 호스트만 수락 → 미확정
    assert_eq!(response.is_confirmed, Some(false));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_with_push_sender_notifies_members(pool: PgPool) {
    insert_test_user(&pool, "host_push_create", "호스트생성").await;
    insert_test_user(&pool, "member_push_create", "멤버생성").await;
    let group_id = create_test_group(&pool, "host_push_create", "생성알림그룹").await;
    add_member_to_group(&pool, group_id, "member_push_create").await;
    register_test_device(&pool, "member_push_create", "device-create", "fcm-create").await;

    let req = make_group_schedule_request(group_id, "생성 알림 일정", future_time(24));
    let mock = MockPushSender::new();

    let response =
        schedule_service::create_schedule_with_push_sender(&pool, &mock, "host_push_create", req)
            .await
            .expect("create should succeed");

    assert_eq!(mock.call_count(), 1);

    let notification_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_invitation'",
    )
    .bind(response.schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count should succeed");

    assert_eq!(notification_count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_host_auto_accepted(pool: PgPool) {
    // P16: 생성 후 schedule_votes에 호스트가 accepted 상태로 존재해야 함
    insert_test_user(&pool, "host_p16", "호스트P16").await;
    let group_id = create_test_group(&pool, "host_p16", "자동수락그룹").await;

    let req = make_group_schedule_request(group_id, "자동수락일정", future_time(24));
    let response = schedule_service::create_schedule(&pool, "host_p16", req)
        .await
        .expect("create should succeed");

    // DB에서 직접 투표 확인
    let vote: Option<(String,)> = sqlx::query_as(
        "SELECT status::text FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2",
    )
    .bind(response.schedule_id)
    .bind("host_p16")
    .fetch_optional(&pool)
    .await
    .expect("query failed");

    assert!(vote.is_some());
    assert_eq!(vote.unwrap().0, "accepted");
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_confirmed_when_min_is_1(pool: PgPool) {
    // P6 예외: 1인 그룹에서만 minimum_participants=1 허용
    // 그룹에 호스트만 존재 (멤버 추가 없음) → min=1, 호스트 자동수락으로 즉시 확정
    insert_test_user(&pool, "host_min1", "호스트Min1").await;
    let group_id = create_test_group(&pool, "host_min1", "즉시확정그룹").await;
    // 다른 멤버를 추가하지 않음 — 1인 그룹

    let mut req = make_group_schedule_request(group_id, "즉시확정", future_time(24));
    req.minimum_participants = Some(1);

    let result = schedule_service::create_schedule(&pool, "host_min1", req).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().is_confirmed, Some(true));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_vote_deadline_equals_start_at(pool: PgPool) {
    // P19: vote_deadline == start_at
    insert_test_user(&pool, "host_p19", "호스트P19").await;
    let group_id = create_test_group(&pool, "host_p19", "데드라인그룹").await;

    let start = future_time(48);
    let req = make_group_schedule_request(group_id, "데드라인테스트", start);
    let response = schedule_service::create_schedule(&pool, "host_p19", req)
        .await
        .expect("create should succeed");

    // DB에서 직접 vote_deadline 확인
    let row: (DateTime<Utc>, DateTime<Utc>) =
        sqlx::query_as("SELECT start_at, vote_deadline FROM schedules WHERE id = $1")
            .bind(response.schedule_id)
            .fetch_one(&pool)
            .await
            .expect("query failed");

    assert_eq!(row.0, row.1);
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_non_member_fails(pool: PgPool) {
    // P9: 비멤버가 그룹일정 생성 시도 → Forbidden
    insert_test_user(&pool, "host_p9", "호스트P9").await;
    insert_test_user(&pool, "outsider_p9", "외부인P9").await;
    let group_id = create_test_group(&pool, "host_p9", "비멤버테스트").await;

    let req = make_group_schedule_request(group_id, "불법생성", future_time(24));
    let result = schedule_service::create_schedule(&pool, "outsider_p9", req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_group_not_found(pool: PgPool) {
    // 존재하지 않는 group_id → NotFound
    insert_test_user(&pool, "host_gnf", "호스트GNF").await;

    let fake_group_id = Uuid::new_v4();
    let req = make_group_schedule_request(fake_group_id, "유령그룹일정", future_time(24));
    let result = schedule_service::create_schedule(&pool, "host_gnf", req).await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_title_empty_fails(pool: PgPool) {
    // 공백만 있는 제목 → BadRequest
    insert_test_user(&pool, "host_te", "호스트TE").await;
    let group_id = create_test_group(&pool, "host_te", "빈제목그룹").await;

    let req = make_group_schedule_request(group_id, "   ", future_time(24));
    let result = schedule_service::create_schedule(&pool, "host_te", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_title_too_long_fails(pool: PgPool) {
    // 31자 제목 → BadRequest
    insert_test_user(&pool, "host_tl", "호스트TL").await;
    let group_id = create_test_group(&pool, "host_tl", "긴제목그룹").await;

    let long_title = "가".repeat(31); // 31자
    let req = make_group_schedule_request(group_id, &long_title, future_time(24));
    let result = schedule_service::create_schedule(&pool, "host_tl", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_description_too_long_fails(pool: PgPool) {
    // 501자 설명 → BadRequest
    insert_test_user(&pool, "host_dl", "호스트DL").await;
    let group_id = create_test_group(&pool, "host_dl", "긴설명그룹").await;

    let mut req = make_group_schedule_request(group_id, "설명테스트", future_time(24));
    req.description = Some("가".repeat(501));

    let result = schedule_service::create_schedule(&pool, "host_dl", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_min_participants_zero_fails(pool: PgPool) {
    // minimum_participants = 0 → BadRequest
    insert_test_user(&pool, "host_mp0", "호스트MP0").await;
    let group_id = create_test_group(&pool, "host_mp0", "최소0그룹").await;

    let mut req = make_group_schedule_request(group_id, "최소0일정", future_time(24));
    req.minimum_participants = Some(0);

    let result = schedule_service::create_schedule(&pool, "host_mp0", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_past_start_fails(pool: PgPool) {
    // P4: 시작 시간은 현재보다 미래여야 함
    insert_test_user(&pool, "host_past", "호스트과거").await;
    let group_id = create_test_group(&pool, "host_past", "과거시작그룹").await;

    let req = make_group_schedule_request(group_id, "과거시작일정", past_time(1));
    let result = schedule_service::create_schedule(&pool, "host_past", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_min_one_requires_single_member_group(pool: PgPool) {
    // P6: minimum_participants=1은 1인 그룹에서만 허용
    insert_test_user(&pool, "host_min_rule", "호스트MinRule").await;
    insert_test_user(&pool, "member_min_rule", "멤버MinRule").await;
    let group_id = create_test_group(&pool, "host_min_rule", "최소인원예외그룹").await;
    add_member_to_group(&pool, group_id, "member_min_rule").await;

    let mut req = make_group_schedule_request(group_id, "잘못된즉시확정", future_time(24));
    req.minimum_participants = Some(1);

    let result = schedule_service::create_schedule(&pool, "host_min_rule", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_end_before_start_fails(pool: PgPool) {
    // end_at < start_at → BadRequest
    insert_test_user(&pool, "host_ebs", "호스트EBS").await;
    let group_id = create_test_group(&pool, "host_ebs", "역순시간그룹").await;

    let start = future_time(48);
    let end = future_time(24); // start보다 이전
    let mut req = make_group_schedule_request(group_id, "역순일정", start);
    req.end_at = Some(end);

    let result = schedule_service::create_schedule(&pool, "host_ebs", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_end_equals_start_fails(pool: PgPool) {
    // end_at == start_at → BadRequest (strictly after)
    insert_test_user(&pool, "host_ees", "호스트EES").await;
    let group_id = create_test_group(&pool, "host_ees", "동일시간그룹").await;

    let time = future_time(24);
    let mut req = make_group_schedule_request(group_id, "동일시간일정", time);
    req.end_at = Some(time);

    let result = schedule_service::create_schedule(&pool, "host_ees", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_description_blocks_max_20(pool: PgPool) {
    // 21개 description_blocks → BadRequest
    insert_test_user(&pool, "host_db21", "호스트DB21").await;
    let group_id = create_test_group(&pool, "host_db21", "블록초과그룹").await;

    let blocks: Vec<serde_json::Value> = (0..21)
        .map(|i| serde_json::json!({"type": "text", "content": format!("block {}", i)}))
        .collect();
    let mut req = make_group_schedule_request(group_id, "블록초과일정", future_time(24));
    req.description_blocks = Some(serde_json::Value::Array(blocks));

    let result = schedule_service::create_schedule(&pool, "host_db21", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_group_schedule_image_urls_max_3(pool: PgPool) {
    // 4개 이미지 URL → BadRequest
    insert_test_user(&pool, "host_img4", "호스트IMG4").await;
    let group_id = create_test_group(&pool, "host_img4", "이미지초과그룹").await;

    let mut req = make_group_schedule_request(group_id, "이미지초과", future_time(24));
    req.image_urls = Some(vec![
        "https://example.com/1.jpg".to_string(),
        "https://example.com/2.jpg".to_string(),
        "https://example.com/3.jpg".to_string(),
        "https://example.com/4.jpg".to_string(),
    ]);

    let result = schedule_service::create_schedule(&pool, "host_img4", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 그룹일정 - 응답 (투표)
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_with_push_sender_notifies_confirmation(pool: PgPool) {
    insert_test_user(&pool, "host_push_respond", "호스트응답").await;
    insert_test_user(&pool, "member_push_respond", "멤버응답").await;
    let group_id = create_test_group(&pool, "host_push_respond", "응답알림그룹").await;
    add_member_to_group(&pool, group_id, "member_push_respond").await;
    register_test_device(
        &pool,
        "member_push_respond",
        "device-respond",
        "fcm-respond",
    )
    .await;

    let schedule = schedule_service::create_schedule(
        &pool,
        "host_push_respond",
        make_group_schedule_request(group_id, "응답 알림 일정", future_time(24)),
    )
    .await
    .expect("create should succeed");

    let mock = MockPushSender::new();
    let response = schedule_service::respond_schedule_with_push_sender(
        &pool,
        &mock,
        "member_push_respond",
        schedule.schedule_id,
        RespondScheduleRequest {
            status: "accepted".to_string(),
        },
    )
    .await
    .expect("respond should succeed");

    assert!(response.is_confirmed);
    assert_eq!(mock.call_count(), 1);

    let notification_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_confirmed'",
    )
    .bind(schedule.schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count should succeed");

    assert!(notification_count.0 >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_accept_success(pool: PgPool) {
    insert_test_user(&pool, "host_ra", "호스트RA").await;
    insert_test_user(&pool, "member_ra", "멤버RA").await;
    let group_id = create_test_group(&pool, "host_ra", "수락그룹").await;
    add_member_to_group(&pool, group_id, "member_ra").await;

    let req = make_group_schedule_request(group_id, "수락테스트", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_ra", req)
        .await
        .expect("create should succeed");

    let respond_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_ra", schedule.schedule_id, respond_req)
            .await;
    assert!(result.is_ok());

    let response = result.unwrap();
    assert_eq!(response.status, "accepted");
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_decline_success(pool: PgPool) {
    insert_test_user(&pool, "host_rd", "호스트RD").await;
    insert_test_user(&pool, "member_rd", "멤버RD").await;
    let group_id = create_test_group(&pool, "host_rd", "거절그룹").await;
    add_member_to_group(&pool, group_id, "member_rd").await;

    let req = make_group_schedule_request(group_id, "거절테스트", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_rd", req)
        .await
        .expect("create should succeed");

    let respond_req = RespondScheduleRequest {
        status: "declined".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_rd", schedule.schedule_id, respond_req)
            .await;
    assert!(result.is_ok());

    let response = result.unwrap();
    assert_eq!(response.status, "declined");
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_pending_removes_vote(pool: PgPool) {
    // P28: pending으로 응답하면 schedule_votes에서 삭제
    insert_test_user(&pool, "host_rp", "호스트RP").await;
    insert_test_user(&pool, "member_rp", "멤버RP").await;
    let group_id = create_test_group(&pool, "host_rp", "보류그룹").await;
    add_member_to_group(&pool, group_id, "member_rp").await;

    let req = make_group_schedule_request(group_id, "보류테스트", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_rp", req)
        .await
        .expect("create should succeed");

    // 먼저 수락
    let accept_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    schedule_service::respond_schedule(&pool, "member_rp", schedule.schedule_id, accept_req)
        .await
        .expect("accept should succeed");

    // pending으로 변경
    let pending_req = RespondScheduleRequest {
        status: "pending".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_rp", schedule.schedule_id, pending_req)
            .await;
    assert!(result.is_ok());

    // DB에서 투표 삭제 확인
    let vote_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2",
    )
    .bind(schedule.schedule_id)
    .bind("member_rp")
    .fetch_one(&pool)
    .await
    .expect("query failed");

    assert_eq!(vote_count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_same_status_noop(pool: PgPool) {
    // P27: 이미 accepted인데 다시 accepted → 에러 없이 동일 상태 유지
    insert_test_user(&pool, "host_rn", "호스트RN").await;
    insert_test_user(&pool, "member_rn", "멤버RN").await;
    let group_id = create_test_group(&pool, "host_rn", "중복응답그룹").await;
    add_member_to_group(&pool, group_id, "member_rn").await;

    let req = make_group_schedule_request(group_id, "중복응답", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_rn", req)
        .await
        .expect("create should succeed");

    let accept_req1 = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    schedule_service::respond_schedule(&pool, "member_rn", schedule.schedule_id, accept_req1)
        .await
        .expect("first accept should succeed");

    let accept_req2 = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_rn", schedule.schedule_id, accept_req2)
            .await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_recalculates_confirmed(pool: PgPool) {
    // P29: min_participants=2, 호스트 수락(1). 멤버 수락 → is_confirmed = true
    insert_test_user(&pool, "host_rc", "호스트RC").await;
    insert_test_user(&pool, "member_rc", "멤버RC").await;
    let group_id = create_test_group(&pool, "host_rc", "확정재계산").await;
    add_member_to_group(&pool, group_id, "member_rc").await;

    let req = make_group_schedule_request(group_id, "확정재계산일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_rc", req)
        .await
        .expect("create should succeed");

    // 아직 미확정 (호스트만 수락, min=2)
    assert_eq!(schedule.is_confirmed, Some(false));

    let accept_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_rc", schedule.schedule_id, accept_req)
            .await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_confirmed);
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_unconfirms_on_decline(pool: PgPool) {
    // min_participants=2, 호스트+멤버 수락 (확정). 멤버 거절 → 미확정
    insert_test_user(&pool, "host_ru", "호스트RU").await;
    insert_test_user(&pool, "member_ru", "멤버RU").await;
    let group_id = create_test_group(&pool, "host_ru", "확정취소").await;
    add_member_to_group(&pool, group_id, "member_ru").await;

    let req = make_group_schedule_request(group_id, "확정취소일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_ru", req)
        .await
        .expect("create should succeed");

    // 멤버 수락 → 확정
    let accept_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let confirmed =
        schedule_service::respond_schedule(&pool, "member_ru", schedule.schedule_id, accept_req)
            .await
            .expect("accept should succeed");
    assert!(confirmed.is_confirmed);

    // 멤버 거절 → 미확정
    let decline_req = RespondScheduleRequest {
        status: "declined".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_ru", schedule.schedule_id, decline_req)
            .await;
    assert!(result.is_ok());
    assert!(!result.unwrap().is_confirmed);
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_non_member_fails(pool: PgPool) {
    // P15: 그룹 비멤버 → Forbidden
    insert_test_user(&pool, "host_rnm", "호스트RNM").await;
    insert_test_user(&pool, "outsider_rnm", "외부인RNM").await;
    let group_id = create_test_group(&pool, "host_rnm", "비멤버응답").await;

    let req = make_group_schedule_request(group_id, "비멤버응답일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_rnm", req)
        .await
        .expect("create should succeed");

    let respond_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result = schedule_service::respond_schedule(
        &pool,
        "outsider_rnm",
        schedule.schedule_id,
        respond_req,
    )
    .await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_not_found(pool: PgPool) {
    // 존재하지 않는 schedule_id → NotFound
    insert_test_user(&pool, "user_rnf", "유저RNF").await;

    let respond_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "user_rnf", Uuid::new_v4(), respond_req).await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_returns_confirmed_schedule(pool: PgPool) {
    // is_confirmed && status=="accepted" → confirmed_schedule에 정보 포함
    insert_test_user(&pool, "host_rcs", "호스트RCS").await;
    insert_test_user(&pool, "member_rcs", "멤버RCS").await;
    let group_id = create_test_group(&pool, "host_rcs", "확정응답").await;
    add_member_to_group(&pool, group_id, "member_rcs").await;

    let mut req = make_group_schedule_request(group_id, "확정일정응답", future_time(24));
    req.minimum_participants = Some(2);

    let schedule = schedule_service::create_schedule(&pool, "host_rcs", req)
        .await
        .expect("create should succeed");

    let accept_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_rcs", schedule.schedule_id, accept_req)
            .await;
    assert!(result.is_ok());

    let response = result.unwrap();
    assert!(response.is_confirmed);
    assert!(response.confirmed_schedule.is_some());

    let confirmed = response.confirmed_schedule.unwrap();
    assert_eq!(confirmed.id, schedule.schedule_id);
    assert_eq!(confirmed.title, "확정일정응답");
    assert_eq!(confirmed.group_id, group_id);
}

#[sqlx::test(migrations = "./migrations")]
async fn respond_schedule_invalid_status_fails(pool: PgPool) {
    // status = "invalid" → BadRequest
    insert_test_user(&pool, "host_ris", "호스트RIS").await;
    insert_test_user(&pool, "member_ris", "멤버RIS").await;
    let group_id = create_test_group(&pool, "host_ris", "잘못된상태").await;
    add_member_to_group(&pool, group_id, "member_ris").await;

    let req = make_group_schedule_request(group_id, "잘못된상태일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_ris", req)
        .await
        .expect("create should succeed");

    let respond_req = RespondScheduleRequest {
        status: "invalid".to_string(),
    };
    let result =
        schedule_service::respond_schedule(&pool, "member_ris", schedule.schedule_id, respond_req)
            .await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 그룹일정 - 수정
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_with_push_sender_notifies_accepted_members(pool: PgPool) {
    insert_test_user(&pool, "host_push_update", "호스트수정").await;
    insert_test_user(&pool, "member_push_update", "멤버수정").await;
    let group_id = create_test_group(&pool, "host_push_update", "수정알림그룹").await;
    add_member_to_group(&pool, group_id, "member_push_update").await;
    register_test_device(&pool, "member_push_update", "device-update", "fcm-update").await;

    let schedule = schedule_service::create_schedule(
        &pool,
        "host_push_update",
        make_group_schedule_request(group_id, "수정 전 일정", future_time(24)),
    )
    .await
    .expect("create should succeed");

    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) VALUES ($1, $2, 'accepted')",
    )
    .bind(schedule.schedule_id)
    .bind("member_push_update")
    .execute(&pool)
    .await
    .expect("vote insert should succeed");

    let mock = MockPushSender::new();
    schedule_service::update_schedule_with_push_sender(
        &pool,
        &mock,
        "host_push_update",
        schedule.schedule_id,
        UpdateScheduleRequest {
            title: Some("수정 후 일정".to_string()),
            emoji: None,
            description: None,
            description_blocks: None,
            start_at: Some(future_time(30)),
            end_at: None,
            location: None,
            minimum_participants: None,
            tracking_start_minutes_before: None,
            image_urls: None,
            reminder_minutes_before: None,
        },
    )
    .await
    .expect("update should succeed");

    assert_eq!(mock.call_count(), 1);

    let notification_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_updated'",
    )
    .bind(schedule.schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count should succeed");

    assert_eq!(notification_count.0, 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_host_success(pool: PgPool) {
    // 일정 호스트가 제목 수정 → 성공
    insert_test_user(&pool, "host_us", "호스트US").await;
    let group_id = create_test_group(&pool, "host_us", "수정그룹").await;

    let req = make_group_schedule_request(group_id, "원래제목", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_us", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: Some("새제목".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "host_us", schedule.schedule_id, update_req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_group_host_success(pool: PgPool) {
    // P10: 그룹 관리자(일정 호스트가 아님)도 수정 가능
    insert_test_user(&pool, "admin_ugh", "관리자UGH").await;
    insert_test_user(&pool, "member_ugh", "멤버UGH").await;
    let group_id = create_test_group(&pool, "admin_ugh", "관리자수정").await;
    add_member_to_group(&pool, group_id, "member_ugh").await;

    // 멤버가 일정 생성 (일정 호스트 = member_ugh)
    let req = make_group_schedule_request(group_id, "멤버일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "member_ugh", req)
        .await
        .expect("create should succeed");

    // 그룹 관리자가 수정
    let update_req = UpdateScheduleRequest {
        title: Some("관리자수정됨".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "admin_ugh", schedule.schedule_id, update_req)
            .await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_non_host_fails(pool: PgPool) {
    // 일반 멤버(일정 호스트도 아니고 그룹 관리자도 아님) → Forbidden
    insert_test_user(&pool, "host_unf", "호스트UNF").await;
    insert_test_user(&pool, "member_unf", "멤버UNF").await;
    let group_id = create_test_group(&pool, "host_unf", "수정거부").await;
    add_member_to_group(&pool, group_id, "member_unf").await;

    let req = make_group_schedule_request(group_id, "호스트일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_unf", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: Some("불법수정".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "member_unf", schedule.schedule_id, update_req)
            .await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_started_fails(pool: PgPool) {
    // P12: 이미 시작된 일정 수정 시도 → PreconditionFailed
    insert_test_user(&pool, "host_usf", "호스트USF").await;
    let group_id = create_test_group(&pool, "host_usf", "시작됨수정").await;

    // 과거 시간의 일정을 직접 DB에 삽입
    let schedule_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO schedules (id, schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ($1, 'group', $2, '과거일정', $3, $4, 2, false, $3)",
    )
    .bind(schedule_id)
    .bind("host_usf")
    .bind(past_time(1))
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert past schedule failed");

    let update_req = UpdateScheduleRequest {
        title: Some("수정시도".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "host_usf", schedule_id, update_req).await;
    assert!(matches!(result, Err(AppError::PreconditionFailed(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_start_at_syncs_vote_deadline(pool: PgPool) {
    // P30: start_at 변경 시 vote_deadline도 새 start_at으로 동기화
    insert_test_user(&pool, "host_usd", "호스트USD").await;
    let group_id = create_test_group(&pool, "host_usd", "데드라인동기화").await;

    let req = make_group_schedule_request(group_id, "동기화테스트", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_usd", req)
        .await
        .expect("create should succeed");

    let new_start = future_time(72);
    let update_req = UpdateScheduleRequest {
        title: None,
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: Some(new_start),
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    schedule_service::update_schedule(&pool, "host_usd", schedule.schedule_id, update_req)
        .await
        .expect("update should succeed");

    // DB에서 vote_deadline 확인
    let row: (DateTime<Utc>, DateTime<Utc>) =
        sqlx::query_as("SELECT start_at, vote_deadline FROM schedules WHERE id = $1")
            .bind(schedule.schedule_id)
            .fetch_one(&pool)
            .await
            .expect("query failed");

    assert_eq!(row.0, row.1);
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_title_empty_fails(pool: PgPool) {
    // 빈 제목 → BadRequest
    insert_test_user(&pool, "host_ute", "호스트UTE").await;
    let group_id = create_test_group(&pool, "host_ute", "빈제목수정").await;

    let req = make_group_schedule_request(group_id, "원래제목", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_ute", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: Some("".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "host_ute", schedule.schedule_id, update_req)
            .await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_title_too_long_fails(pool: PgPool) {
    // 31자 초과 제목 → BadRequest
    insert_test_user(&pool, "host_utl", "호스트UTL").await;
    let group_id = create_test_group(&pool, "host_utl", "긴제목수정").await;

    let req = make_group_schedule_request(group_id, "원래제목", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_utl", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: Some("가".repeat(31)),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "host_utl", schedule.schedule_id, update_req)
            .await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_start_at_past_fails(pool: PgPool) {
    // P4/P12: 미래 일정도 과거로 옮길 수는 없음
    insert_test_user(&pool, "host_usp", "호스트USP").await;
    let group_id = create_test_group(&pool, "host_usp", "과거이동금지").await;

    let req = make_group_schedule_request(group_id, "미래일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_usp", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: None,
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: Some(past_time(1)),
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "host_usp", schedule.schedule_id, update_req)
            .await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_schedule_minimum_participants_recalculates_confirmed(pool: PgPool) {
    // minimum_participants 변경 시 is_confirmed도 즉시 재계산되어야 함
    insert_test_user(&pool, "host_umr", "호스트UMR").await;
    insert_test_user(&pool, "member1_umr", "멤버1UMR").await;
    insert_test_user(&pool, "member2_umr", "멤버2UMR").await;
    let group_id = create_test_group(&pool, "host_umr", "확정재계산수정").await;
    add_member_to_group(&pool, group_id, "member1_umr").await;
    add_member_to_group(&pool, group_id, "member2_umr").await;

    let req = make_group_schedule_request(group_id, "확정상태변경", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_umr", req)
        .await
        .expect("create should succeed");

    schedule_service::respond_schedule(
        &pool,
        "member1_umr",
        schedule.schedule_id,
        RespondScheduleRequest {
            status: "accepted".to_string(),
        },
    )
    .await
    .expect("accept should succeed");

    let update_req = UpdateScheduleRequest {
        title: None,
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: Some(3),
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    schedule_service::update_schedule(&pool, "host_umr", schedule.schedule_id, update_req)
        .await
        .expect("update should succeed");

    let row: (bool,) = sqlx::query_as("SELECT is_confirmed FROM schedules WHERE id = $1")
        .bind(schedule.schedule_id)
        .fetch_one(&pool)
        .await
        .expect("query failed");
    assert!(!row.0);
}

// ============================================================
// 그룹일정 - 삭제
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn delete_schedule_host_success(pool: PgPool) {
    // 일정 호스트가 삭제 → 성공
    insert_test_user(&pool, "host_ds", "호스트DS").await;
    let group_id = create_test_group(&pool, "host_ds", "삭제그룹").await;

    let req = make_group_schedule_request(group_id, "삭제대상", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_ds", req)
        .await
        .expect("create should succeed");

    let result = schedule_service::delete_schedule(&pool, "host_ds", schedule.schedule_id).await;
    assert!(result.is_ok());

    // DB에서 삭제 확인
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM schedules WHERE id = $1")
        .bind(schedule.schedule_id)
        .fetch_one(&pool)
        .await
        .expect("query failed");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_schedule_group_host_success(pool: PgPool) {
    // P11: 그룹 관리자도 삭제 가능
    insert_test_user(&pool, "admin_dg", "관리자DG").await;
    insert_test_user(&pool, "member_dg", "멤버DG").await;
    let group_id = create_test_group(&pool, "admin_dg", "관리자삭제").await;
    add_member_to_group(&pool, group_id, "member_dg").await;

    // 멤버가 일정 생성
    let req = make_group_schedule_request(group_id, "멤버삭제대상", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "member_dg", req)
        .await
        .expect("create should succeed");

    // 그룹 관리자가 삭제
    let result = schedule_service::delete_schedule(&pool, "admin_dg", schedule.schedule_id).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_schedule_non_host_fails(pool: PgPool) {
    // 일반 멤버 → Forbidden
    insert_test_user(&pool, "host_dnf", "호스트DNF").await;
    insert_test_user(&pool, "member_dnf", "멤버DNF").await;
    let group_id = create_test_group(&pool, "host_dnf", "삭제거부").await;
    add_member_to_group(&pool, group_id, "member_dnf").await;

    let req = make_group_schedule_request(group_id, "삭제거부일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_dnf", req)
        .await
        .expect("create should succeed");

    let result = schedule_service::delete_schedule(&pool, "member_dnf", schedule.schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_schedule_started_fails(pool: PgPool) {
    // P13: 이미 시작된 일정 삭제 시도 → PreconditionFailed
    insert_test_user(&pool, "host_dsf", "호스트DSF").await;
    let group_id = create_test_group(&pool, "host_dsf", "시작됨삭제").await;

    let schedule_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO schedules (id, schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ($1, 'group', $2, '과거삭제', $3, $4, 2, false, $3)",
    )
    .bind(schedule_id)
    .bind("host_dsf")
    .bind(past_time(1))
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert past schedule failed");

    let result = schedule_service::delete_schedule(&pool, "host_dsf", schedule_id).await;
    assert!(matches!(result, Err(AppError::PreconditionFailed(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_schedule_cascades_votes(pool: PgPool) {
    // 삭제 후 schedule_votes도 함께 삭제
    insert_test_user(&pool, "host_dcv", "호스트DCV").await;
    insert_test_user(&pool, "member_dcv", "멤버DCV").await;
    let group_id = create_test_group(&pool, "host_dcv", "캐스케이드").await;
    add_member_to_group(&pool, group_id, "member_dcv").await;

    let req = make_group_schedule_request(group_id, "캐스케이드일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "host_dcv", req)
        .await
        .expect("create should succeed");

    // 멤버 수락
    let accept_req = RespondScheduleRequest {
        status: "accepted".to_string(),
    };
    schedule_service::respond_schedule(&pool, "member_dcv", schedule.schedule_id, accept_req)
        .await
        .expect("accept should succeed");

    // 삭제
    schedule_service::delete_schedule(&pool, "host_dcv", schedule.schedule_id)
        .await
        .expect("delete should succeed");

    // 투표도 삭제되었는지 확인
    let vote_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM schedule_votes WHERE schedule_id = $1")
            .bind(schedule.schedule_id)
            .fetch_one(&pool)
            .await
            .expect("query failed");
    assert_eq!(vote_count.0, 0);
}

// ============================================================
// 개인일정
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn create_personal_schedule_success(pool: PgPool) {
    insert_test_user(&pool, "user_ps", "유저PS").await;

    let req = make_personal_schedule_request("개인일정", future_time(24));
    let result = schedule_service::create_schedule(&pool, "user_ps", req).await;

    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.title, "개인일정");
    assert!(response.group_id.is_none());
    assert!(response.is_confirmed.is_none());
}

#[sqlx::test(migrations = "./migrations")]
async fn get_personal_schedule_owner_only(pool: PgPool) {
    // 소유자만 조회 가능, 다른 유저 → Forbidden
    insert_test_user(&pool, "owner_gpo", "소유자GPO").await;
    insert_test_user(&pool, "other_gpo", "타인GPO").await;

    let req = make_personal_schedule_request("비공개일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "owner_gpo", req)
        .await
        .expect("create should succeed");

    // 소유자 조회 → 성공
    let owner_result =
        schedule_service::get_schedule(&pool, "owner_gpo", schedule.schedule_id).await;
    assert!(owner_result.is_ok());

    // 타인 조회 → Forbidden
    let other_result =
        schedule_service::get_schedule(&pool, "other_gpo", schedule.schedule_id).await;
    assert!(matches!(other_result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn update_personal_schedule_owner_only(pool: PgPool) {
    // 소유자만 수정 가능
    insert_test_user(&pool, "owner_upo", "소유자UPO").await;
    insert_test_user(&pool, "other_upo", "타인UPO").await;

    let req = make_personal_schedule_request("수정대상개인일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "owner_upo", req)
        .await
        .expect("create should succeed");

    let update_req = UpdateScheduleRequest {
        title: Some("수정됨".to_string()),
        emoji: None,
        description: None,
        description_blocks: None,
        start_at: None,
        end_at: None,
        location: None,
        minimum_participants: None,
        tracking_start_minutes_before: None,
        image_urls: None,
        reminder_minutes_before: None,
    };
    let result =
        schedule_service::update_schedule(&pool, "other_upo", schedule.schedule_id, update_req)
            .await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_personal_schedule_owner_only(pool: PgPool) {
    // 소유자만 삭제 가능
    insert_test_user(&pool, "owner_dpo", "소유자DPO").await;
    insert_test_user(&pool, "other_dpo", "타인DPO").await;

    let req = make_personal_schedule_request("삭제대상개인일정", future_time(24));
    let schedule = schedule_service::create_schedule(&pool, "owner_dpo", req)
        .await
        .expect("create should succeed");

    let result = schedule_service::delete_schedule(&pool, "other_dpo", schedule.schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_personal_schedule_with_group_id_fails(pool: PgPool) {
    // schedule_type=personal + group_id 설정 → BadRequest
    insert_test_user(&pool, "user_pgf", "유저PGF").await;
    let group_id = create_test_group(&pool, "user_pgf", "개인+그룹").await;

    let mut req = make_personal_schedule_request("잘못된개인일정", future_time(24));
    req.group_id = Some(group_id);

    let result = schedule_service::create_schedule(&pool, "user_pgf", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 반복일정
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_daily_success(pool: PgPool) {
    insert_test_user(&pool, "user_crd", "유저CRD").await;

    let req = make_recurring_request("매일운동", RecurrenceFrequency::Daily);
    let result = schedule_service::create_recurring_schedule(&pool, "user_crd", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_weekly_success(pool: PgPool) {
    insert_test_user(&pool, "user_crw", "유저CRW").await;

    let mut req = make_recurring_request("주간미팅", RecurrenceFrequency::Weekly);
    req.days_of_week = Some(vec![2, 4, 6]); // 화, 목, 토

    let result = schedule_service::create_recurring_schedule(&pool, "user_crw", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_monthly_success(pool: PgPool) {
    insert_test_user(&pool, "user_crm", "유저CRM").await;

    let mut req = make_recurring_request("월간보고", RecurrenceFrequency::Monthly);
    req.day_of_month = Some(15);

    let result = schedule_service::create_recurring_schedule(&pool, "user_crm", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_weekly_missing_days_fails(pool: PgPool) {
    // frequency=weekly, days_of_week=None → BadRequest
    insert_test_user(&pool, "user_rwmd", "유저RWMD").await;

    let req = make_recurring_request("요일없는주간", RecurrenceFrequency::Weekly);
    // days_of_week = None (기본값)

    let result = schedule_service::create_recurring_schedule(&pool, "user_rwmd", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_monthly_missing_day_fails(pool: PgPool) {
    // frequency=monthly, day_of_month=None → BadRequest
    insert_test_user(&pool, "user_rmmd", "유저RMMD").await;

    let req = make_recurring_request("일자없는월간", RecurrenceFrequency::Monthly);
    // day_of_month = None (기본값)

    let result = schedule_service::create_recurring_schedule(&pool, "user_rmmd", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_daily_with_extra_fields_fails(pool: PgPool) {
    // frequency=daily + days_of_week 설정 → BadRequest (상호배타)
    insert_test_user(&pool, "user_rdef", "유저RDEF").await;

    let mut req = make_recurring_request("잘못된매일", RecurrenceFrequency::Daily);
    req.days_of_week = Some(vec![1, 2]);

    let result = schedule_service::create_recurring_schedule(&pool, "user_rdef", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_monthly_out_of_range_fails(pool: PgPool) {
    // day_of_month=32 → BadRequest
    insert_test_user(&pool, "user_rmor", "유저RMOR").await;

    let mut req = make_recurring_request("범위초과월간", RecurrenceFrequency::Monthly);
    req.day_of_month = Some(32);

    let result = schedule_service::create_recurring_schedule(&pool, "user_rmor", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn create_recurring_weekly_invalid_day_range_fails(pool: PgPool) {
    // days_of_week 값은 1-7 범위여야 함 (0, 8은 범위 밖)
    insert_test_user(&pool, "user1", "nick1").await;

    let mut req = make_recurring_request("invalid weekday", RecurrenceFrequency::Weekly);
    req.days_of_week = Some(vec![0, 8]); // 0 and 8 are out of 1-7 range

    let result = schedule_service::create_recurring_schedule(&pool, "user1", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_recurring_schedule_owner_only(pool: PgPool) {
    // 소유자만 삭제 가능
    insert_test_user(&pool, "owner_drs", "소유자DRS").await;
    insert_test_user(&pool, "other_drs", "타인DRS").await;

    let req = make_recurring_request("삭제대상반복", RecurrenceFrequency::Daily);
    let recurring = schedule_service::create_recurring_schedule(&pool, "owner_drs", req)
        .await
        .expect("create should succeed");

    let result =
        schedule_service::delete_recurring_schedule(&pool, "other_drs", recurring.id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn get_recurring_schedules_returns_own_only(pool: PgPool) {
    // 각 유저는 자신의 반복일정만 조회
    insert_test_user(&pool, "user1_grs", "유저1GRS").await;
    insert_test_user(&pool, "user2_grs", "유저2GRS").await;

    let req1 = make_recurring_request("유저1반복", RecurrenceFrequency::Daily);
    schedule_service::create_recurring_schedule(&pool, "user1_grs", req1)
        .await
        .expect("create should succeed");

    let req2 = make_recurring_request("유저2반복", RecurrenceFrequency::Daily);
    schedule_service::create_recurring_schedule(&pool, "user2_grs", req2)
        .await
        .expect("create should succeed");

    let user1_list = schedule_service::get_recurring_schedules(&pool, "user1_grs")
        .await
        .expect("get should succeed");
    assert_eq!(user1_list.len(), 1);
    assert_eq!(user1_list[0].title, "유저1반복");

    let user2_list = schedule_service::get_recurring_schedules(&pool, "user2_grs")
        .await
        .expect("get should succeed");
    assert_eq!(user2_list.len(), 1);
    assert_eq!(user2_list[0].title, "유저2반복");
}

// ============================================================
// 목록/조회
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn get_group_schedules_active(pool: PgPool) {
    // 미래 일정 2개 + 과거 일정 1개 → active 조회 시 2개만 반환
    insert_test_user(&pool, "host_gsa", "호스트GSA").await;
    let group_id = create_test_group(&pool, "host_gsa", "활성조회").await;

    // 미래 일정 2개
    let req1 = make_group_schedule_request(group_id, "미래일정1", future_time(24));
    schedule_service::create_schedule(&pool, "host_gsa", req1)
        .await
        .expect("create1 should succeed");

    let req2 = make_group_schedule_request(group_id, "미래일정2", future_time(48));
    schedule_service::create_schedule(&pool, "host_gsa", req2)
        .await
        .expect("create2 should succeed");

    // 과거 일정 직접 삽입
    sqlx::query(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ('group', $1, '과거일정', $2, $3, 2, false, $2)",
    )
    .bind("host_gsa")
    .bind(past_time(24))
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert past schedule failed");

    let query = GroupScheduleQuery {
        status: Some("active".to_string()),
        limit: None,
        cursor: None,
    };
    let result = schedule_service::get_group_schedules(&pool, "host_gsa", group_id, query).await;
    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.data.len(), 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn get_group_schedules_past_with_pagination(pool: PgPool) {
    // 과거 일정 5개, limit=2 → 2개 반환
    insert_test_user(&pool, "host_gsp", "호스트GSP").await;
    let group_id = create_test_group(&pool, "host_gsp", "과거페이징").await;

    for i in 1..=5 {
        sqlx::query(
            "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
             minimum_participants, is_confirmed, vote_deadline) \
             VALUES ('group', $1, $2, $3, $4, 2, false, $3)",
        )
        .bind("host_gsp")
        .bind(format!("과거일정{}", i))
        .bind(past_time(i * 24))
        .bind(group_id)
        .execute(&pool)
        .await
        .expect("insert past schedule failed");
    }

    let query = GroupScheduleQuery {
        status: Some("past".to_string()),
        limit: Some(2),
        cursor: None,
    };
    let result = schedule_service::get_group_schedules(&pool, "host_gsp", group_id, query).await;
    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.data.len(), 2);
    // cursor가 있으면 다음 페이지 존재
    assert!(response.cursor.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn get_group_schedules_non_member_fails(pool: PgPool) {
    // 비멤버 → Forbidden
    insert_test_user(&pool, "host_gsnm", "호스트GSNM").await;
    insert_test_user(&pool, "outsider_gsnm", "외부인GSNM").await;
    let group_id = create_test_group(&pool, "host_gsnm", "비멤버조회").await;

    let query = GroupScheduleQuery {
        status: Some("active".to_string()),
        limit: None,
        cursor: None,
    };
    let result =
        schedule_service::get_group_schedules(&pool, "outsider_gsnm", group_id, query).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn get_home_schedules_multi_group(pool: PgPool) {
    // 유저가 2개 그룹에 속해 있고, 각 그룹에 미래 일정 → 합산 결과, start_at 정렬
    insert_test_user(&pool, "user_ghm", "유저GHM").await;
    let group1 = create_test_group(&pool, "user_ghm", "그룹A").await;
    let group2 = create_test_group(&pool, "user_ghm", "그룹B").await;

    let req1 = make_group_schedule_request(group1, "그룹A일정", future_time(48));
    schedule_service::create_schedule(&pool, "user_ghm", req1)
        .await
        .expect("create1 should succeed");

    let req2 = make_group_schedule_request(group2, "그룹B일정", future_time(24));
    schedule_service::create_schedule(&pool, "user_ghm", req2)
        .await
        .expect("create2 should succeed");

    let query = HomeQuery { limit: None };
    let result = schedule_service::get_home_schedules(&pool, "user_ghm", query).await;
    assert!(result.is_ok());

    let schedules = result.unwrap();
    assert!(schedules.len() >= 2);
    // start_at 오름차순 정렬 확인
    if schedules.len() >= 2 {
        assert!(schedules[0].start_at <= schedules[1].start_at);
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn get_calendar_sync_confirmed_only(pool: PgPool) {
    // 확정 1개 + 미확정 1개 → 확정된 것만 반환
    insert_test_user(&pool, "user_gcs", "유저GCS").await;
    insert_test_user(&pool, "member_gcs", "멤버GCS").await;
    let group_id = create_test_group(&pool, "user_gcs", "캘린더동기화").await;
    add_member_to_group(&pool, group_id, "member_gcs").await;

    // 확정 일정: min=2, 멤버까지 수락
    let req1 = make_group_schedule_request(group_id, "확정일정", future_time(24));
    let confirmed_schedule = schedule_service::create_schedule(&pool, "user_gcs", req1)
        .await
        .expect("create confirmed should succeed");
    schedule_service::respond_schedule(
        &pool,
        "member_gcs",
        confirmed_schedule.schedule_id,
        RespondScheduleRequest {
            status: "accepted".to_string(),
        },
    )
    .await
    .expect("member accept should succeed");

    // 미확정 일정: min=2, 호스트만 수락
    let req2 = make_group_schedule_request(group_id, "미확정일정", future_time(48));
    schedule_service::create_schedule(&pool, "user_gcs", req2)
        .await
        .expect("create unconfirmed should succeed");

    let result = schedule_service::get_calendar_sync(&pool, "user_gcs").await;
    assert!(result.is_ok());

    let synced = result.unwrap();
    assert_eq!(synced.len(), 1);
    assert_eq!(synced[0].title, "확정일정");
}

#[sqlx::test(migrations = "./migrations")]
async fn get_calendar_schedules_zero_duration_without_end_at_only_on_start_day(pool: PgPool) {
    insert_test_user(&pool, "user_gcz", "유저GCZ").await;

    let start_at = Utc.with_ymd_and_hms(2026, 12, 1, 10, 0, 0).unwrap();
    let req = make_personal_schedule_request("단발일정", start_at);
    schedule_service::create_schedule(&pool, "user_gcz", req)
        .await
        .expect("create should succeed");

    let same_day = schedule_service::get_calendar_schedules(
        &pool,
        "user_gcz",
        CalendarQuery {
            start: Utc.with_ymd_and_hms(2026, 12, 1, 0, 0, 0).unwrap(),
            end: Utc.with_ymd_and_hms(2026, 12, 2, 0, 0, 0).unwrap(),
            accepted_only: None,
            timezone: Some("UTC".to_string()),
        },
    )
    .await
    .expect("same day query should succeed");
    assert_eq!(same_day.schedules.len(), 1);

    let next_day = schedule_service::get_calendar_schedules(
        &pool,
        "user_gcz",
        CalendarQuery {
            start: Utc.with_ymd_and_hms(2026, 12, 2, 0, 0, 0).unwrap(),
            end: Utc.with_ymd_and_hms(2026, 12, 3, 0, 0, 0).unwrap(),
            accepted_only: None,
            timezone: Some("UTC".to_string()),
        },
    )
    .await
    .expect("next day query should succeed");
    assert_eq!(next_day.schedules.len(), 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn get_calendar_schedules_recurring_respects_timezone_and_camelcase_overrides(pool: PgPool) {
    insert_test_user(&pool, "user_gcr", "유저GCR").await;

    sqlx::query(
        "INSERT INTO recurring_schedules \
         (user_id, title, start_time_hour, start_time_minute, frequency, days_of_week, \
          series_start_date, overrides, location_name) \
         VALUES ($1, $2, 9, 0, 'weekly', $3, $4, $5, $6)",
    )
    .bind("user_gcr")
    .bind("기본제목")
    .bind(vec![1_i16])
    .bind(NaiveDate::from_ymd_opt(2026, 1, 1).unwrap())
    .bind(serde_json::json!({
        "2026-04-05": {
            "title": "오버라이드제목",
            "startTime": { "hour": 17, "minute": 30 },
            "location": { "name": "오버라이드장소" },
            "isCancelled": false
        }
    }))
    .bind("기본장소")
    .execute(&pool)
    .await
    .expect("insert recurring schedule failed");

    let response = schedule_service::get_calendar_schedules(
        &pool,
        "user_gcr",
        CalendarQuery {
            start: Utc.with_ymd_and_hms(2026, 4, 4, 16, 0, 0).unwrap(),
            end: Utc.with_ymd_and_hms(2026, 4, 4, 18, 0, 0).unwrap(),
            accepted_only: None,
            timezone: Some("Asia/Seoul".to_string()),
        },
    )
    .await
    .expect("calendar query should succeed");

    assert_eq!(response.recurring_instances.len(), 1);
    let instance = &response.recurring_instances[0];
    assert_eq!(instance.date, NaiveDate::from_ymd_opt(2026, 4, 5).unwrap());
    assert_eq!(instance.title, "오버라이드제목");
    assert_eq!(instance.start_time.hour, 17);
    assert_eq!(instance.start_time.minute, 30);
    assert_eq!(
        instance
            .location
            .as_ref()
            .map(|location| location.name.as_str()),
        Some("오버라이드장소")
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn check_conflicts_includes_recurring_instances(pool: PgPool) {
    insert_test_user(&pool, "user_ccr", "유저CCR").await;

    sqlx::query(
        "INSERT INTO recurring_schedules \
         (user_id, title, start_time_hour, start_time_minute, frequency, series_start_date) \
         VALUES ($1, $2, 10, 0, 'daily', $3)",
    )
    .bind("user_ccr")
    .bind("매일운동")
    .bind(NaiveDate::from_ymd_opt(2026, 12, 1).unwrap())
    .execute(&pool)
    .await
    .expect("insert recurring schedule failed");

    let conflicts = schedule_service::check_conflicts(
        &pool,
        "user_ccr",
        CheckConflictsRequest {
            start_at: Utc.with_ymd_and_hms(2026, 12, 2, 10, 0, 0).unwrap(),
            end_at: Some(Utc.with_ymd_and_hms(2026, 12, 2, 11, 0, 0).unwrap()),
            min_gap_minutes: Some(0),
            exclude_ids: None,
            timezone: Some("UTC".to_string()),
        },
    )
    .await
    .expect("conflict check should succeed");

    assert!(conflicts
        .iter()
        .any(|conflict| conflict.conflict_type == "recurring"));
}

#[sqlx::test(migrations = "./migrations")]
async fn check_conflicts_zero_duration_same_time_conflicts(pool: PgPool) {
    insert_test_user(&pool, "user_ccz", "유저CCZ").await;

    let start_at = Utc.with_ymd_and_hms(2026, 12, 3, 10, 0, 0).unwrap();
    let created = schedule_service::create_schedule(
        &pool,
        "user_ccz",
        make_personal_schedule_request("점일정", start_at),
    )
    .await
    .expect("create should succeed");

    let conflicts = schedule_service::check_conflicts(
        &pool,
        "user_ccz",
        CheckConflictsRequest {
            start_at,
            end_at: None,
            min_gap_minutes: Some(0),
            exclude_ids: None,
            timezone: Some("UTC".to_string()),
        },
    )
    .await
    .expect("conflict check should succeed");

    assert!(conflicts.iter().any(|conflict| {
        conflict.conflict_type == "personal" && conflict.id == created.schedule_id.to_string()
    }));
}
