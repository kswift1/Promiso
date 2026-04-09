use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::middleware::auth::ServerAuth;
use promiso_backend::models::auth::CreateSessionInput;
use promiso_backend::routes;
use promiso_backend::services::auth_service;
use sqlx::PgPool;
use tower::ServiceExt;
use uuid::Uuid;

fn test_config() -> Config {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");
    std::env::set_var("AUTH_JWT_SECRET", "test-server-secret");
    std::env::set_var("AUTH_JWT_ISSUER", "promiso-test");
    Config::from_env()
}

fn server_auth() -> ServerAuth {
    ServerAuth::new(
        Some("test-server-secret".to_string()),
        "promiso-test".to_string(),
        900,
    )
}

async fn insert_auth_account(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO auth_accounts \
         (user_id, provider_type, provider_uid, email, display_name) \
         VALUES ($1, 'google', $2, $3, $4)",
    )
    .bind(user_id)
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .bind(format!("display-{user_id}"))
    .execute(pool)
    .await
    .expect("insert auth account");
}

async fn insert_user(pool: &PgPool, user_id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(user_id)
    .bind(format!("name-{user_id}"))
    .bind(nickname)
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .execute(pool)
    .await
    .expect("insert user");
}

async fn create_session(pool: &PgPool, user_id: &str, device_id: &str) -> String {
    let tokens = auth_service::create_session(
        pool,
        &server_auth(),
        CreateSessionInput {
            user_id: user_id.to_string(),
            device_id: device_id.to_string(),
            platform: "ios".to_string(),
            app_version: Some("1.0.0".to_string()),
            user_agent: Some("users-delete-test".to_string()),
        },
    )
    .await
    .expect("create session");

    tokens.access_token
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_my_account_rejects_group_host(pool: PgPool) {
    insert_auth_account(&pool, "delete_host_user").await;
    insert_user(&pool, "delete_host_user", "호스트유저").await;

    let group_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO groups (id, name, max_members, invite_code) \
         VALUES ($1, '호스트그룹', 5, 'HOST01')",
    )
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert group");

    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')",
    )
    .bind(group_id)
    .bind("delete_host_user")
    .execute(&pool)
    .await
    .expect("insert host membership");

    let access_token = create_session(&pool, "delete_host_user", "device-host").await;

    let response = routes::create_router(pool.clone(), &test_config())
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri("/api/v1/users/me")
                .header("authorization", format!("Bearer {}", access_token))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::PRECONDITION_FAILED);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["error"]["code"], "failed-precondition");

    let remaining_user: Option<String> = sqlx::query_scalar("SELECT id FROM users WHERE id = $1")
        .bind("delete_host_user")
        .fetch_optional(&pool)
        .await
        .expect("fetch remaining user");
    assert_eq!(remaining_user.as_deref(), Some("delete_host_user"));
}

