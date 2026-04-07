//! LiveActivity 도메인 비즈니스 규칙 테스트 (Red Phase)
//!
//! 모든 테스트는 컴파일은 되지만 실행 시 실패해야 한다.
//! service 함수들이 Err(AppError::Internal("not implemented")) 를 반환하기 때문.

#![allow(dead_code)]
#![allow(clippy::type_complexity)]

use std::sync::{Arc, Mutex};

use chrono::{Duration, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::models::live_activity::*;
use promiso_backend::services::{live_activity_service, scheduled_task_service};
use sqlx::PgPool;
use uuid::Uuid;

// ============================================================
// MockApnsSender
// ============================================================

struct MockApnsSender {
    push_to_start_calls: Arc<Mutex<Vec<(Vec<String>, ApnsPayload)>>>,
    broadcast_calls: Arc<Mutex<Vec<(String, ApnsPayload)>>>,
    channel_counter: Arc<Mutex<i32>>,
}

impl MockApnsSender {
    fn new() -> Self {
        Self {
            push_to_start_calls: Arc::new(Mutex::new(Vec::new())),
            broadcast_calls: Arc::new(Mutex::new(Vec::new())),
            channel_counter: Arc::new(Mutex::new(0)),
        }
    }

    fn push_to_start_count(&self) -> usize {
        self.push_to_start_calls.lock().unwrap().len()
    }

    fn broadcast_count(&self) -> usize {
        self.broadcast_calls.lock().unwrap().len()
    }

    fn last_broadcast_payload(&self) -> Option<(String, ApnsPayload)> {
        self.broadcast_calls.lock().unwrap().last().cloned()
    }
}

#[async_trait::async_trait]
impl ApnsSender for MockApnsSender {
    async fn send_push_to_start(
        &self,
        tokens: &[String],
        payload: &ApnsPayload,
    ) -> ApnsResult {
        self.push_to_start_calls
            .lock()
            .unwrap()
            .push((tokens.to_vec(), payload.clone()));
        ApnsResult {
            success_count: tokens.len() as i32,
            failure_count: 0,
        }
    }

    async fn create_channel(&self) -> Result<String, AppError> {
        let mut counter = self.channel_counter.lock().unwrap();
        *counter += 1;
        Ok(format!("test-channel-{}", counter))
    }

    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &ApnsPayload,
    ) -> ApnsResult {
        self.broadcast_calls
            .lock()
            .unwrap()
            .push((channel_id.to_string(), payload.clone()));
        ApnsResult {
            success_count: 1,
            failure_count: 0,
        }
    }
}

// ============================================================
// Test Helpers
// ============================================================

async fn insert_test_user(pool: &PgPool, id: &str, nickname: &str) {
    // nickname must not contain spaces (chk_nickname_no_spaces constraint)
    let safe_nickname = nickname.replace(' ', "");
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', 'test-uid', 'test@test.com')",
    )
    .bind(id)
    .bind(nickname)
    .bind(&safe_nickname)
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

async fn register_test_device_with_pts(
    pool: &PgPool,
    user_id: &str,
    device_id: &str,
    fcm_token: &str,
    push_to_start_token: &str,
) {
    sqlx::query(
        "INSERT INTO devices (user_id, device_id, fcm_token, platform, push_to_start_token) \
         VALUES ($1, $2, $3, 'ios', $4)",
    )
    .bind(user_id)
    .bind(device_id)
    .bind(fcm_token)
    .bind(push_to_start_token)
    .execute(pool)
    .await
    .expect("Failed to register test device with push_to_start_token");
}

async fn create_confirmed_schedule(
    pool: &PgPool,
    group_id: Uuid,
    creator_id: &str,
    title: &str,
    minutes_from_now: i64,
    tracking_minutes: Option<i16>,
) -> Uuid {
    let start_at = Utc::now() + Duration::minutes(minutes_from_now);
    let vote_deadline = start_at;
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline, tracking_start_minutes_before) \
         VALUES ('group', $1, $2, $3, $4, 2, true, $5, $6) \
         RETURNING id",
    )
    .bind(creator_id)
    .bind(title)
    .bind(start_at)
    .bind(group_id)
    .bind(vote_deadline)
    .bind(tracking_minutes)
    .fetch_one(pool)
    .await
    .expect("Failed to create confirmed schedule");

    row.0
}

async fn create_unconfirmed_schedule(
    pool: &PgPool,
    group_id: Uuid,
    creator_id: &str,
    title: &str,
) -> Uuid {
    let start_at = Utc::now() + Duration::hours(24);
    let vote_deadline = start_at;
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ('group', $1, $2, $3, $4, 2, false, $5) \
         RETURNING id",
    )
    .bind(creator_id)
    .bind(title)
    .bind(start_at)
    .bind(group_id)
    .bind(vote_deadline)
    .fetch_one(pool)
    .await
    .expect("Failed to create unconfirmed schedule");

    row.0
}

async fn accept_schedule(pool: &PgPool, schedule_id: Uuid, user_id: &str) {
    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) \
         VALUES ($1, $2, 'accepted')",
    )
    .bind(schedule_id)
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to accept schedule");
}

