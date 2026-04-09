use axum::body::Body;
use axum::http::{Request, StatusCode};
use promiso_backend::config::Config;
use promiso_backend::middleware::auth::ServerAuth;
use promiso_backend::models::auth::CreateSessionInput;
use promiso_backend::routes;
use promiso_backend::services::auth_service;
use sqlx::PgPool;
use tower::ServiceExt;

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

async fn insert_user(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(user_id)
    .bind(format!("name-{user_id}"))
    .bind(format!("nick{}", &user_id[user_id.len().saturating_sub(4)..]))
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .execute(pool)
    .await
    .expect("insert user");
}

#[sqlx::test(migrations = "./migrations")]
async fn widget_snapshot_accepts_server_access_token(pool: PgPool) {
    insert_auth_account(&pool, "widget_server_user").await;
    insert_user(&pool, "widget_server_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "widget_server_user".to_string(),
            device_id: "device-widget-server".to_string(),
            platform: "ios".to_string(),
            app_version: Some("1.0.0".to_string()),
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .uri("/api/v1/widget/snapshot")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}
