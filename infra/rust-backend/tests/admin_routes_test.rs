use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Extension;
use http_body_util::BodyExt;
use promiso_backend::middleware::auth::Claims;
use serde_json::json;
use sqlx::PgPool;
use tower::ServiceExt;

fn app_with_claims(pool: PgPool, user_id: &str) -> axum::Router {
    promiso_backend::routes::admin::router()
        .layer(Extension(Claims {
            uid: user_id.to_string(),
            email: Some(format!("{user_id}@promiso.test")),
        }))
        .with_state(pool)
}

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
async fn dashboard_summary_route_returns_counts(pool: PgPool) {
    insert_admin(&pool, "admin_owner_route_1", "owner").await;
    insert_user(&pool, "admin_route_user_1", "유저1", "닉1").await;
    insert_user(&pool, "admin_route_user_2", "유저2", "닉2").await;

    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES
            ('admin_route_user_1', true, 'subscription', 'subscribed', false),
            ('admin_route_user_2', false, 'none', NULL, false)",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert entitlements");

    let response = app_with_claims(pool, "admin_owner_route_1")
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/dashboard/summary")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["summary"]["totalUsers"], 2);
    assert_eq!(json["data"]["summary"]["proUsers"], 1);
    assert_eq!(json["data"]["summary"]["freeUsers"], 1);
    assert_eq!(json["data"]["summary"]["pushJobCount"], 0);
    assert_eq!(json["data"]["summary"]["remoteConfigVersion"], serde_json::Value::Null);
}

#[sqlx::test(migrations = "./migrations")]
async fn user_summary_route_returns_results(pool: PgPool) {
    insert_admin(&pool, "admin_support_route_1", "support").await;
    insert_user(&pool, "summary_route_user_1", "홍길동", "길동").await;

    let response = app_with_claims(pool, "admin_support_route_1")
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/users?query=summary_route_user_1%40promiso.test&field=email")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["results"][0]["userId"], "summary_route_user_1");
    assert_eq!(json["data"]["hasMore"], false);
}

#[sqlx::test(migrations = "./migrations")]
async fn user_timeline_route_returns_summary_and_audit_logs(pool: PgPool) {
    insert_admin(&pool, "admin_support_route_2", "support").await;
    insert_user(&pool, "timeline_route_user_1", "타임라인", "타임").await;

    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id, updated_at)
         VALUES ($1, 'subscribed', 'com.promiso.pro.monthly', 'otx_timeline_route', NOW())",
    )
    .bind("timeline_route_user_1")
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    sqlx::query(
        "INSERT INTO admin_audit_logs
            (actor_id, action, target_id, target_type, created_at)
         VALUES
            ('admin_support_route_2', 'touch_user', 'timeline_route_user_1', 'user', NOW())",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert audit log");

    let response = app_with_claims(pool, "admin_support_route_2")
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/users/timeline_route_user_1/timeline?limit=10")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["summary"]["userId"], "timeline_route_user_1");
    assert_eq!(json["data"]["subscription"]["status"], "subscribed");
    assert_eq!(json["data"]["auditLogs"][0]["action"], "touch_user");
    assert_eq!(json["data"]["auditLogs"][0]["actorId"], "admin_support_route_2");
    assert_eq!(json["data"]["auditLogs"][0]["targetType"], "user");
    assert!(json["data"]["auditLogs"][0]["id"].is_string());
}

#[sqlx::test(migrations = "./migrations")]
async fn grant_override_route_writes_override_and_audit_log(pool: PgPool) {
    insert_admin(&pool, "admin_support_route_3", "support").await;
    insert_user(&pool, "override_route_user_1", "오버", "라이드").await;

    let response = app_with_claims(pool.clone(), "admin_support_route_3")
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/entitlements/grant")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({
                        "userId": "override_route_user_1",
                        "reason": "manual support"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let override_row: (bool,) =
        sqlx::query_as("SELECT is_active FROM entitlement_overrides WHERE user_id = $1")
            .bind("override_route_user_1")
            .fetch_one(&pool)
            .await
            .expect("override row should exist");
    assert!(override_row.0);

    let audit_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM admin_audit_logs
         WHERE actor_id = $1 AND action = 'grant_entitlement_override'",
    )
    .bind("admin_support_route_3")
    .fetch_one(&pool)
    .await
    .expect("audit log should exist");
    assert_eq!(audit_count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn revoke_override_route_disables_override(pool: PgPool) {
    insert_admin(&pool, "admin_support_route_4", "support").await;
    insert_user(&pool, "override_route_user_2", "리보크", "테스트").await;

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('override_route_user_2', true, 'manual_pro_grant', 'manual support', 'admin_support_route_4')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    let response = app_with_claims(pool.clone(), "admin_support_route_4")
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/entitlements/revoke")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({
                        "userId": "override_route_user_2",
                        "reason": "cleanup"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let override_row: (bool,) =
        sqlx::query_as("SELECT is_active FROM entitlement_overrides WHERE user_id = $1")
            .bind("override_route_user_2")
            .fetch_one(&pool)
            .await
            .expect("override row should exist");
    assert!(!override_row.0);
}

#[sqlx::test(migrations = "./migrations")]
async fn pro_plan_dashboard_route_returns_breakdown(pool: PgPool) {
    insert_admin(&pool, "admin_owner_route_2", "owner").await;
    insert_user(&pool, "pro_dashboard_route_user_1", "플랜1", "월간").await;

    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id, last_offer_type, last_offer_identifier)
         VALUES
            ('pro_dashboard_route_user_1', 'subscribed', 'com.promiso.pro.monthly', 'otx_route_dashboard_1', 3, 'SPRING2026')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    let response = app_with_claims(pool, "admin_owner_route_2")
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/pro-plan/dashboard")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["dashboard"]["overview"]["totalUsers"], 1);
    assert_eq!(json["data"]["dashboard"]["overview"]["proUsers"], 0);
    assert_eq!(json["data"]["dashboard"]["breakdown"]["monthly"]["count"], 1);
    assert_eq!(json["data"]["dashboard"]["revenue"]["estimatedMRR"], 3900);
    assert_eq!(json["data"]["dashboard"]["coupons"]["total"], 0);
    assert_eq!(json["data"]["dashboard"]["offerCodes"]["totalRedemptions"], 1);
    assert_eq!(
        json["data"]["dashboard"]["offerCodes"]["recentRedemptions"][0]["offerIdentifier"],
        "SPRING2026"
    );
    assert_eq!(
        json["data"]["dashboard"]["recentActivities"][0]["type"],
        "subscribed"
    );
}