#[sqlx::test(migrations = "./migrations")]
async fn delete_my_account_cleans_auth_and_user_state_but_preserves_subscription_history(
    pool: PgPool,
) {
    insert_auth_account(&pool, "delete_regular_user").await;
    insert_user(&pool, "delete_regular_user", "일반유저").await;
    insert_user(&pool, "delete_group_admin", "그룹관리자").await;

    sqlx::query(
        "INSERT INTO user_settings (user_id, briefing_notification_hour, briefing_timezone, briefing_language, briefing_style) \
         VALUES ($1, 9, 'Asia/Seoul', 'ko', 'friendly')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert user settings");

    sqlx::query(
        "INSERT INTO briefing_subscriptions (user_id, notification_hour, timezone, language, style, next_dispatch_at) \
         VALUES ($1, 9, 'Asia/Seoul', 'ko', 'friendly', NOW() + INTERVAL '1 hour')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert briefing subscription");

    sqlx::query(
        "INSERT INTO entitlements (user_id, has_pro, source, override_active) \
         VALUES ($1, TRUE, 'subscription', FALSE)",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert entitlement");

    sqlx::query(
        "INSERT INTO entitlement_overrides (user_id, is_active, override_type) \
         VALUES ($1, FALSE, 'manual')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert entitlement override");

    sqlx::query("INSERT INTO admin_users (user_id, role) VALUES ($1, 'support')")
        .bind("delete_regular_user")
        .execute(&pool)
        .await
        .expect("insert admin user");

    sqlx::query("INSERT INTO subscriptions (user_id, status) VALUES ($1, 'subscribed')")
        .bind("delete_regular_user")
        .execute(&pool)
        .await
        .expect("insert subscription");

    sqlx::query(
        "INSERT INTO subscription_owners (original_transaction_id, user_id, product_id) \
         VALUES ('orig-delete-1', $1, 'promiso.pro.monthly')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert subscription owner");

    sqlx::query(
        "INSERT INTO schedules (schedule_type, user_id, title, start_at) \
         VALUES ('personal', $1, '삭제될 개인 일정', NOW() + INTERVAL '1 day')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert personal schedule");

    let device_id: Uuid = sqlx::query_scalar(
        "INSERT INTO devices (user_id, device_id, platform) \
         VALUES ($1, 'ios-device-delete', 'ios') \
         RETURNING id",
    )
    .bind("delete_regular_user")
    .fetch_one(&pool)
    .await
    .expect("insert device");

    sqlx::query(
        "INSERT INTO notification_endpoints (device_id, provider, token) \
         VALUES ($1, 'fcm', 'fcm-delete-token')",
    )
    .bind(device_id)
    .execute(&pool)
    .await
    .expect("insert notification endpoint");

    sqlx::query(
        "INSERT INTO live_activity_endpoints (device_id, push_to_start_token) \
         VALUES ($1, 'push-to-start-delete')",
    )
    .bind(device_id)
    .execute(&pool)
    .await
    .expect("insert live activity endpoint");

    sqlx::query(
        "INSERT INTO notifications (user_id, notification_type, title, body) \
         VALUES ($1, 'system', '탈퇴 테스트', '삭제 대상')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert notification");

    sqlx::query(
        "INSERT INTO briefing_cache (user_id, date_key, prompt_key, summary, detail) \
         VALUES ($1, CURRENT_DATE, 'prompt-key', 'summary', 'detail')",
    )
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert briefing cache");

    let group_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO groups (id, name, max_members, invite_code) \
         VALUES ($1, '잔존그룹', 5, 'KEEP01')",
    )
    .bind(group_id)
    .execute(&pool)
    .await
    .expect("insert group");

    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin'), ($1, $3, 'member')",
    )
    .bind(group_id)
    .bind("delete_group_admin")
    .bind("delete_regular_user")
    .execute(&pool)
    .await
    .expect("insert memberships");

    let access_token = create_session(&pool, "delete_regular_user", "device-regular").await;

    let response = routes::create_router(pool.clone(), &test_config())
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri("/api/v1/users/me")
                .header("authorization", format!("Bearer {}", access_token))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let users_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE id = $1")
        .bind("delete_regular_user")
        .fetch_one(&pool)
        .await
        .expect("count users");
    assert_eq!(users_count, 0);

    let auth_accounts_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM auth_accounts WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count auth accounts");
    assert_eq!(auth_accounts_count, 0);

    let auth_sessions_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM auth_sessions WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count auth sessions");
    assert_eq!(auth_sessions_count, 0);

    let user_settings_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM user_settings WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count user settings");
    assert_eq!(user_settings_count, 0);

    let briefing_subscriptions_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM briefing_subscriptions WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count briefing subscriptions");
    assert_eq!(briefing_subscriptions_count, 0);

    let entitlements_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM entitlements WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count entitlements");
    assert_eq!(entitlements_count, 0);

    let entitlement_overrides_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM entitlement_overrides WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count entitlement overrides");
    assert_eq!(entitlement_overrides_count, 0);

    let admin_users_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM admin_users WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count admin users");
    assert_eq!(admin_users_count, 0);

    let group_members_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM group_members WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count group members");
    assert_eq!(group_members_count, 0);

    let schedules_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM schedules WHERE user_id = $1")
        .bind("delete_regular_user")
        .fetch_one(&pool)
        .await
        .expect("count schedules");
    assert_eq!(schedules_count, 0);

    let devices_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM devices WHERE user_id = $1")
        .bind("delete_regular_user")
        .fetch_one(&pool)
        .await
        .expect("count devices");
    assert_eq!(devices_count, 0);

    let notifications_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM notifications WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count notifications");
    assert_eq!(notifications_count, 0);

    let briefing_cache_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM briefing_cache WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count briefing cache");
    assert_eq!(briefing_cache_count, 0);

    let subscriptions_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM subscriptions WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count subscriptions");
    assert_eq!(subscriptions_count, 1);

    let subscription_owners_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM subscription_owners WHERE user_id = $1")
            .bind("delete_regular_user")
            .fetch_one(&pool)
            .await
            .expect("count subscription owners");
    assert_eq!(subscription_owners_count, 1);
}
