use std::sync::Arc;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use promiso_backend::models::notification::{FcmMessage, PushResult, PushSender};
use promiso_backend::push::NoopPushSender;
use promiso_backend::services::briefing_scheduler_service::{
    dispatch_due_briefings, verify_scheduler_secret,
};
use sqlx::PgPool;
use tower::ServiceExt;

// 테스트용 모의 PushSender — 결과를 미리 지정해 카운팅 분기를 검증한다.
struct MockPushSender {
    success_count: i32,
    failure_count: i32,
}

#[async_trait::async_trait]
impl PushSender for MockPushSender {
    async fn send_multicast(&self, _tokens: &[String], _message: &FcmMessage) -> PushResult {
        PushResult {
            success: self.failure_count == 0,
            success_count: self.success_count,
            failure_count: self.failure_count,
            delivered_tokens: Vec::new(),
        }
    }
}

/// FCM 토큰 등록 — devices + notification_endpoints
async fn insert_fcm_token(pool: &PgPool, user_id: &str, token: &str) {
    let device_id: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO devices (user_id, device_id, platform, last_active_at)
         VALUES ($1, $2, 'ios', NOW())
         RETURNING id",
    )
    .bind(user_id)
    .bind(format!("device-{user_id}"))
    .fetch_one(pool)
    .await
    .expect("Failed to insert device");

    sqlx::query(
        "INSERT INTO notification_endpoints (device_id, provider, token)
         VALUES ($1, 'fcm', $2)",
    )
    .bind(device_id.0)
    .bind(token)
    .execute(pool)
    .await
    .expect("Failed to insert notification_endpoint");
}

// ============================================================
// 순수 함수 테스트
// ============================================================

#[test]
fn verify_scheduler_secret_matches() {
    assert!(verify_scheduler_secret("secret-abc", "secret-abc"));
}

#[test]
fn verify_scheduler_secret_rejects_mismatch() {
    assert!(!verify_scheduler_secret("wrong", "secret-abc"));
}

#[test]
fn verify_scheduler_secret_rejects_empty() {
    assert!(!verify_scheduler_secret("", "secret-abc"));
}

// ============================================================
// DB 테스트 헬퍼
// ============================================================

async fn insert_user(pool: &PgPool, id: &str) {
    let suffix = if id.len() > 8 {
        &id[id.len() - 8..]
    } else {
        id
    };

    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email)
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(id)
    .bind(format!("유저{suffix}"))
    .bind(format!("닉{suffix}"))
    .bind(format!("provider-{id}"))
    .bind(format!("{id}@promiso.test"))
    .execute(pool)
    .await
    .expect("Failed to insert user");
}

async fn insert_pro_entitlement(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES ($1, true, 'subscription', 'subscribed', false)",
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to insert entitlement");
}

async fn insert_free_entitlement(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES ($1, false, 'none', NULL, false)",
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to insert free entitlement");
}

/// briefing_subscriptions에 due 항목 삽입
/// next_dispatch_at을 now 기준으로 조정할 수 있도록 offset_secs 파라미터 지원
/// offset_secs < 0 이면 과거 (due), > 0 이면 미래 (not due)
async fn insert_subscription(pool: &PgPool, user_id: &str, offset_secs: i64) {
    sqlx::query(
        "INSERT INTO briefing_subscriptions
            (user_id, notification_hour, timezone, language, style, next_dispatch_at)
         VALUES ($1, 8, 'Asia/Seoul', 'ko', 'friendly',
                 NOW() + ($2 || ' seconds')::interval)",
    )
    .bind(user_id)
    .bind(offset_secs.to_string())
    .execute(pool)
    .await
    .expect("Failed to insert subscription");
}

async fn insert_user_settings(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO user_settings
            (user_id, briefing_notification_hour, briefing_timezone, briefing_language, briefing_style)
         VALUES ($1, 8, 'Asia/Seoul', 'ko', 'friendly')",
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to insert user_settings");
}

