//! Admin subscription cutover tests
//!
//! 목표:
//! - Firebase callable이 담당하던 summary/timeline/override 로직을 Rust 서비스로 옮긴다.
//! - 권한 검사, 입력 검증, audit log 기록을 서버 테스트로 먼저 고정한다.

use chrono::{Duration, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::services::admin_subscription_service::{
    build_dashboard_summary, build_pro_plan_dashboard, get_user_summary, get_user_summary_with_filters,
    get_user_timeline, grant_entitlement_override, revoke_entitlement_override,
    GrantEntitlementOverrideRequest, RevokeEntitlementOverrideRequest,
};
use sqlx::PgPool;

async fn insert_user(pool: &PgPool, id: &str, name: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email)
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(id)
    .bind(name)
    .bind(nickname)
    .bind(format!("provider-{id}"))
    .bind(format!("{id}@promiso.test"))
    .execute(pool)
    .await
    .expect("Failed to insert user");
}

async fn insert_admin(pool: &PgPool, id: &str, role: &str) {
    sqlx::query(
        "INSERT INTO admin_users (user_id, email, role, enabled)
         VALUES ($1, $2, $3::admin_role, true)",
    )
    .bind(id)
    .bind(format!("{id}@promiso.test"))
    .bind(role)
    .execute(pool)
    .await
    .expect("Failed to insert admin");
}