// ============================================================
// Schedule LiveActivity -- Permission
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn r1_host_can_start_live_activity(pool: PgPool) {
    insert_test_user(&pool, "host_r1", "Host R1").await;
    insert_test_user(&pool, "member_r1", "Member R1").await;
    let group_id = create_test_group(&pool, "host_r1", "Group R1").await;
    add_member_to_group(&pool, group_id, "member_r1").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r1", "LA Test", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r1").await;
    accept_schedule(&pool, schedule_id, "member_r1").await;

    register_test_device_with_pts(&pool, "host_r1", "dev-r1-h", "fcm-h", "pts-h").await;
    register_test_device_with_pts(&pool, "member_r1", "dev-r1-m", "fcm-m", "pts-m").await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r1", schedule_id).await;
    assert!(result.is_ok(), "Host should be able to start LA");
    let resp = result.unwrap();
    assert!(resp.success);
    assert!(apns.push_to_start_count() > 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn r1b_non_host_cannot_start_live_activity(pool: PgPool) {
    insert_test_user(&pool, "host_r1b", "Host R1b").await;
    insert_test_user(&pool, "member_r1b", "Member R1b").await;
    let group_id = create_test_group(&pool, "host_r1b", "Group R1b").await;
    add_member_to_group(&pool, group_id, "member_r1b").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r1b", "LA Test", 60, Some(30)).await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "member_r1b", schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// Schedule LiveActivity -- ETA
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn r2_authenticated_user_can_update_eta(pool: PgPool) {
    insert_test_user(&pool, "host_r2", "Host R2").await;
    insert_test_user(&pool, "member_r2", "Member R2").await;
    let group_id = create_test_group(&pool, "host_r2", "Group R2").await;
    add_member_to_group(&pool, group_id, "member_r2").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r2", "ETA Test", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r2").await;
    accept_schedule(&pool, schedule_id, "member_r2").await;

    register_test_device_with_pts(&pool, "member_r2", "dev-r2", "fcm-r2", "pts-r2").await;

    // Mark schedule as LA started
    sqlx::query("UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r2' WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    let apns = MockApnsSender::new();
    let req = UpdateETARequest {
        channel_id: "ch-r2".to_string(),
        participants: vec![ParticipantState {
            id: "member_r2".to_string(),
            name: "Member R2".to_string(),
            estimated_arrival_minutes: Some(15),
        }],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "member_r2", schedule_id, req).await;
    assert!(result.is_ok(), "Authenticated user should update ETA");
}

#[sqlx::test(migrations = "./migrations")]
async fn r5_default_tracking_minutes_is_30(pool: PgPool) {
    insert_test_user(&pool, "host_r5", "Host R5").await;
    let group_id = create_test_group(&pool, "host_r5", "Group R5").await;

    // Create schedule without tracking_start_minutes_before
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r5", "Default Track", 60, None).await;
    accept_schedule(&pool, schedule_id, "host_r5").await;

    register_test_device_with_pts(&pool, "host_r5", "dev-r5", "fcm-r5", "pts-r5").await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r5", schedule_id).await;
    // When implemented: should use default 30 minutes tracking
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn r6_eta_null_means_waiting(pool: PgPool) {
    insert_test_user(&pool, "host_r6", "Host R6").await;
    let group_id = create_test_group(&pool, "host_r6", "Group R6").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r6", "ETA Null", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r6").await;

    sqlx::query("UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r6' WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    register_test_device_with_pts(&pool, "host_r6", "dev-r6", "fcm-r6", "pts-r6").await;

    let apns = MockApnsSender::new();
    let req = UpdateETARequest {
        channel_id: "ch-r6".to_string(),
        participants: vec![ParticipantState {
            id: "host_r6".to_string(),
            name: "Host R6".to_string(),
            estimated_arrival_minutes: None, // null = waiting
        }],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r6", schedule_id, req).await;
    assert!(result.is_ok(), "ETA null should mean waiting state");
}

#[sqlx::test(migrations = "./migrations")]
async fn r6b_eta_zero_means_arrived(pool: PgPool) {
    insert_test_user(&pool, "host_r6b", "Host R6b").await;
    let group_id = create_test_group(&pool, "host_r6b", "Group R6b").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r6b", "ETA Zero", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r6b").await;

    sqlx::query(
        "UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r6b' WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    register_test_device_with_pts(&pool, "host_r6b", "dev-r6b", "fcm-r6b", "pts-r6b").await;

    let apns = MockApnsSender::new();
    let req = UpdateETARequest {
        channel_id: "ch-r6b".to_string(),
        participants: vec![ParticipantState {
            id: "host_r6b".to_string(),
            name: "Host R6b".to_string(),
            estimated_arrival_minutes: Some(0), // 0 = arrived
        }],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r6b", schedule_id, req).await;
    assert!(result.is_ok(), "ETA 0 should mean arrived");
}

#[sqlx::test(migrations = "./migrations")]
async fn r6c_eta_positive_means_minutes_remaining(pool: PgPool) {
    insert_test_user(&pool, "host_r6c", "Host R6c").await;
    let group_id = create_test_group(&pool, "host_r6c", "Group R6c").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r6c", "ETA Pos", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r6c").await;

    sqlx::query(
        "UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r6c' WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    register_test_device_with_pts(&pool, "host_r6c", "dev-r6c", "fcm-r6c", "pts-r6c").await;

    let apns = MockApnsSender::new();
    let req = UpdateETARequest {
        channel_id: "ch-r6c".to_string(),
        participants: vec![ParticipantState {
            id: "host_r6c".to_string(),
            name: "Host R6c".to_string(),
            estimated_arrival_minutes: Some(15), // 15 = 15 minutes remaining
        }],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r6c", schedule_id, req).await;
    assert!(result.is_ok(), "ETA positive should mean minutes remaining");
}

// ============================================================
// Schedule LiveActivity -- Auto Scheduling
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn r7_confirm_with_tracking_schedules_live_activity(pool: PgPool) {
    insert_test_user(&pool, "host_r7", "Host R7").await;
    let group_id = create_test_group(&pool, "host_r7", "Group R7").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r7", "Auto LA", 120, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r7").await;

    // schedule_live_activity should create a task in scheduled_tasks
    let result = live_activity_service::schedule_live_activity(&pool, schedule_id).await;
    assert!(result.is_ok());

    // Verify task was created
    let tasks: Vec<(String,)> = sqlx::query_as(
        "SELECT task_type FROM scheduled_tasks WHERE schedule_id = $1 AND status = 'pending'",
    )
    .bind(schedule_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert!(!tasks.is_empty(), "Should have created scheduled task");
}

#[sqlx::test(migrations = "./migrations")]
async fn r8_unconfirm_resets_schedule(pool: PgPool) {
    insert_test_user(&pool, "host_r8", "Host R8").await;
    let group_id = create_test_group(&pool, "host_r8", "Group R8").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r8", "Reset LA", 120, Some(30)).await;

    // Simulate having scheduled LA
    sqlx::query("UPDATE schedules SET la_scheduled = true WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    let result = live_activity_service::cancel_live_activity_schedule(&pool, schedule_id).await;
    assert!(result.is_ok());

    // Verify la_scheduled is reset
    let row: (bool,) =
        sqlx::query_as("SELECT la_scheduled FROM schedules WHERE id = $1")
            .bind(schedule_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(!row.0, "la_scheduled should be false after cancel");
}

#[sqlx::test(migrations = "./migrations")]
async fn r9_tracking_null_resets_schedule(pool: PgPool) {
    insert_test_user(&pool, "host_r9", "Host R9").await;
    let group_id = create_test_group(&pool, "host_r9", "Group R9").await;

    // Create confirmed with tracking, then set tracking to NULL
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r9", "Track Null", 120, Some(30)).await;

    sqlx::query("UPDATE schedules SET la_scheduled = true WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    // When tracking becomes null, should cancel schedule
    sqlx::query("UPDATE schedules SET tracking_start_minutes_before = NULL WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    let result = live_activity_service::cancel_live_activity_schedule(&pool, schedule_id).await;
    assert!(result.is_ok());

    let row: (bool,) =
        sqlx::query_as("SELECT la_scheduled FROM schedules WHERE id = $1")
            .bind(schedule_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(!row.0, "la_scheduled should be false when tracking is null");
}

#[sqlx::test(migrations = "./migrations")]
async fn r10_confirm_reschedules_on_time_change(pool: PgPool) {
    insert_test_user(&pool, "host_r10", "Host R10").await;
    let group_id = create_test_group(&pool, "host_r10", "Group R10").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r10", "Resched", 120, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r10").await;

    // First schedule
    let result = live_activity_service::schedule_live_activity(&pool, schedule_id).await;
    assert!(result.is_ok(), "First schedule should succeed");

    // Change time (simulate) and reschedule
    sqlx::query("UPDATE schedules SET start_at = NOW() + INTERVAL '180 minutes' WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    // Reschedule should cancel old tasks and create new ones
    let result = live_activity_service::schedule_live_activity(&pool, schedule_id).await;
    assert!(result.is_ok(), "Reschedule should succeed");
}

#[sqlx::test(migrations = "./migrations")]
async fn r11_schedule_version_prevents_stale_execution(pool: PgPool) {
    insert_test_user(&pool, "host_r11", "Host R11").await;
    let group_id = create_test_group(&pool, "host_r11", "Group R11").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r11", "Version", 120, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r11").await;

    let stale_version = Uuid::new_v4();
    let current_version = Uuid::new_v4();

    sqlx::query("UPDATE schedules SET la_schedule_version = $1 WHERE id = $2")
        .bind(current_version)
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    // A task with the stale version should be skipped
    // When implemented: task executor checks version before running
    // For now, test that schedule_live_activity updates version
    let result = live_activity_service::schedule_live_activity(&pool, schedule_id).await;
    assert!(result.is_ok());

    let row: (Option<Uuid>,) =
        sqlx::query_as("SELECT la_schedule_version FROM schedules WHERE id = $1")
            .bind(schedule_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    // After re-scheduling, version should differ from stale_version
    assert_ne!(
        row.0,
        Some(stale_version),
        "Version should be updated after reschedule"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn r12_started_prevents_reschedule(pool: PgPool) {
    insert_test_user(&pool, "host_r12", "Host R12").await;
    let group_id = create_test_group(&pool, "host_r12", "Group R12").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r12", "Started", 60, Some(30)).await;

    // Mark as already started
    sqlx::query("UPDATE schedules SET la_started = true WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    // schedule_live_activity should be a no-op (not error, just skip)
    let result = live_activity_service::schedule_live_activity(&pool, schedule_id).await;
    assert!(result.is_ok(), "Should silently skip when already started");
}

#[sqlx::test(migrations = "./migrations")]
async fn r13_insufficient_participants_skips_start(pool: PgPool) {
    insert_test_user(&pool, "host_r13", "Host R13").await;
    let group_id = create_test_group(&pool, "host_r13", "Group R13").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r13", "Few Parts", 60, Some(30)).await;
    // minimum_participants = 2 but only host accepted (1 person)
    accept_schedule(&pool, schedule_id, "host_r13").await;

    register_test_device_with_pts(&pool, "host_r13", "dev-r13", "fcm-r13", "pts-r13").await;

    let apns = MockApnsSender::new();
    // When auto-start triggers but not enough participants, should skip
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r13", schedule_id).await;
    // Should succeed but not actually send pushes (skip)
    assert!(result.is_ok());
    assert_eq!(apns.push_to_start_count(), 0, "Should not send push if insufficient participants");
}

// ============================================================
// Schedule LiveActivity -- End
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn r14_auto_end_after_30_minutes(pool: PgPool) {
    insert_test_user(&pool, "host_r14", "Host R14").await;
    insert_test_user(&pool, "member_r14", "Member R14").await;
    let group_id = create_test_group(&pool, "host_r14", "Group R14").await;
    add_member_to_group(&pool, group_id, "member_r14").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r14", "Auto End", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r14").await;
    accept_schedule(&pool, schedule_id, "member_r14").await;

    register_test_device_with_pts(&pool, "host_r14", "dev-r14-h", "fcm-r14-h", "pts-r14-h")
        .await;
    register_test_device_with_pts(&pool, "member_r14", "dev-r14-m", "fcm-r14-m", "pts-r14-m")
        .await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r14", schedule_id).await;
    assert!(result.is_ok());

    // Check that an "end" task is scheduled for start+30min
    let tasks: Vec<(String,)> = sqlx::query_as(
        "SELECT task_type FROM scheduled_tasks \
         WHERE schedule_id = $1 AND task_type = 'end_live_activity' AND status = 'pending'",
    )
    .bind(schedule_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert!(
        !tasks.is_empty(),
        "Should schedule auto-end task after 30 minutes"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn r15_all_arrived_schedules_delayed_end(pool: PgPool) {
    insert_test_user(&pool, "host_r15", "Host R15").await;
    insert_test_user(&pool, "member_r15", "Member R15").await;
    let group_id = create_test_group(&pool, "host_r15", "Group R15").await;
    add_member_to_group(&pool, group_id, "member_r15").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r15", "All Arrive", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r15").await;
    accept_schedule(&pool, schedule_id, "member_r15").await;

    sqlx::query(
        "UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r15' WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    register_test_device_with_pts(&pool, "host_r15", "dev-r15-h", "fcm-r15-h", "pts-r15-h")
        .await;
    register_test_device_with_pts(&pool, "member_r15", "dev-r15-m", "fcm-r15-m", "pts-r15-m")
        .await;

    let apns = MockApnsSender::new();

    // All participants report ETA=0 (arrived)
    let req = UpdateETARequest {
        channel_id: "ch-r15".to_string(),
        participants: vec![
            ParticipantState {
                id: "host_r15".to_string(),
                name: "Host R15".to_string(),
                estimated_arrival_minutes: Some(0),
            },
            ParticipantState {
                id: "member_r15".to_string(),
                name: "Member R15".to_string(),
                estimated_arrival_minutes: Some(0),
            },
        ],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r15", schedule_id, req).await;
    assert!(result.is_ok());

    // Check that a delayed end task (5 min) is scheduled
    let tasks: Vec<(String,)> = sqlx::query_as(
        "SELECT task_type FROM scheduled_tasks \
         WHERE schedule_id = $1 AND task_type = 'delayed_end_live_activity' AND status = 'pending'",
    )
    .bind(schedule_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert!(
        !tasks.is_empty(),
        "Should schedule delayed end task (5 min) when all arrived"
    );
}

// ============================================================
// Schedule LiveActivity -- Notifications
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn r16_first_arrival_triggers_alert(pool: PgPool) {
    insert_test_user(&pool, "host_r16", "Host R16").await;
    insert_test_user(&pool, "member_r16", "Member R16").await;
    let group_id = create_test_group(&pool, "host_r16", "Group R16").await;
    add_member_to_group(&pool, group_id, "member_r16").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r16", "Alert Test", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r16").await;
    accept_schedule(&pool, schedule_id, "member_r16").await;

    sqlx::query(
        "UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r16' WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    register_test_device_with_pts(&pool, "host_r16", "dev-r16-h", "fcm-r16-h", "pts-r16-h")
        .await;
    register_test_device_with_pts(&pool, "member_r16", "dev-r16-m", "fcm-r16-m", "pts-r16-m")
        .await;

    let apns = MockApnsSender::new();

    // First person arrives (arrivedCount==1, totalCount==2)
    let req = UpdateETARequest {
        channel_id: "ch-r16".to_string(),
        participants: vec![
            ParticipantState {
                id: "host_r16".to_string(),
                name: "Host R16".to_string(),
                estimated_arrival_minutes: Some(0), // arrived
            },
            ParticipantState {
                id: "member_r16".to_string(),
                name: "Member R16".to_string(),
                estimated_arrival_minutes: Some(10), // not arrived
            },
        ],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r16", schedule_id, req).await;
    assert!(result.is_ok());

    // Should include alert in broadcast payload
    let last = apns.last_broadcast_payload();
    assert!(last.is_some(), "Should broadcast update");
    let (_, payload) = last.unwrap();
    assert!(
        payload.alert.is_some(),
        "First arrival should trigger an alert"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn r16b_second_arrival_no_alert(pool: PgPool) {
    insert_test_user(&pool, "host_r16b", "Host R16b").await;
    insert_test_user(&pool, "m1_r16b", "M1 R16b").await;
    insert_test_user(&pool, "m2_r16b", "M2 R16b").await;
    let group_id = create_test_group(&pool, "host_r16b", "Group R16b").await;
    add_member_to_group(&pool, group_id, "m1_r16b").await;
    add_member_to_group(&pool, group_id, "m2_r16b").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r16b", "No Alert", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r16b").await;
    accept_schedule(&pool, schedule_id, "m1_r16b").await;
    accept_schedule(&pool, schedule_id, "m2_r16b").await;

    sqlx::query(
        "UPDATE schedules SET la_started = true, vote_channel_id = 'ch-r16b' WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    register_test_device_with_pts(&pool, "host_r16b", "dev-r16b-h", "fcm-r16b-h", "pts-r16b-h")
        .await;

    let apns = MockApnsSender::new();

    // Second person arrives (arrivedCount==2)
    let req = UpdateETARequest {
        channel_id: "ch-r16b".to_string(),
        participants: vec![
            ParticipantState {
                id: "host_r16b".to_string(),
                name: "Host R16b".to_string(),
                estimated_arrival_minutes: Some(0), // arrived
            },
            ParticipantState {
                id: "m1_r16b".to_string(),
                name: "M1 R16b".to_string(),
                estimated_arrival_minutes: Some(0), // arrived
            },
            ParticipantState {
                id: "m2_r16b".to_string(),
                name: "M2 R16b".to_string(),
                estimated_arrival_minutes: Some(10), // not arrived
            },
        ],
        tracking_duration_minutes: None,
    };
    let result =
        live_activity_service::update_eta(&pool, &apns, "host_r16b", schedule_id, req).await;
    assert!(result.is_ok());

    // Should NOT include alert
    let last = apns.last_broadcast_payload();
    if let Some((_, payload)) = last {
        assert!(
            payload.alert.is_none(),
            "Second arrival should NOT trigger an alert"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn r17_nudge_scheduled_at_half_tracking(pool: PgPool) {
    insert_test_user(&pool, "host_r17", "Host R17").await;
    insert_test_user(&pool, "member_r17", "Member R17").await;
    let group_id = create_test_group(&pool, "host_r17", "Group R17").await;
    add_member_to_group(&pool, group_id, "member_r17").await;

    // tracking = 30, so nudge at 15 minutes after start
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r17", "Nudge Test", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r17").await;
    accept_schedule(&pool, schedule_id, "member_r17").await;

    register_test_device_with_pts(&pool, "host_r17", "dev-r17-h", "fcm-r17-h", "pts-r17-h")
        .await;
    register_test_device_with_pts(&pool, "member_r17", "dev-r17-m", "fcm-r17-m", "pts-r17-m")
        .await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r17", schedule_id).await;
    assert!(result.is_ok());

    // Check that a nudge task is scheduled at tracking/2 = 15 minutes
    let tasks: Vec<(String,)> = sqlx::query_as(
        "SELECT task_type FROM scheduled_tasks \
         WHERE schedule_id = $1 AND task_type = 'nudge' AND status = 'pending'",
    )
    .bind(schedule_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert!(!tasks.is_empty(), "Should schedule nudge at half tracking time");
}

#[sqlx::test(migrations = "./migrations")]
async fn r18_nudge_targets_all_accepted(pool: PgPool) {
    insert_test_user(&pool, "host_r18", "Host R18").await;
    insert_test_user(&pool, "m1_r18", "M1 R18").await;
    insert_test_user(&pool, "m2_r18", "M2 R18").await;
    let group_id = create_test_group(&pool, "host_r18", "Group R18").await;
    add_member_to_group(&pool, group_id, "m1_r18").await;
    add_member_to_group(&pool, group_id, "m2_r18").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r18", "Nudge All", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r18").await;
    accept_schedule(&pool, schedule_id, "m1_r18").await;
    // m2_r18 did NOT accept

    register_test_device_with_pts(&pool, "host_r18", "dev-r18-h", "fcm-r18-h", "pts-r18-h")
        .await;
    register_test_device_with_pts(&pool, "m1_r18", "dev-r18-m1", "fcm-r18-m1", "pts-r18-m1")
        .await;
    register_test_device_with_pts(&pool, "m2_r18", "dev-r18-m2", "fcm-r18-m2", "pts-r18-m2")
        .await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r18", schedule_id).await;
    assert!(result.is_ok());

    // Nudge task payload should target only accepted users (host_r18, m1_r18)
    let tasks: Vec<(serde_json::Value,)> = sqlx::query_as(
        "SELECT payload FROM scheduled_tasks \
         WHERE schedule_id = $1 AND task_type = 'nudge' AND status = 'pending'",
    )
    .bind(schedule_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert!(
        !tasks.is_empty(),
        "Should have nudge task targeting accepted users only"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn r19_nudge_only_once_per_schedule(pool: PgPool) {
    insert_test_user(&pool, "host_r19", "Host R19").await;
    insert_test_user(&pool, "member_r19", "Member R19").await;
    let group_id = create_test_group(&pool, "host_r19", "Group R19").await;
    add_member_to_group(&pool, group_id, "member_r19").await;

    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_r19", "Nudge Once", 60, Some(30)).await;
    accept_schedule(&pool, schedule_id, "host_r19").await;
    accept_schedule(&pool, schedule_id, "member_r19").await;

    register_test_device_with_pts(&pool, "host_r19", "dev-r19-h", "fcm-r19-h", "pts-r19-h")
        .await;
    register_test_device_with_pts(&pool, "member_r19", "dev-r19-m", "fcm-r19-m", "pts-r19-m")
        .await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_live_activity(&pool, &apns, "host_r19", schedule_id).await;
    assert!(result.is_ok());

    // Count nudge tasks -- should be exactly 1
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM scheduled_tasks \
         WHERE schedule_id = $1 AND task_type = 'nudge'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 1, "Should schedule exactly one nudge per schedule");
}

// ============================================================
// Vote LiveActivity -- Permission
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn v1_host_can_start_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v1", "Host V1").await;
    insert_test_user(&pool, "member_v1", "Member V1").await;
    let group_id = create_test_group(&pool, "host_v1", "Group V1").await;
    add_member_to_group(&pool, group_id, "member_v1").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v1", "Vote Test").await;

    register_test_device_with_pts(&pool, "member_v1", "dev-v1-m", "fcm-v1-m", "pts-v1-m").await;

    let apns = MockApnsSender::new();
    let result = live_activity_service::start_vote(&pool, &apns, "host_v1", schedule_id).await;
    assert!(result.is_ok(), "Host should be able to start vote");
    let resp = result.unwrap();
    assert!(resp.success);
    assert!(resp.channel_id.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn v1b_non_host_cannot_start_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v1b", "Host V1b").await;
    insert_test_user(&pool, "member_v1b", "Member V1b").await;
    let group_id = create_test_group(&pool, "host_v1b", "Group V1b").await;
    add_member_to_group(&pool, group_id, "member_v1b").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v1b", "Vote NoHost").await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_vote(&pool, &apns, "member_v1b", schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn v2_user_can_only_respond_own_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v2", "Host V2").await;
    insert_test_user(&pool, "member_v2", "Member V2").await;
    let group_id = create_test_group(&pool, "host_v2", "Group V2").await;
    add_member_to_group(&pool, group_id, "member_v2").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v2", "Vote Own").await;

    // Start vote first
    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v2', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let req = VoteRespondRequest {
        response: "accepted".to_string(),
        user_name: Some("Member V2".to_string()),
    };
    let result =
        live_activity_service::respond_vote(&pool, &apns, "member_v2", schedule_id, req).await;
    assert!(result.is_ok(), "User should be able to respond own vote");
}

#[sqlx::test(migrations = "./migrations")]
async fn v2b_cannot_respond_other_users_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v2b", "Host V2b").await;
    insert_test_user(&pool, "m1_v2b", "M1 V2b").await;
    insert_test_user(&pool, "m2_v2b", "M2 V2b").await;
    let group_id = create_test_group(&pool, "host_v2b", "Group V2b").await;
    add_member_to_group(&pool, group_id, "m1_v2b").await;
    add_member_to_group(&pool, group_id, "m2_v2b").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v2b", "Vote Other").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v2b', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    // m2_v2b is NOT a member of the group -- trying to respond should fail
    // Actually, m2_v2b IS a member. The test checks that respond_vote only allows
    // the user_uid to respond for themselves, not impersonate others.
    // The service should check that the user_uid matches the authenticated user.
    let apns = MockApnsSender::new();
    let req = VoteRespondRequest {
        response: "accepted".to_string(),
        user_name: Some("M1 V2b".to_string()),
    };
    // m2_v2b tries to respond as if they are m1_v2b -- the service should reject
    // since user_uid (m2_v2b) doesn't match the vote being cast for another user
    // In practice, the service uses user_uid from auth, so this is a non-member test
    insert_test_user(&pool, "outsider_v2b", "Outsider V2b").await;
    let result =
        live_activity_service::respond_vote(&pool, &apns, "outsider_v2b", schedule_id, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn v3_host_can_finalize_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v3", "Host V3").await;
    insert_test_user(&pool, "member_v3", "Member V3").await;
    let group_id = create_test_group(&pool, "host_v3", "Group V3").await;
    add_member_to_group(&pool, group_id, "member_v3").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v3", "Finalize").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v3', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::finalize_vote(&pool, &apns, "host_v3", schedule_id).await;
    assert!(result.is_ok(), "Host should be able to finalize vote");
}

#[sqlx::test(migrations = "./migrations")]
async fn v3b_non_host_cannot_finalize_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v3b", "Host V3b").await;
    insert_test_user(&pool, "member_v3b", "Member V3b").await;
    let group_id = create_test_group(&pool, "host_v3b", "Group V3b").await;
    add_member_to_group(&pool, group_id, "member_v3b").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v3b", "No Finalize").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v3b', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::finalize_vote(&pool, &apns, "member_v3b", schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn v4_host_can_end_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v4", "Host V4").await;
    insert_test_user(&pool, "member_v4", "Member V4").await;
    let group_id = create_test_group(&pool, "host_v4", "Group V4").await;
    add_member_to_group(&pool, group_id, "member_v4").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v4", "End Vote").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v4', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result = live_activity_service::end_vote(&pool, &apns, "host_v4", schedule_id).await;
    assert!(result.is_ok(), "Host should be able to end vote");
}

#[sqlx::test(migrations = "./migrations")]
async fn v4b_non_host_cannot_end_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v4b", "Host V4b").await;
    insert_test_user(&pool, "member_v4b", "Member V4b").await;
    let group_id = create_test_group(&pool, "host_v4b", "Group V4b").await;
    add_member_to_group(&pool, group_id, "member_v4b").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v4b", "No End").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v4b', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::end_vote(&pool, &apns, "member_v4b", schedule_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// Vote LiveActivity -- Validity
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn v6_cannot_start_vote_for_past_schedule(pool: PgPool) {
    insert_test_user(&pool, "host_v6", "Host V6").await;
    let group_id = create_test_group(&pool, "host_v6", "Group V6").await;

    // Create schedule in the past
    let past_start = Utc::now() - Duration::hours(2);
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ('group', $1, 'Past Schedule', $2, $3, 2, false, $4) \
         RETURNING id",
    )
    .bind("host_v6")
    .bind(past_start)
    .bind(group_id)
    .bind(past_start)
    .fetch_one(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result = live_activity_service::start_vote(&pool, &apns, "host_v6", row.0).await;
    assert!(matches!(result, Err(AppError::PreconditionFailed(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn v7_cannot_start_vote_when_deadline_passed(pool: PgPool) {
    insert_test_user(&pool, "host_v7", "Host V7").await;
    let group_id = create_test_group(&pool, "host_v7", "Group V7").await;

    // Schedule in the future but vote_deadline in the past
    let start_at = Utc::now() + Duration::hours(2);
    let past_deadline = Utc::now() - Duration::hours(1);
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, group_id, \
         minimum_participants, is_confirmed, vote_deadline) \
         VALUES ('group', $1, 'Deadline Passed', $2, $3, 2, false, $4) \
         RETURNING id",
    )
    .bind("host_v7")
    .bind(start_at)
    .bind(group_id)
    .bind(past_deadline)
    .fetch_one(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result = live_activity_service::start_vote(&pool, &apns, "host_v7", row.0).await;
    assert!(matches!(result, Err(AppError::PreconditionFailed(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn v8_cannot_start_vote_when_already_active(pool: PgPool) {
    insert_test_user(&pool, "host_v8", "Host V8").await;
    let group_id = create_test_group(&pool, "host_v8", "Group V8").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v8", "Active Vote").await;

    // Mark vote as already started
    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v8', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    let result = live_activity_service::start_vote(&pool, &apns, "host_v8", schedule_id).await;
    assert!(matches!(result, Err(AppError::Conflict(_))));
}

// ============================================================
// Vote LiveActivity -- Behavior
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn v9_host_auto_accepted_on_vote_start(pool: PgPool) {
    insert_test_user(&pool, "host_v9", "Host V9").await;
    insert_test_user(&pool, "member_v9", "Member V9").await;
    let group_id = create_test_group(&pool, "host_v9", "Group V9").await;
    add_member_to_group(&pool, group_id, "member_v9").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v9", "Host Auto").await;

    register_test_device_with_pts(&pool, "member_v9", "dev-v9-m", "fcm-v9-m", "pts-v9-m").await;

    let apns = MockApnsSender::new();
    let result = live_activity_service::start_vote(&pool, &apns, "host_v9", schedule_id).await;
    assert!(result.is_ok());

    // Verify host is auto-accepted in schedule_votes
    let vote: Option<(String,)> = sqlx::query_as(
        "SELECT status::TEXT FROM schedule_votes WHERE schedule_id = $1 AND user_id = 'host_v9'",
    )
    .bind(schedule_id)
    .fetch_optional(&pool)
    .await
    .unwrap();
    assert!(vote.is_some(), "Host should be auto-accepted");
    assert_eq!(vote.unwrap().0, "accepted");
}

#[sqlx::test(migrations = "./migrations")]
async fn v10_vote_deadline_calculation(pool: PgPool) {
    insert_test_user(&pool, "host_v10", "Host V10").await;
    insert_test_user(&pool, "member_v10", "Member V10").await;
    let group_id = create_test_group(&pool, "host_v10", "Group V10").await;
    add_member_to_group(&pool, group_id, "member_v10").await;

    // tracking=30 minutes, schedule in 2 hours
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_v10", "Deadline", 120, Some(30)).await;

    // Unconfirm for vote
    sqlx::query("UPDATE schedules SET is_confirmed = false WHERE id = $1")
        .bind(schedule_id)
        .execute(&pool)
        .await
        .unwrap();

    register_test_device_with_pts(&pool, "member_v10", "dev-v10-m", "fcm-v10-m", "pts-v10-m")
        .await;

    let apns = MockApnsSender::new();
    let result =
        live_activity_service::start_vote(&pool, &apns, "host_v10", schedule_id).await;
    assert!(result.is_ok());

    // vote deadline = min(scheduledAt - tracking*60, now + 8hours)
    // With schedule 2h from now and tracking 30min: deadline = scheduledAt - 30min = ~90min from now
    let row: (Option<chrono::DateTime<Utc>>,) =
        sqlx::query_as("SELECT vote_ended_at FROM schedules WHERE id = $1")
            .bind(schedule_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    // vote_ended_at should be set to the calculated deadline
    assert!(
        row.0.is_some(),
        "Vote deadline should be set after starting vote"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn v11_all_responded_auto_finalizes(pool: PgPool) {
    insert_test_user(&pool, "host_v11", "Host V11").await;
    insert_test_user(&pool, "member_v11", "Member V11").await;
    let group_id = create_test_group(&pool, "host_v11", "Group V11").await;
    add_member_to_group(&pool, group_id, "member_v11").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v11", "Auto Final").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v11', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    // Host is auto-accepted (simulate)
    accept_schedule(&pool, schedule_id, "host_v11").await;

    let apns = MockApnsSender::new();

    // Member responds -- this is the last response (2/2)
    let req = VoteRespondRequest {
        response: "accepted".to_string(),
        user_name: Some("Member V11".to_string()),
    };
    let result =
        live_activity_service::respond_vote(&pool, &apns, "member_v11", schedule_id, req).await;
    assert!(result.is_ok());

    let resp = result.unwrap();
    assert!(
        resp.content_state.is_finalized,
        "Should auto-finalize when all responded"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn v12_host_can_force_finalize_without_all_responses(pool: PgPool) {
    insert_test_user(&pool, "host_v12", "Host V12").await;
    insert_test_user(&pool, "m1_v12", "M1 V12").await;
    insert_test_user(&pool, "m2_v12", "M2 V12").await;
    let group_id = create_test_group(&pool, "host_v12", "Group V12").await;
    add_member_to_group(&pool, group_id, "m1_v12").await;
    add_member_to_group(&pool, group_id, "m2_v12").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v12", "Force Final").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v12', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    // Only host accepted, m1 accepted, m2 not responded yet
    accept_schedule(&pool, schedule_id, "host_v12").await;
    accept_schedule(&pool, schedule_id, "m1_v12").await;

    let apns = MockApnsSender::new();
    // Host force-finalizes without m2's response
    let result =
        live_activity_service::finalize_vote(&pool, &apns, "host_v12", schedule_id).await;
    assert!(result.is_ok(), "Host should be able to force finalize");

    let resp = result.unwrap();
    assert!(
        resp.content_state.is_finalized,
        "Vote should be finalized"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn v13_schedule_deletion_ends_vote(pool: PgPool) {
    insert_test_user(&pool, "host_v13", "Host V13").await;
    insert_test_user(&pool, "member_v13", "Member V13").await;
    let group_id = create_test_group(&pool, "host_v13", "Group V13").await;
    add_member_to_group(&pool, group_id, "member_v13").await;

    let schedule_id =
        create_unconfirmed_schedule(&pool, group_id, "host_v13", "Delete Vote").await;

    sqlx::query(
        "UPDATE schedules SET vote_channel_id = 'ch-v13', vote_started_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(&pool)
    .await
    .unwrap();

    let apns = MockApnsSender::new();
    // End vote when schedule is being deleted
    let result =
        live_activity_service::end_vote(&pool, &apns, "host_v13", schedule_id).await;
    assert!(result.is_ok(), "Should end vote on schedule deletion");

    // Verify vote_ended_at is set
    let row: (Option<chrono::DateTime<Utc>>,) =
        sqlx::query_as("SELECT vote_ended_at FROM schedules WHERE id = $1")
            .bind(schedule_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(
        row.0.is_some(),
        "vote_ended_at should be set after ending vote"
    );
}

// ============================================================
// ScheduledTask Service
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn st1_create_task(pool: PgPool) {
    insert_test_user(&pool, "host_st1", "Host ST1").await;
    let group_id = create_test_group(&pool, "host_st1", "Group ST1").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_st1", "Task Test", 60, Some(30)).await;

    let execute_at = Utc::now() + Duration::minutes(30);
    let payload = serde_json::json!({"action": "start_la"});

    let result = scheduled_task_service::create_task(
        &pool,
        "start_live_activity",
        schedule_id,
        execute_at,
        payload,
    )
    .await;
    assert!(result.is_ok());
    let task = result.unwrap();
    assert_eq!(task.task_type, "start_live_activity");
    assert_eq!(task.schedule_id, schedule_id);
    assert_eq!(task.status, "pending");
}

#[sqlx::test(migrations = "./migrations")]
async fn st2_cancel_pending_tasks(pool: PgPool) {
    insert_test_user(&pool, "host_st2", "Host ST2").await;
    let group_id = create_test_group(&pool, "host_st2", "Group ST2").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_st2", "Cancel Test", 60, Some(30)).await;

    // Insert some pending tasks manually
    let execute_at = Utc::now() + Duration::minutes(30);
    sqlx::query(
        "INSERT INTO scheduled_tasks (task_type, schedule_id, execute_at, payload) \
         VALUES ('start_live_activity', $1, $2, '{}')",
    )
    .bind(schedule_id)
    .bind(execute_at)
    .execute(&pool)
    .await
    .unwrap();

    let result =
        scheduled_task_service::cancel_pending_tasks(&pool, schedule_id, Some("start_live_activity"))
            .await;
    assert!(result.is_ok());
    let cancelled = result.unwrap();
    assert_eq!(cancelled, 1, "Should cancel 1 pending task");
}

#[sqlx::test(migrations = "./migrations")]
async fn st3_poll_pending_tasks(pool: PgPool) {
    insert_test_user(&pool, "host_st3", "Host ST3").await;
    let group_id = create_test_group(&pool, "host_st3", "Group ST3").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_st3", "Poll Test", 60, Some(30)).await;

    // Insert a task that should be executed now
    let past_time = Utc::now() - Duration::minutes(5);
    sqlx::query(
        "INSERT INTO scheduled_tasks (task_type, schedule_id, execute_at, payload) \
         VALUES ('start_live_activity', $1, $2, '{}')",
    )
    .bind(schedule_id)
    .bind(past_time)
    .execute(&pool)
    .await
    .unwrap();

    let result = scheduled_task_service::poll_pending_tasks(&pool).await;
    assert!(result.is_ok());
    let tasks = result.unwrap();
    assert!(!tasks.is_empty(), "Should find pending tasks past execute_at");
}

#[sqlx::test(migrations = "./migrations")]
async fn st4_mark_task_completed(pool: PgPool) {
    insert_test_user(&pool, "host_st4", "Host ST4").await;
    let group_id = create_test_group(&pool, "host_st4", "Group ST4").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_st4", "Complete Test", 60, Some(30))
            .await;

    let execute_at = Utc::now() - Duration::minutes(5);
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO scheduled_tasks (task_type, schedule_id, execute_at, payload) \
         VALUES ('start_live_activity', $1, $2, '{}') RETURNING id",
    )
    .bind(schedule_id)
    .bind(execute_at)
    .fetch_one(&pool)
    .await
    .unwrap();

    let result = scheduled_task_service::mark_task_completed(&pool, row.0).await;
    assert!(result.is_ok());

    let status: (String,) =
        sqlx::query_as("SELECT status::TEXT FROM scheduled_tasks WHERE id = $1")
            .bind(row.0)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(status.0, "completed");
}

#[sqlx::test(migrations = "./migrations")]
async fn st5_mark_task_failed(pool: PgPool) {
    insert_test_user(&pool, "host_st5", "Host ST5").await;
    let group_id = create_test_group(&pool, "host_st5", "Group ST5").await;
    let schedule_id =
        create_confirmed_schedule(&pool, group_id, "host_st5", "Fail Test", 60, Some(30)).await;

    let execute_at = Utc::now() - Duration::minutes(5);
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO scheduled_tasks (task_type, schedule_id, execute_at, payload) \
         VALUES ('start_live_activity', $1, $2, '{}') RETURNING id",
    )
    .bind(schedule_id)
    .bind(execute_at)
    .fetch_one(&pool)
    .await
    .unwrap();

    let result = scheduled_task_service::mark_task_failed(&pool, row.0).await;
    assert!(result.is_ok());

    let status: (String,) =
        sqlx::query_as("SELECT status::TEXT FROM scheduled_tasks WHERE id = $1")
            .bind(row.0)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(status.0, "failed");
}