// ============================================================
// DB 테스트
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_processes_due_items(pool: PgPool) {
    insert_user(&pool, "sched_due_1").await;
    insert_pro_entitlement(&pool, "sched_due_1").await;
    insert_user_settings(&pool, "sched_due_1").await;
    // next_dispatch_at = now - 60s (due)
    insert_subscription(&pool, "sched_due_1", -60).await;

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    // due 항목이 1개이므로 total_due >= 1
    assert!(summary.total_due >= 1);
    // processed는 1개 이상
    assert!(summary.processed >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_skips_future_items(pool: PgPool) {
    insert_user(&pool, "sched_future_1").await;
    insert_pro_entitlement(&pool, "sched_future_1").await;
    insert_user_settings(&pool, "sched_future_1").await;
    // next_dispatch_at = now + 3600s (미래, not due)
    insert_subscription(&pool, "sched_future_1", 3600).await;

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    assert_eq!(summary.total_due, 0);
    assert_eq!(summary.processed, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_respects_limit(pool: PgPool) {
    for i in 1..=3 {
        let uid = format!("sched_limit_{i}");
        insert_user(&pool, &uid).await;
        insert_pro_entitlement(&pool, &uid).await;
        insert_user_settings(&pool, &uid).await;
        insert_subscription(&pool, &uid, -60).await;
    }

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 1).await.unwrap();

    // limit=1이면 최대 1개만 처리
    assert!(summary.processed <= 1);
    assert!(summary.total_due >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_advances_next_dispatch_at(pool: PgPool) {
    insert_user(&pool, "sched_advance_1").await;
    insert_pro_entitlement(&pool, "sched_advance_1").await;
    insert_user_settings(&pool, "sched_advance_1").await;
    insert_subscription(&pool, "sched_advance_1", -60).await;

    let now = chrono::Utc::now();
    let before_dispatch: (chrono::DateTime<chrono::Utc>,) =
        sqlx::query_as("SELECT next_dispatch_at FROM briefing_subscriptions WHERE user_id = $1")
            .bind("sched_advance_1")
            .fetch_one(&pool)
            .await
            .expect("row should exist before dispatch");

    dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    // 처리 후 next_dispatch_at이 갱신되었거나 행이 삭제되어야 한다
    let after_row: Option<(chrono::DateTime<chrono::Utc>,)> =
        sqlx::query_as("SELECT next_dispatch_at FROM briefing_subscriptions WHERE user_id = $1")
            .bind("sched_advance_1")
            .fetch_optional(&pool)
            .await
            .expect("query should succeed");

    if let Some(after_dispatch) = after_row {
        // 갱신된 경우: next_dispatch_at이 이전보다 미래여야 한다
        assert!(after_dispatch.0 > before_dispatch.0);
    }
    // 행이 삭제된 경우도 허용 (SC-8: compute_next_dispatch_at이 None이면 삭제)
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_deletes_when_no_next(pool: PgPool) {
    // timezone이 유효하지 않으면 compute_next_dispatch_at이 None을 반환해 행 삭제
    insert_user(&pool, "sched_delete_1").await;
    insert_pro_entitlement(&pool, "sched_delete_1").await;

    sqlx::query(
        "INSERT INTO user_settings
            (user_id, briefing_notification_hour, briefing_timezone, briefing_language, briefing_style)
         VALUES ($1, 8, 'Invalid/Timezone', 'ko', 'friendly')",
    )
    .bind("sched_delete_1")
    .execute(&pool)
    .await
    .expect("Failed to insert user_settings");

    sqlx::query(
        "INSERT INTO briefing_subscriptions
            (user_id, notification_hour, timezone, language, style, next_dispatch_at)
         VALUES ($1, 8, 'Invalid/Timezone', 'ko', 'friendly', NOW() - INTERVAL '60 seconds')",
    )
    .bind("sched_delete_1")
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    // 행이 삭제되어야 한다
    let row_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM briefing_subscriptions WHERE user_id = $1")
            .bind("sched_delete_1")
            .fetch_one(&pool)
            .await
            .expect("count query should succeed");

    assert_eq!(
        row_count.0, 0,
        "row should be deleted when no next dispatch time"
    );
    assert_eq!(summary.deleted, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_skips_non_pro_users(pool: PgPool) {
    insert_user(&pool, "sched_nonpro_1").await;
    insert_free_entitlement(&pool, "sched_nonpro_1").await;
    insert_user_settings(&pool, "sched_nonpro_1").await;
    insert_subscription(&pool, "sched_nonpro_1", -60).await;

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    // Pro 아닌 유저는 skipped 카운트에 반영 (SC-2, SC-3)
    assert!(summary.skipped >= 1);
    assert_eq!(summary.succeeded, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_returns_correct_summary(pool: PgPool) {
    // due + pro = succeeded candidate
    insert_user(&pool, "sched_summary_pro_1").await;
    insert_pro_entitlement(&pool, "sched_summary_pro_1").await;
    insert_user_settings(&pool, "sched_summary_pro_1").await;
    insert_subscription(&pool, "sched_summary_pro_1", -60).await;

    // due + non-pro = skipped
    insert_user(&pool, "sched_summary_free_1").await;
    insert_free_entitlement(&pool, "sched_summary_free_1").await;
    insert_user_settings(&pool, "sched_summary_free_1").await;
    insert_subscription(&pool, "sched_summary_free_1", -60).await;

    // future = not processed
    insert_user(&pool, "sched_summary_future_1").await;
    insert_pro_entitlement(&pool, "sched_summary_future_1").await;
    insert_user_settings(&pool, "sched_summary_future_1").await;
    insert_subscription(&pool, "sched_summary_future_1", 3600).await;

    let now = chrono::Utc::now();
    let summary = dispatch_due_briefings(&pool, &NoopPushSender, now, 10).await.unwrap();

    // due 항목: 2개 (pro 1 + free 1)
    assert_eq!(summary.total_due, 2);
    // processed: 2개 모두 처리 시도
    assert_eq!(summary.processed, 2);
    // skipped: 2개 (non-pro 1 + pro지만 FCM 토큰 없음 1)
    assert_eq!(summary.skipped, 2);
    // succeeded + failed + skipped == processed
    assert_eq!(
        summary.succeeded + summary.failed + summary.skipped,
        summary.processed
    );
}

// ============================================================
// FCM 발송 카운팅 분기 테스트 (Mock PushSender 사용)
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_counts_no_tokens_as_skipped(pool: PgPool) {
    insert_user(&pool, "fcm_no_token").await;
    insert_pro_entitlement(&pool, "fcm_no_token").await;
    insert_user_settings(&pool, "fcm_no_token").await;
    insert_subscription(&pool, "fcm_no_token", -60).await;
    // FCM 토큰 미등록

    let mock = MockPushSender {
        success_count: 0,
        failure_count: 0,
    };
    let summary = dispatch_due_briefings(&pool, &mock, chrono::Utc::now(), 10)
        .await
        .unwrap();

    // 토큰이 없으므로 발송 시도 자체가 없어야 하고, skipped로 집계되어야 한다.
    assert_eq!(summary.skipped, 1);
    assert_eq!(summary.succeeded, 0);
    assert_eq!(summary.failed, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_counts_partial_failure_as_succeeded(pool: PgPool) {
    insert_user(&pool, "fcm_partial").await;
    insert_pro_entitlement(&pool, "fcm_partial").await;
    insert_user_settings(&pool, "fcm_partial").await;
    insert_subscription(&pool, "fcm_partial", -60).await;
    insert_fcm_token(&pool, "fcm_partial", "token-a").await;

    let mock = MockPushSender {
        success_count: 1,
        failure_count: 1,
    };
    let summary = dispatch_due_briefings(&pool, &mock, chrono::Utc::now(), 10)
        .await
        .unwrap();

    // 부분 실패는 succeeded로 집계 (전부 실패만 failed).
    assert_eq!(summary.succeeded, 1);
    assert_eq!(summary.failed, 0);
    assert_eq!(summary.skipped, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_counts_total_failure_as_failed(pool: PgPool) {
    insert_user(&pool, "fcm_all_fail").await;
    insert_pro_entitlement(&pool, "fcm_all_fail").await;
    insert_user_settings(&pool, "fcm_all_fail").await;
    insert_subscription(&pool, "fcm_all_fail", -60).await;
    insert_fcm_token(&pool, "fcm_all_fail", "token-a").await;

    let mock = MockPushSender {
        success_count: 0,
        failure_count: 1,
    };
    let summary = dispatch_due_briefings(&pool, &mock, chrono::Utc::now(), 10)
        .await
        .unwrap();

    assert_eq!(summary.failed, 1);
    assert_eq!(summary.succeeded, 0);
    assert_eq!(summary.skipped, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_counts_noop_pushsender_as_succeeded(pool: PgPool) {
    // NoopPushSender는 success=0, failure=0 을 반환한다.
    // 운영 환경에서 FCM 미설정 시 폴백으로 사용되므로
    // 모든 dispatch가 failed로 잡히지 않아야 한다.
    insert_user(&pool, "fcm_noop").await;
    insert_pro_entitlement(&pool, "fcm_noop").await;
    insert_user_settings(&pool, "fcm_noop").await;
    insert_subscription(&pool, "fcm_noop", -60).await;
    insert_fcm_token(&pool, "fcm_noop", "token-a").await;

    let summary = dispatch_due_briefings(&pool, &NoopPushSender, chrono::Utc::now(), 10)
        .await
        .unwrap();

    assert_eq!(summary.succeeded, 1);
    assert_eq!(summary.failed, 0);
}

// ============================================================
// 라우트 테스트
// ============================================================

fn app_with_scheduler_secret(pool: PgPool, secret: &str) -> axum::Router {
    std::env::set_var("SCHEDULER_SECRET", secret);
    let push_sender: Arc<dyn PushSender> = Arc::new(NoopPushSender);
    promiso_backend::routes::internal::router()
        .layer(axum::Extension(push_sender))
        .with_state(pool)
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_handler_returns_ok_with_valid_secret(pool: PgPool) {
    let app = app_with_scheduler_secret(pool, "test-scheduler-secret");

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/internal/briefing/dispatch")
                .header("X-Scheduler-Secret", "test-scheduler-secret")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_handler_returns_unauthorized_with_wrong_secret(pool: PgPool) {
    let app = app_with_scheduler_secret(pool, "test-scheduler-secret");

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/internal/briefing/dispatch")
                .header("X-Scheduler-Secret", "wrong-secret")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn dispatch_handler_returns_unauthorized_without_secret_header(pool: PgPool) {
    let app = app_with_scheduler_secret(pool, "test-scheduler-secret");

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/internal/briefing/dispatch")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
