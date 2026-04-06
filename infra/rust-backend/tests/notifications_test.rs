//! Notifications 도메인 비즈니스 규칙 테스트 (Red Phase)
//!
//! 모든 테스트는 컴파일은 되지만 실행 시 실패해야 한다.
//! service 함수들이 todo!("Red phase")를 반환하기 때문.

#![allow(dead_code)]

use std::sync::{Arc, Mutex};

use chrono::{DateTime, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::models::notification::*;
use promiso_backend::services::notification_service;
use sqlx::PgPool;
use uuid::Uuid;

// ============================================================
// MockPushSender
// ============================================================

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

    fn last_tokens(&self) -> Vec<String> {
        self.calls
            .lock()
            .unwrap()
            .last()
            .map(|(t, _)| t.clone())
            .unwrap_or_default()
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

    // 생성자를 admin으로 추가
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
    sqlx::query(
        "INSERT INTO devices (user_id, device_id, fcm_token, platform) \
         VALUES ($1, $2, $3, 'ios')",
    )
    .bind(user_id)
    .bind(device_id)
    .bind(fcm_token)
    .execute(pool)
    .await
    .expect("Failed to register test device");
}

async fn insert_test_notification(
    pool: &PgPool,
    user_id: &str,
    ntype: NotificationType,
    title: &str,
    group_id: Option<Uuid>,
) -> Uuid {
    let row: (Uuid,) = sqlx::query_as(
        "INSERT INTO notifications (user_id, notification_type, title, body, group_id) \
         VALUES ($1, $2, $3, 'test body', $4) \
         RETURNING id",
    )
    .bind(user_id)
    .bind(&ntype)
    .bind(title)
    .bind(group_id)
    .fetch_one(pool)
    .await
    .expect("Failed to insert test notification");
    row.0
}

async fn create_test_schedule(
    pool: &PgPool,
    group_id: Uuid,
    creator_id: &str,
    title: &str,
) -> Uuid {
    let start_at = Utc::now() + chrono::Duration::hours(24);
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
    .expect("Failed to create test schedule");

    row.0
}

// ============================================================
// 디바이스 관리
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn d1_register_device_success(pool: PgPool) {
    insert_test_user(&pool, "user_d1", "디바이스유저1").await;

    let req = UpsertDeviceRequest {
        device_id: "device-001".to_string(),
        fcm_token: "fcm-token-001".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let result = notification_service::upsert_device(&pool, "user_d1", req).await;
    assert!(result.is_ok());
    let resp = result.unwrap();
    assert_eq!(resp.device_id, "device-001");
    assert_eq!(resp.fcm_token, "fcm-token-001");
    assert_eq!(resp.platform, "ios");
}

#[sqlx::test(migrations = "./migrations")]
async fn d2_register_multiple_devices_same_user(pool: PgPool) {
    insert_test_user(&pool, "user_d2", "디바이스유저2").await;

    let req1 = UpsertDeviceRequest {
        device_id: "device-a".to_string(),
        fcm_token: "fcm-a".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let req2 = UpsertDeviceRequest {
        device_id: "device-b".to_string(),
        fcm_token: "fcm-b".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let r1 = notification_service::upsert_device(&pool, "user_d2", req1).await;
    assert!(r1.is_ok());
    let r2 = notification_service::upsert_device(&pool, "user_d2", req2).await;
    assert!(r2.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn d3_register_device_user_not_found(pool: PgPool) {
    let req = UpsertDeviceRequest {
        device_id: "device-ghost".to_string(),
        fcm_token: "fcm-ghost".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let result = notification_service::upsert_device(&pool, "nonexistent_user", req).await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn d4_upsert_device_updates_existing(pool: PgPool) {
    insert_test_user(&pool, "user_d4", "디바이스유저4").await;

    let req1 = UpsertDeviceRequest {
        device_id: "device-upsert".to_string(),
        fcm_token: "old-token".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    notification_service::upsert_device(&pool, "user_d4", req1)
        .await
        .expect("first upsert should succeed");

    // 같은 device_id로 새 fcm_token
    let req2 = UpsertDeviceRequest {
        device_id: "device-upsert".to_string(),
        fcm_token: "new-token".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let result = notification_service::upsert_device(&pool, "user_d4", req2).await;
    assert!(result.is_ok());
    let resp = result.unwrap();
    assert_eq!(resp.fcm_token, "new-token");
}

#[sqlx::test(migrations = "./migrations")]
async fn d5_delete_device_success(pool: PgPool) {
    insert_test_user(&pool, "user_d5", "디바이스유저5").await;

    let req = UpsertDeviceRequest {
        device_id: "device-del".to_string(),
        fcm_token: "fcm-del".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    notification_service::upsert_device(&pool, "user_d5", req)
        .await
        .expect("upsert should succeed");

    let result = notification_service::delete_device(&pool, "user_d5", "device-del").await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn d6_delete_all_devices_on_logout(pool: PgPool) {
    insert_test_user(&pool, "user_d6", "디바이스유저6").await;

    let req1 = UpsertDeviceRequest {
        device_id: "dev-logout-1".to_string(),
        fcm_token: "fcm-logout-1".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let req2 = UpsertDeviceRequest {
        device_id: "dev-logout-2".to_string(),
        fcm_token: "fcm-logout-2".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    notification_service::upsert_device(&pool, "user_d6", req1)
        .await
        .expect("upsert 1");
    notification_service::upsert_device(&pool, "user_d6", req2)
        .await
        .expect("upsert 2");

    let result = notification_service::delete_all_devices(&pool, "user_d6").await;
    assert!(result.is_ok());

    // DB에서 직접 확인: 디바이스 0개
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM devices WHERE user_id = $1")
        .bind("user_d6")
        .fetch_one(&pool)
        .await
        .expect("count query failed");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn d7_upsert_device_transfers_fcm_token_ownership(pool: PgPool) {
    // Risk 3: 같은 fcm_token이 다른 유저에 있으면 이전 row 삭제
    insert_test_user(&pool, "user_d7a", "유저D7A").await;
    insert_test_user(&pool, "user_d7b", "유저D7B").await;

    let req_a = UpsertDeviceRequest {
        device_id: "dev-transfer-a".to_string(),
        fcm_token: "shared-fcm-token".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    notification_service::upsert_device(&pool, "user_d7a", req_a)
        .await
        .expect("user_a upsert");

    // 다른 유저가 같은 fcm_token으로 등록
    let req_b = UpsertDeviceRequest {
        device_id: "dev-transfer-b".to_string(),
        fcm_token: "shared-fcm-token".to_string(),
        platform: Some("ios".to_string()),
        push_to_start_token: None,
        live_activity_push_token: None,
    };
    let result = notification_service::upsert_device(&pool, "user_d7b", req_b).await;
    assert!(result.is_ok());

    // user_d7a의 디바이스에서 해당 fcm_token이 사라졌는지 확인
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM devices WHERE user_id = $1 AND fcm_token = $2",
    )
    .bind("user_d7a")
    .bind("shared-fcm-token")
    .fetch_one(&pool)
    .await
    .expect("count query failed");
    assert_eq!(count.0, 0);
}

// ============================================================
// 알림 CRUD
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn n_crud1_get_notifications_paginated_desc(pool: PgPool) {
    insert_test_user(&pool, "user_nc1", "알림유저1").await;

    // 알림 3개 직접 삽입
    for i in 0..3 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', $2, 'body')",
        )
        .bind("user_nc1")
        .bind(format!("알림 {}", i))
        .execute(&pool)
        .await
        .expect("insert notification");
    }

    let query = GetNotificationsQuery {
        limit: Some(2),
        before: None,
    };
    let result = notification_service::get_notifications(&pool, "user_nc1", query).await;
    assert!(result.is_ok());
    let notifications = result.unwrap();
    assert_eq!(notifications.len(), 2);
    // DESC 정렬 확인
    assert!(notifications[0].created_at >= notifications[1].created_at);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud2_get_notifications_cursor_pagination(pool: PgPool) {
    insert_test_user(&pool, "user_nc2", "알림유저2").await;

    // 알림 5개 삽입
    for i in 0..5 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body, created_at) \
             VALUES ($1, 'system', $2, 'body', NOW() + ($3 || ' seconds')::interval)",
        )
        .bind("user_nc2")
        .bind(format!("알림 {}", i))
        .bind(format!("{}", i))
        .execute(&pool)
        .await
        .expect("insert notification");
    }

    // 첫 페이지
    let q1 = GetNotificationsQuery {
        limit: Some(3),
        before: None,
    };
    let page1 = notification_service::get_notifications(&pool, "user_nc2", q1)
        .await
        .expect("page 1");
    assert_eq!(page1.len(), 3);

    // 커서로 다음 페이지
    let last_created_at = page1.last().unwrap().created_at;
    let q2 = GetNotificationsQuery {
        limit: Some(3),
        before: Some(last_created_at),
    };
    let page2 = notification_service::get_notifications(&pool, "user_nc2", q2)
        .await
        .expect("page 2");
    assert_eq!(page2.len(), 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud3_get_notifications_only_own(pool: PgPool) {
    insert_test_user(&pool, "user_nc3a", "알림유저3A").await;
    insert_test_user(&pool, "user_nc3b", "알림유저3B").await;

    // user_nc3a에게 알림 2개
    for i in 0..2 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', $2, 'body')",
        )
        .bind("user_nc3a")
        .bind(format!("A 알림 {}", i))
        .execute(&pool)
        .await
        .expect("insert");
    }
    // user_nc3b에게 알림 3개
    for i in 0..3 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', $2, 'body')",
        )
        .bind("user_nc3b")
        .bind(format!("B 알림 {}", i))
        .execute(&pool)
        .await
        .expect("insert");
    }

    let query = GetNotificationsQuery {
        limit: None,
        before: None,
    };
    let result = notification_service::get_notifications(&pool, "user_nc3a", query).await;
    assert!(result.is_ok());
    let notifications = result.unwrap();
    assert_eq!(notifications.len(), 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud4_mark_as_read_success(pool: PgPool) {
    insert_test_user(&pool, "user_nc4", "알림유저4").await;

    let nid: (Uuid,) = sqlx::query_as(
        "INSERT INTO notifications (user_id, notification_type, title, body) \
         VALUES ($1, 'system', 'test', 'body') RETURNING id",
    )
    .bind("user_nc4")
    .fetch_one(&pool)
    .await
    .expect("insert");

    let result = notification_service::mark_as_read(&pool, "user_nc4", nid.0).await;
    assert!(result.is_ok());

    // DB 확인
    let row: (bool, Option<DateTime<Utc>>) =
        sqlx::query_as("SELECT is_read, read_at FROM notifications WHERE id = $1")
            .bind(nid.0)
            .fetch_one(&pool)
            .await
            .expect("query");
    assert!(row.0);
    assert!(row.1.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud5_mark_as_read_not_own_rejected(pool: PgPool) {
    insert_test_user(&pool, "user_nc5a", "알림유저5A").await;
    insert_test_user(&pool, "user_nc5b", "알림유저5B").await;

    let nid: (Uuid,) = sqlx::query_as(
        "INSERT INTO notifications (user_id, notification_type, title, body) \
         VALUES ($1, 'system', 'test', 'body') RETURNING id",
    )
    .bind("user_nc5a")
    .fetch_one(&pool)
    .await
    .expect("insert");

    // 다른 유저가 읽음 처리 시도
    let result = notification_service::mark_as_read(&pool, "user_nc5b", nid.0).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud6_mark_all_as_read(pool: PgPool) {
    insert_test_user(&pool, "user_nc6", "알림유저6").await;

    for _ in 0..3 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', 'test', 'body')",
        )
        .bind("user_nc6")
        .execute(&pool)
        .await
        .expect("insert");
    }

    let result = notification_service::mark_all_as_read(&pool, "user_nc6").await;
    assert!(result.is_ok());

    // 미읽음 0개 확인
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE",
    )
    .bind("user_nc6")
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud7_delete_notifications_success(pool: PgPool) {
    insert_test_user(&pool, "user_nc7", "알림유저7").await;

    let mut ids = Vec::new();
    for _ in 0..3 {
        let nid: (Uuid,) = sqlx::query_as(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', 'test', 'body') RETURNING id",
        )
        .bind("user_nc7")
        .fetch_one(&pool)
        .await
        .expect("insert");
        ids.push(nid.0);
    }

    // 2개만 삭제
    let req = DeleteNotificationsRequest {
        notification_ids: vec![ids[0], ids[1]],
    };
    let result = notification_service::delete_notifications(&pool, "user_nc7", req).await;
    assert!(result.is_ok());

    // 1개 남음
    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM notifications WHERE user_id = $1")
            .bind("user_nc7")
            .fetch_one(&pool)
            .await
            .expect("count");
    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud8_delete_notifications_not_own_rejected(pool: PgPool) {
    insert_test_user(&pool, "user_nc8a", "알림유저8A").await;
    insert_test_user(&pool, "user_nc8b", "알림유저8B").await;

    let nid: (Uuid,) = sqlx::query_as(
        "INSERT INTO notifications (user_id, notification_type, title, body) \
         VALUES ($1, 'system', 'test', 'body') RETURNING id",
    )
    .bind("user_nc8a")
    .fetch_one(&pool)
    .await
    .expect("insert");

    let req = DeleteNotificationsRequest {
        notification_ids: vec![nid.0],
    };
    let result = notification_service::delete_notifications(&pool, "user_nc8b", req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud9_delete_all_notifications(pool: PgPool) {
    insert_test_user(&pool, "user_nc9", "알림유저9").await;

    for _ in 0..3 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', 'test', 'body')",
        )
        .bind("user_nc9")
        .execute(&pool)
        .await
        .expect("insert");
    }

    let result = notification_service::delete_all_notifications(&pool, "user_nc9").await;
    assert!(result.is_ok());

    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM notifications WHERE user_id = $1")
            .bind("user_nc9")
            .fetch_one(&pool)
            .await
            .expect("count");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud10_get_unread_count(pool: PgPool) {
    insert_test_user(&pool, "user_nc10", "알림유저10").await;

    // 미읽음 3개, 읽음 2개
    for _ in 0..3 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body) \
             VALUES ($1, 'system', 'test', 'body')",
        )
        .bind("user_nc10")
        .execute(&pool)
        .await
        .expect("insert");
    }
    for _ in 0..2 {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body, is_read, read_at) \
             VALUES ($1, 'system', 'test', 'body', TRUE, NOW())",
        )
        .bind("user_nc10")
        .execute(&pool)
        .await
        .expect("insert");
    }

    let result = notification_service::get_unread_count(&pool, "user_nc10").await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().count, 3);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_crud11_notification_data_as_string_map(pool: PgPool) {
    insert_test_user(&pool, "user_nc11", "알림유저11").await;

    let data = serde_json::json!({"key1": "value1", "key2": "value2"});
    sqlx::query(
        "INSERT INTO notifications (user_id, notification_type, title, body, data) \
         VALUES ($1, 'system', 'test', 'body', $2)",
    )
    .bind("user_nc11")
    .bind(&data)
    .execute(&pool)
    .await
    .expect("insert");

    let query = GetNotificationsQuery {
        limit: None,
        before: None,
    };
    let result = notification_service::get_notifications(&pool, "user_nc11", query).await;
    assert!(result.is_ok());
    let notifications = result.unwrap();
    assert_eq!(notifications.len(), 1);
    let ndata = notifications[0].data.as_ref().expect("data should exist");
    assert_eq!(ndata.get("key1"), Some(&"value1".to_string()));
    assert_eq!(ndata.get("key2"), Some(&"value2".to_string()));
}

// ============================================================
// 푸시 전송
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm1_send_requires_same_group(pool: PgPool) {
    insert_test_user(&pool, "user_fcm1a", "FCM유저1A").await;
    insert_test_user(&pool, "user_fcm1b", "FCM유저1B").await;
    let group_id = create_test_group(&pool, "user_fcm1a", "FCM그룹1").await;
    // user_fcm1b는 그룹 미가입

    register_test_device(&pool, "user_fcm1b", "dev-fcm1", "fcm-fcm1").await;

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm1b".to_string()],
        notification_type: NotificationType::ScheduleInvitation,
        title: "test".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: Some("user_fcm1a".to_string()),
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm2_send_to_self_always_allowed(pool: PgPool) {
    insert_test_user(&pool, "user_fcm2", "FCM유저2").await;
    register_test_device(&pool, "user_fcm2", "dev-fcm2", "fcm-fcm2").await;

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm2".to_string()],
        notification_type: NotificationType::ScheduleReminder,
        title: "self reminder".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: None,
        related_user_id: Some("user_fcm2".to_string()),
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm3_push_always_saves_to_db(pool: PgPool) {
    insert_test_user(&pool, "user_fcm3", "FCM유저3").await;
    let group_id = create_test_group(&pool, "user_fcm3", "FCM그룹3").await;
    // 디바이스 없음 = FCM 전송 불가, 하지만 DB에는 저장되어야 함

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm3".to_string()],
        notification_type: NotificationType::GroupUpdate,
        title: "group update".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());

    // DB에 알림이 저장되었는지 확인
    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM notifications WHERE user_id = $1")
            .bind("user_fcm3")
            .fetch_one(&pool)
            .await
            .expect("count");
    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm4_push_skipped_group_disabled(pool: PgPool) {
    insert_test_user(&pool, "user_fcm4", "FCM유저4").await;
    let group_id = create_test_group(&pool, "user_fcm4", "FCM그룹4").await;
    register_test_device(&pool, "user_fcm4", "dev-fcm4", "fcm-fcm4").await;

    // 그룹 알림 비활성화
    sqlx::query(
        "UPDATE group_members SET notifications_enabled = FALSE \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_fcm4")
    .execute(&pool)
    .await
    .expect("disable notifications");

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm4".to_string()],
        notification_type: NotificationType::ScheduleInvitation,
        title: "new schedule".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());

    // DB에 알림은 저장됨
    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM notifications WHERE user_id = $1")
            .bind("user_fcm4")
            .fetch_one(&pool)
            .await
            .expect("count");
    assert_eq!(count.0, 1);

    // FCM은 전송되지 않음
    assert_eq!(mock.call_count(), 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm5_push_skipped_category_disabled(pool: PgPool) {
    insert_test_user(&pool, "user_fcm5", "FCM유저5").await;
    let group_id = create_test_group(&pool, "user_fcm5", "FCM그룹5").await;
    register_test_device(&pool, "user_fcm5", "dev-fcm5", "fcm-fcm5").await;

    // schedule_invitation 카테고리만 비활성화
    sqlx::query(
        "UPDATE group_members SET schedule_invitation = FALSE \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_fcm5")
    .execute(&pool)
    .await
    .expect("disable category");

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm5".to_string()],
        notification_type: NotificationType::ScheduleInvitation,
        title: "invitation".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());

    // FCM 미전송
    assert_eq!(mock.call_count(), 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm6_location_reminder_bypasses_settings(pool: PgPool) {
    insert_test_user(&pool, "user_fcm6", "FCM유저6").await;
    let group_id = create_test_group(&pool, "user_fcm6", "FCM그룹6").await;
    register_test_device(&pool, "user_fcm6", "dev-fcm6", "fcm-fcm6").await;

    // 그룹 알림 전체 비활성화
    sqlx::query(
        "UPDATE group_members SET notifications_enabled = FALSE \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_fcm6")
    .execute(&pool)
    .await
    .expect("disable");

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm6".to_string()],
        notification_type: NotificationType::LocationSharingReminder,
        title: "location".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());

    // 설정 무시하고 전송됨
    assert_eq!(mock.call_count(), 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm7_system_bypasses_settings(pool: PgPool) {
    insert_test_user(&pool, "user_fcm7", "FCM유저7").await;
    let group_id = create_test_group(&pool, "user_fcm7", "FCM그룹7").await;
    register_test_device(&pool, "user_fcm7", "dev-fcm7", "fcm-fcm7").await;

    // 그룹 알림 전체 비활성화
    sqlx::query(
        "UPDATE group_members SET notifications_enabled = FALSE \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_fcm7")
    .execute(&pool)
    .await
    .expect("disable");

    let mock = MockPushSender::new();
    let req = SendPushRequest {
        user_ids: vec!["user_fcm7".to_string()],
        notification_type: NotificationType::System,
        title: "system".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(result.is_ok());

    assert_eq!(mock.call_count(), 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_fcm8_send_missing_required_fields(pool: PgPool) {
    insert_test_user(&pool, "user_fcm8", "FCM유저8").await;

    let mock = MockPushSender::new();

    // user_ids 빈 배열
    let req = SendPushRequest {
        user_ids: vec![],
        notification_type: NotificationType::System,
        title: "test".to_string(),
        body: "body".to_string(),
        schedule_id: None,
        group_id: None,
        related_user_id: None,
        data: None,
    };
    let result = notification_service::send_push_internal(&pool, &mock, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 이벤트 트리거
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn n_t1_schedule_created_notifies_except_host(pool: PgPool) {
    insert_test_user(&pool, "host_t1", "호스트T1").await;
    insert_test_user(&pool, "member_t1a", "멤버T1A").await;
    insert_test_user(&pool, "member_t1b", "멤버T1B").await;
    let group_id = create_test_group(&pool, "host_t1", "트리거그룹1").await;
    add_member_to_group(&pool, group_id, "member_t1a").await;
    add_member_to_group(&pool, group_id, "member_t1b").await;

    register_test_device(&pool, "member_t1a", "dev-t1a", "fcm-t1a").await;
    register_test_device(&pool, "member_t1b", "dev-t1b", "fcm-t1b").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t1", "트리거일정1").await;
    let mock = MockPushSender::new();

    let result = notification_service::notify_schedule_created(
        &pool,
        &mock,
        schedule_id,
        group_id,
        "host_t1",
    )
    .await;
    assert!(result.is_ok());

    // 호스트 제외 2명에게 알림
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count.0, 2);

    // 호스트에게는 알림 없음
    let host_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND user_id = $2",
    )
    .bind(schedule_id)
    .bind("host_t1")
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(host_count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t1a_schedule_created_method_none_skipped(pool: PgPool) {
    // TODO: schedules 테이블에 notification_method 필드가 없음.
    // 해당 필드 추가 후 이 테스트를 완성해야 함.
    // 현재는 서비스 스텁만 호출하여 컴파일 확인.

    insert_test_user(&pool, "host_t1a", "호스트T1A").await;
    insert_test_user(&pool, "member_t1a2", "멤버T1A2").await;
    let group_id = create_test_group(&pool, "host_t1a", "메서드None그룹").await;
    add_member_to_group(&pool, group_id, "member_t1a2").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t1a", "None메서드일정").await;
    let mock = MockPushSender::new();

    // notification_method=none이면 알림 0건이어야 함
    // 현재 필드가 없으므로 서비스 구현 시 처리 필요
    let result = notification_service::notify_schedule_created(
        &pool,
        &mock,
        schedule_id,
        group_id,
        "host_t1a",
    )
    .await;
    // Red phase에서는 todo! panic이므로 result 검증은 Green에서
    let _ = result;
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t2_vote_confirmed_notifies_accepted(pool: PgPool) {
    insert_test_user(&pool, "host_t2", "호스트T2").await;
    insert_test_user(&pool, "mem_t2a", "멤버T2A").await;
    insert_test_user(&pool, "mem_t2b", "멤버T2B").await;
    let group_id = create_test_group(&pool, "host_t2", "투표그룹2").await;
    add_member_to_group(&pool, group_id, "mem_t2a").await;
    add_member_to_group(&pool, group_id, "mem_t2b").await;

    register_test_device(&pool, "mem_t2a", "dev-t2a", "fcm-t2a").await;
    register_test_device(&pool, "mem_t2b", "dev-t2b", "fcm-t2b").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t2", "확정일정").await;
    let mock = MockPushSender::new();

    let old_votes = vec![
        VoteInfo { user_id: "host_t2".to_string(), status: "accepted".to_string() },
    ];
    let new_votes = vec![
        VoteInfo { user_id: "host_t2".to_string(), status: "accepted".to_string() },
        VoteInfo { user_id: "mem_t2a".to_string(), status: "accepted".to_string() },
    ];

    let result = notification_service::notify_schedule_votes_updated(
        &pool,
        &mock,
        schedule_id,
        &old_votes,
        &new_votes,
    )
    .await;
    assert!(result.is_ok());

    // min=2 달성 시 accepted 유저들에게 confirmed 알림
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_confirmed'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert!(count.0 >= 2); // host + mem_t2a
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t3_vote_cancelled_notifies_accepted(pool: PgPool) {
    insert_test_user(&pool, "host_t3", "호스트T3").await;
    insert_test_user(&pool, "mem_t3a", "멤버T3A").await;
    insert_test_user(&pool, "mem_t3b", "멤버T3B").await;
    let group_id = create_test_group(&pool, "host_t3", "취소그룹3").await;
    add_member_to_group(&pool, group_id, "mem_t3a").await;
    add_member_to_group(&pool, group_id, "mem_t3b").await;

    register_test_device(&pool, "host_t3", "dev-t3h", "fcm-t3h").await;
    register_test_device(&pool, "mem_t3a", "dev-t3a", "fcm-t3a").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t3", "취소일정").await;
    let mock = MockPushSender::new();

    // 이전: host accepted, mem_t3a accepted (확정 상태)
    // 이후: mem_t3b가 declined → 가능인원(2) < minimum(2)가 아닌데,
    //       mem_t3a가 declined하여 가능인원(1) < minimum(2)
    let old_votes = vec![
        VoteInfo { user_id: "host_t3".to_string(), status: "accepted".to_string() },
        VoteInfo { user_id: "mem_t3a".to_string(), status: "accepted".to_string() },
    ];
    let new_votes = vec![
        VoteInfo { user_id: "host_t3".to_string(), status: "accepted".to_string() },
        VoteInfo { user_id: "mem_t3a".to_string(), status: "declined".to_string() },
    ];

    let result = notification_service::notify_schedule_votes_updated(
        &pool,
        &mock,
        schedule_id,
        &old_votes,
        &new_votes,
    )
    .await;
    assert!(result.is_ok());

    // accepted인 host_t3에게 cancelled 알림
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_cancelled'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert!(count.0 >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t3a_vote_cancelled_requires_new_decline(pool: PgPool) {
    // 기존 거절만 있고 신규 거절 없음 → cancelled 미발송
    insert_test_user(&pool, "host_t3a", "호스트T3A").await;
    insert_test_user(&pool, "mem_t3a2", "멤버T3A2").await;
    let group_id = create_test_group(&pool, "host_t3a", "기존거절그룹").await;
    add_member_to_group(&pool, group_id, "mem_t3a2").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t3a", "기존거절일정").await;
    let mock = MockPushSender::new();

    // 이전과 이후 모두 동일한 거절 상태
    let old_votes = vec![
        VoteInfo { user_id: "host_t3a".to_string(), status: "accepted".to_string() },
        VoteInfo { user_id: "mem_t3a2".to_string(), status: "declined".to_string() },
    ];
    let new_votes = vec![
        VoteInfo { user_id: "host_t3a".to_string(), status: "accepted".to_string() },
        VoteInfo { user_id: "mem_t3a2".to_string(), status: "declined".to_string() },
    ];

    let result = notification_service::notify_schedule_votes_updated(
        &pool,
        &mock,
        schedule_id,
        &old_votes,
        &new_votes,
    )
    .await;
    assert!(result.is_ok());

    // cancelled 알림 0건
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_cancelled'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t4_schedule_updated_sends_diff(pool: PgPool) {
    insert_test_user(&pool, "host_t4", "호스트T4").await;
    insert_test_user(&pool, "mem_t4", "멤버T4").await;
    let group_id = create_test_group(&pool, "host_t4", "수정그룹4").await;
    add_member_to_group(&pool, group_id, "mem_t4").await;

    register_test_device(&pool, "mem_t4", "dev-t4", "fcm-t4").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t4", "수정일정").await;
    let mock = MockPushSender::new();

    let changes = vec![
        FieldChange {
            field: "title".to_string(),
            old_value: Some("수정일정".to_string()),
            new_value: Some("수정된일정".to_string()),
        },
        FieldChange {
            field: "start_at".to_string(),
            old_value: Some("2026-04-10T10:00:00Z".to_string()),
            new_value: Some("2026-04-10T14:00:00Z".to_string()),
        },
    ];

    let result = notification_service::notify_schedule_info_updated(
        &pool,
        &mock,
        schedule_id,
        &changes,
    )
    .await;
    assert!(result.is_ok());

    // schedule_updated 알림 생성 확인
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_updated'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert!(count.0 >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t4a_schedule_updated_ignores_end_at(pool: PgPool) {
    // endAt 변경만 있으면 알림 미발송 (결정 1-B)
    insert_test_user(&pool, "host_t4a", "호스트T4A").await;
    insert_test_user(&pool, "mem_t4a", "멤버T4A").await;
    let group_id = create_test_group(&pool, "host_t4a", "endAt그룹").await;
    add_member_to_group(&pool, group_id, "mem_t4a").await;

    let schedule_id = create_test_schedule(&pool, group_id, "host_t4a", "endAt일정").await;
    let mock = MockPushSender::new();

    let changes = vec![
        FieldChange {
            field: "end_at".to_string(),
            old_value: None,
            new_value: Some("2026-04-10T18:00:00Z".to_string()),
        },
    ];

    let result = notification_service::notify_schedule_info_updated(
        &pool,
        &mock,
        schedule_id,
        &changes,
    )
    .await;
    assert!(result.is_ok());

    // 알림 0건
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE schedule_id = $1 AND notification_type = 'schedule_updated'",
    )
    .bind(schedule_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn n_t5_member_joined_notifies_existing(pool: PgPool) {
    insert_test_user(&pool, "host_t5", "호스트T5").await;
    insert_test_user(&pool, "existing_t5", "기존멤버T5").await;
    insert_test_user(&pool, "new_t5", "신규멤버T5").await;
    let group_id = create_test_group(&pool, "host_t5", "가입그룹5").await;
    add_member_to_group(&pool, group_id, "existing_t5").await;

    register_test_device(&pool, "host_t5", "dev-t5h", "fcm-t5h").await;
    register_test_device(&pool, "existing_t5", "dev-t5e", "fcm-t5e").await;

    // 신규 멤버 가입 (헬퍼로 직접 추가)
    add_member_to_group(&pool, group_id, "new_t5").await;

    let mock = MockPushSender::new();
    let result = notification_service::notify_group_member_joined(
        &pool,
        &mock,
        group_id,
        "new_t5",
    )
    .await;
    assert!(result.is_ok());

    // 기존 멤버(host + existing)에게 알림, 신규 멤버 제외
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE group_id = $1 AND notification_type = 'group_update'",
    )
    .bind(group_id)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count.0, 2); // host_t5, existing_t5

    // 신규 멤버에게는 알림 없음
    let new_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("new_t5")
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(new_count.0, 0);
}

// ============================================================
// Badge
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn b1_schedule_created_updates_last_activity(pool: PgPool) {
    insert_test_user(&pool, "host_b1", "호스트B1").await;
    let group_id = create_test_group(&pool, "host_b1", "배지그룹1").await;

    // last_activity_at 기록
    let before: (DateTime<Utc>,) =
        sqlx::query_as("SELECT last_activity_at FROM groups WHERE id = $1")
            .bind(group_id)
            .fetch_one(&pool)
            .await
            .expect("query");

    // 일정 생성으로 last_activity_at 갱신
    let schedule_id = create_test_schedule(&pool, group_id, "host_b1", "배지일정1").await;

    // notify_schedule_created 호출 (내부에서 last_activity_at 갱신)
    let mock = MockPushSender::new();
    let _ = notification_service::notify_schedule_created(
        &pool,
        &mock,
        schedule_id,
        group_id,
        "host_b1",
    )
    .await;

    let after: (DateTime<Utc>,) =
        sqlx::query_as("SELECT last_activity_at FROM groups WHERE id = $1")
            .bind(group_id)
            .fetch_one(&pool)
            .await
            .expect("query");

    assert!(after.0 >= before.0);
}

#[sqlx::test(migrations = "./migrations")]
async fn b2_clear_badge_via_mark_read(pool: PgPool) {
    insert_test_user(&pool, "user_b2", "배지유저2").await;
    let group_id = create_test_group(&pool, "user_b2", "배지그룹2").await;

    // last_read_at 기록
    let before: (DateTime<Utc>,) = sqlx::query_as(
        "SELECT last_read_at FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_b2")
    .fetch_one(&pool)
    .await
    .expect("query");

    // mark_all_as_read 호출 시 last_read_at도 갱신되어야 함
    // 알림 삽입
    sqlx::query(
        "INSERT INTO notifications (user_id, notification_type, title, body, group_id) \
         VALUES ($1, 'system', 'test', 'body', $2)",
    )
    .bind("user_b2")
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert");

    let _ = notification_service::mark_all_as_read(&pool, "user_b2").await;

    let after: (DateTime<Utc>,) = sqlx::query_as(
        "SELECT last_read_at FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind("user_b2")
    .fetch_one(&pool)
    .await
    .expect("query");

    assert!(after.0 >= before.0);
}

#[sqlx::test(migrations = "./migrations")]
async fn b3_badge_check_via_timestamp_comparison(pool: PgPool) {
    insert_test_user(&pool, "user_b3", "배지유저3").await;
    let group_id = create_test_group(&pool, "user_b3", "배지그룹3").await;

    // last_activity_at을 미래로 업데이트 (새 활동 발생 시뮬레이션)
    sqlx::query(
        "UPDATE groups SET last_activity_at = NOW() + INTERVAL '1 hour' WHERE id = $1",
    )
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("update");

    // last_activity_at > last_read_at 이면 has_new_activity = true
    let row: (DateTime<Utc>, DateTime<Utc>) = sqlx::query_as(
        "SELECT g.last_activity_at, gm.last_read_at \
         FROM groups g \
         JOIN group_members gm ON g.id = gm.group_id \
         WHERE g.id = $1 AND gm.user_id = $2",
    )
    .bind(group_id)
    .bind("user_b3")
    .fetch_one(&pool)
    .await
    .expect("query");

    let has_new_activity = row.0 > row.1;
    assert!(has_new_activity);
}
