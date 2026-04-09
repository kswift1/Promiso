use axum::body::Body;
use axum::http::{Request, StatusCode};
use promiso_backend::services::briefing_scheduler_service::{
    dispatch_due_briefings, verify_scheduler_secret,
};
use sqlx::PgPool;
use tower::ServiceExt;

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
    let summary = dispatch_due_briefings(&pool, now, 10).await.unwrap();

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
    let summary = dispatch_due_briefings(&pool, now, 10).await.unwrap();

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
    let summary = dispatch_due_briefings(&pool, now, 1).await.unwrap();

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

    dispatch_due_briefings(&pool, now, 10).await.unwrap();

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
    let summary = dispatch_due_briefings(&pool, now, 10).await.unwrap();

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
    let summary = dispatch_due_briefings(&pool, now, 10).await.unwrap();

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
    let summary = dispatch_due_briefings(&pool, now, 10).await.unwrap();

    // due 항목: 2개 (pro 1 + free 1)
    assert_eq!(summary.total_due, 2);
    // processed: 2개 모두 처리 시도
    assert_eq!(summary.processed, 2);
    // skipped: 1개 (non-pro)
    assert_eq!(summary.skipped, 1);
    // succeeded + failed + skipped == processed
    assert_eq!(
        summary.succeeded + summary.failed + summary.skipped,
        summary.processed
    );
}

// ============================================================
// 라우트 테스트
// ============================================================

fn app_with_scheduler_secret(pool: PgPool, secret: &str) -> axum::Router {
    std::env::set_var("SCHEDULER_SECRET", secret);
    promiso_backend::routes::internal::router().with_state(pool)
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