#[sqlx::test(migrations = "./migrations")]
async fn dashboard_summary_counts_total_pro_free_and_active_override(pool: PgPool) {
    insert_admin(&pool, "admin_owner_1", "owner").await;
    insert_user(&pool, "admin_user_1", "유저1", "닉1").await;
    insert_user(&pool, "admin_user_2", "유저2", "닉2").await;

    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES
            ('admin_user_1', true, 'subscription', 'subscribed', false),
            ('admin_user_2', false, 'none', NULL, false)",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert entitlements");

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('admin_user_1', true, 'manual_pro_grant', 'support', 'admin_owner_1')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    let summary = build_dashboard_summary(&pool, "admin_owner_1")
        .await
        .expect("dashboard summary should succeed");

    assert_eq!(summary.total_users, 2);
    assert_eq!(summary.pro_users, 1);
    assert_eq!(summary.free_users, 1);
    assert_eq!(summary.active_overrides, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn user_summary_search_by_email_returns_matching_user(pool: PgPool) {
    insert_admin(&pool, "admin_support_1", "support").await;
    insert_user(&pool, "summary_user_1", "홍길동", "길동").await;

    let result = get_user_summary(
        &pool,
        "admin_support_1",
        "summary_user_1@promiso.test",
        "email",
    )
    .await
    .expect("user summary should succeed");

    assert_eq!(result.results.len(), 1);
    assert_eq!(result.results[0].user_id, "summary_user_1");
    assert_eq!(result.results[0].group_count, 0);
    assert_eq!(result.results[0].device_count, 0);
    assert_eq!(result.results[0].personal_event_count, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn user_summary_filters_override_state_and_honors_limit(pool: PgPool) {
    insert_admin(&pool, "admin_support_filter_1", "support").await;
    insert_user(&pool, "filter_user_1", "필터1", "닉1").await;
    insert_user(&pool, "filter_user_2", "필터2", "닉2").await;

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('filter_user_1', true, 'manual_pro_grant', 'manual support', 'admin_support_filter_1')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    let result = get_user_summary_with_filters(
        &pool,
        "admin_support_filter_1",
        None,
        "all",
        "all",
        "active",
        1,
        None,
    )
    .await
    .expect("filtered user summary should succeed");

    assert_eq!(result.results.len(), 1);
    assert_eq!(result.results[0].user_id, "filter_user_1");
    assert!(result.results[0].override_active);
    assert_eq!(result.has_more, false);
}

#[sqlx::test(migrations = "./migrations")]
async fn user_summary_includes_joined_counts_and_subscription_status(pool: PgPool) {
    insert_admin(&pool, "admin_support_join_1", "support").await;
    insert_user(&pool, "joined_user_1", "조인유저", "조인닉").await;

    let group_id: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code)
         VALUES ('테스트그룹', 'ABC123')
         RETURNING id",
    )
    .fetch_one(&pool)
    .await
    .expect("Failed to insert group");

    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'member')",
    )
    .bind(group_id.0)
    .bind("joined_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert group member");

    sqlx::query(
        "INSERT INTO devices (user_id, device_id, platform)
         VALUES ($1, 'device_joined_user_1', 'ios')",
    )
    .bind("joined_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert device");

    sqlx::query(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at, reminder_minutes_before)
         VALUES ('personal', $1, '개인일정', NOW(), 30)",
    )
    .bind("joined_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert personal schedule");

    sqlx::query(
        "INSERT INTO subscriptions (user_id, status, product_id, original_transaction_id, updated_at)
         VALUES ($1, 'subscribed', 'com.promiso.pro.monthly', 'otx_joined_user_1', NOW())",
    )
    .bind("joined_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    let result = get_user_summary(&pool, "admin_support_join_1", "joined_user_1", "userId")
        .await
        .expect("user summary should succeed");

    assert_eq!(result.results.len(), 1);
    assert_eq!(result.results[0].group_count, 1);
    assert_eq!(result.results[0].device_count, 1);
    assert_eq!(result.results[0].personal_event_count, 1);
    assert_eq!(
        result.results[0].subscription_status.as_deref(),
        Some("subscribed")
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn user_timeline_returns_summary_subscription_override_and_audit_logs(pool: PgPool) {
    insert_admin(&pool, "admin_support_2", "support").await;
    insert_user(&pool, "timeline_user_1", "타임라인", "타임").await;

    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id, updated_at)
         VALUES ($1, 'subscribed', 'com.promiso.pro.monthly', 'otx_timeline', NOW())",
    )
    .bind("timeline_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('timeline_user_1', true, 'manual_pro_grant', 'manual support', 'admin_support_2')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    sqlx::query(
        "INSERT INTO admin_audit_logs
            (actor_id, action, target_id, target_type, before_data, after_data, created_at)
         VALUES
            ('admin_support_2', 'grant_entitlement_override', 'timeline_user_1', 'user', '{\"before\":true}', '{\"after\":true}', NOW()),
            ('admin_support_2', 'touch_user', 'timeline_user_1', 'user', NULL, NULL, NOW() - interval '1 hour')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert audit logs");

    let timeline = get_user_timeline(&pool, "admin_support_2", "timeline_user_1", 20)
        .await
        .expect("timeline should succeed");

    assert_eq!(timeline.summary.user_id, "timeline_user_1");
    assert_eq!(timeline.subscription.status.as_deref(), Some("subscribed"));
    assert!(timeline.r#override.is_some());
    assert_eq!(timeline.audit_logs.len(), 2);
    assert_eq!(timeline.audit_logs[0].action.as_deref(), Some("grant_entitlement_override"));
    assert_eq!(timeline.audit_logs[0].actor_id.as_deref(), Some("admin_support_2"));
    assert_eq!(timeline.audit_logs[0].target_type.as_deref(), Some("user"));
    assert!(timeline.audit_logs[0].id.len() > 0);
    assert!(timeline.audit_logs[0].before.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn grant_override_requires_reason(pool: PgPool) {
    insert_admin(&pool, "admin_support_3", "support").await;
    insert_user(&pool, "grant_user_1", "그랜트", "부여").await;

    let result = grant_entitlement_override(
        &pool,
        "admin_support_3",
        GrantEntitlementOverrideRequest {
            user_id: "grant_user_1".to_string(),
            reason: "".to_string(),
            expires_at: None,
        },
    )
    .await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn grant_override_rejects_invalid_expiration_format(pool: PgPool) {
    insert_admin(&pool, "admin_support_4", "support").await;
    insert_user(&pool, "grant_user_2", "그랜트2", "부여2").await;

    let result = grant_entitlement_override(
        &pool,
        "admin_support_4",
        GrantEntitlementOverrideRequest {
            user_id: "grant_user_2".to_string(),
            reason: "manual support".to_string(),
            expires_at: Some("not-a-date".to_string()),
        },
    )
    .await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn grant_override_writes_override_and_audit_log(pool: PgPool) {
    insert_admin(&pool, "admin_support_5", "support").await;
    insert_user(&pool, "grant_user_3", "그랜트3", "부여3").await;

    grant_entitlement_override(
        &pool,
        "admin_support_5",
        GrantEntitlementOverrideRequest {
            user_id: "grant_user_3".to_string(),
            reason: "manual support".to_string(),
            expires_at: Some((Utc::now() + Duration::days(30)).to_rfc3339()),
        },
    )
    .await
    .expect("grant should succeed");

    let override_row: (bool,) =
        sqlx::query_as("SELECT is_active FROM entitlement_overrides WHERE user_id = $1")
            .bind("grant_user_3")
            .fetch_one(&pool)
            .await
            .expect("override row should exist");
    assert!(override_row.0);

    let audit_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM admin_audit_logs
         WHERE target_id = $1 AND action = 'grant_entitlement_override'",
    )
    .bind("grant_user_3")
    .fetch_one(&pool)
    .await
    .expect("audit row should exist");
    assert_eq!(audit_count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn revoke_override_requires_existing_override(pool: PgPool) {
    insert_admin(&pool, "admin_support_6", "support").await;

    let result = revoke_entitlement_override(
        &pool,
        "admin_support_6",
        RevokeEntitlementOverrideRequest {
            user_id: "missing_override_user".to_string(),
            reason: Some("cleanup".to_string()),
        },
    )
    .await;

    assert!(matches!(result, Err(AppError::NotFound(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn revoke_override_disables_row_and_writes_audit_log(pool: PgPool) {
    insert_admin(&pool, "admin_support_7", "support").await;
    insert_user(&pool, "revoke_user_1", "리보크", "회수").await;
    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('revoke_user_1', true, 'manual_pro_grant', 'manual support', 'admin_support_7')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    revoke_entitlement_override(
        &pool,
        "admin_support_7",
        RevokeEntitlementOverrideRequest {
            user_id: "revoke_user_1".to_string(),
            reason: Some("cleanup".to_string()),
        },
    )
    .await
    .expect("revoke should succeed");

    let override_row: (bool,) =
        sqlx::query_as("SELECT is_active FROM entitlement_overrides WHERE user_id = $1")
            .bind("revoke_user_1")
            .fetch_one(&pool)
            .await
            .expect("override row should exist");
    assert!(!override_row.0);

    let audit_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM admin_audit_logs
         WHERE target_id = $1 AND action = 'revoke_entitlement_override'",
    )
    .bind("revoke_user_1")
    .fetch_one(&pool)
    .await
    .expect("audit row should exist");
    assert_eq!(audit_count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn pro_plan_dashboard_counts_products_grace_period_and_offer_codes(pool: PgPool) {
    insert_admin(&pool, "admin_owner_2", "owner").await;
    insert_user(&pool, "plan_user_monthly", "월간", "월간").await;
    insert_user(&pool, "plan_user_yearly", "연간", "연간").await;
    insert_user(&pool, "plan_user_lifetime", "평생", "평생").await;
    insert_user(&pool, "plan_user_grace", "유예", "유예").await;

    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id, last_offer_type, last_offer_identifier, updated_at)
         VALUES
            ('plan_user_monthly', 'subscribed', 'com.promiso.pro.monthly', 'otx_m', NULL, NULL, NOW()),
            ('plan_user_yearly', 'subscribed', 'com.promiso.pro.yearly', 'otx_y', 3, 'SPRING2026', NOW()),
            ('plan_user_lifetime', 'lifetime', 'com.promiso.pro.lifetime', 'otx_l', NULL, NULL, NOW()),
            ('plan_user_grace', 'grace_period', 'com.promiso.pro.monthly', 'otx_g', NULL, NULL, NOW())",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert subscriptions");

    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES
            ('plan_user_monthly', true, 'subscription', 'subscribed', false),
            ('plan_user_yearly', true, 'subscription', 'subscribed', false),
            ('plan_user_lifetime', true, 'subscription', 'lifetime', false),
            ('plan_user_grace', true, 'subscription', 'grace_period', false)",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert entitlements");

    let dashboard = build_pro_plan_dashboard(&pool, "admin_owner_2")
        .await
        .expect("pro plan dashboard should succeed");

    assert_eq!(dashboard.breakdown.monthly.count, 1);
    assert_eq!(dashboard.breakdown.yearly.count, 1);
    assert_eq!(dashboard.breakdown.lifetime.count, 1);
    assert_eq!(dashboard.breakdown.grace_period.count, 1);
    assert_eq!(dashboard.overview.total_users, 4);
    assert_eq!(dashboard.overview.pro_users, 4);
    assert_eq!(dashboard.overview.pro_subscription_users, 4);
    assert_eq!(dashboard.revenue.estimated_mrr, 7150);
    assert_eq!(dashboard.coupons.total, 0);
    assert_eq!(dashboard.offer_codes.total_redemptions, 1);
    assert_eq!(dashboard.offer_codes.recent_redemptions.len(), 1);
    assert_eq!(
        dashboard.offer_codes.recent_redemptions[0].offer_identifier,
        "SPRING2026"
    );
    assert_eq!(dashboard.recent_activities.len(), 4);
}
