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

fn test_config() -> Config {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");
    std::env::set_var("AUTH_JWT_SECRET", "test-server-secret");
    std::env::set_var("AUTH_JWT_ISSUER", "promiso-test");
    Config::from_env()
}

async fn insert_auth_account(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO auth_accounts \
         (user_id, provider_type, provider_uid, email, display_name, profile_image_url) \
         VALUES ($1, 'google', $2, $3, $4, $5)",
    )
    .bind(user_id)
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .bind(format!("display-{user_id}"))
    .bind(format!("https://example.com/{user_id}.jpg"))
    .execute(pool)
    .await
    .expect("insert auth account");
}

async fn insert_user(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email, profile_url) \
         VALUES ($1, $2, $3, 'google', $4, $5, $6)",
    )
    .bind(user_id)
    .bind(format!("name-{user_id}"))
    .bind(format!(
        "nick{}",
        &user_id[user_id.len().saturating_sub(4)..]
    ))
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .bind(format!("https://cdn.example.com/{user_id}.jpg"))
    .execute(pool)
    .await
    .expect("insert user");
}

fn server_auth() -> ServerAuth {
    ServerAuth::new(
        Some("test-server-secret".to_string()),
        "promiso-test".to_string(),
        900,
    )
}

#[sqlx::test(migrations = "./migrations")]
async fn auth_me_returns_auth_subject_and_profile_status(pool: PgPool) {
    insert_auth_account(&pool, "auth_me_user").await;
    insert_user(&pool, "auth_me_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_me_user".to_string(),
            device_id: "device-auth-me".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .uri("/api/v1/auth/me")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["userId"], "auth_me_user");
    assert_eq!(json["data"]["provider"], "google");
    assert_eq!(json["data"]["hasProfile"], true);
    assert_eq!(
        json["data"]["profileImageUrl"],
        "https://cdn.example.com/auth_me_user.jpg"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn auth_refresh_rotates_tokens_via_public_route(pool: PgPool) {
    insert_auth_account(&pool, "auth_refresh_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_refresh_user".to_string(),
            device_id: "device-refresh".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool.clone(), &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/auth/refresh")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "refreshToken": tokens.refresh_token,
                        "deviceId": "device-refresh"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert!(json["data"]["accessToken"].as_str().is_some());
    assert!(json["data"]["refreshToken"].as_str().is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn auth_logout_revokes_current_session(pool: PgPool) {
    insert_auth_account(&pool, "auth_logout_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_logout_user".to_string(),
            device_id: "device-logout".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool.clone(), &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/auth/logout")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let reused = auth_service::refresh_session(
        &pool,
        &server_auth(),
        promiso_backend::models::auth::RefreshSessionInput {
            refresh_token: tokens.refresh_token,
            device_id: "device-logout".to_string(),
        },
    )
    .await;

    assert!(reused.is_err());
}

#[sqlx::test(migrations = "./migrations")]
async fn auth_logout_all_revokes_all_user_sessions(pool: PgPool) {
    insert_auth_account(&pool, "auth_logout_all_user").await;

    let session_a = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_logout_all_user".to_string(),
            device_id: "device-a".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session a");

    let session_b = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_logout_all_user".to_string(),
            device_id: "device-b".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session b");

    let response = routes::create_router(pool.clone(), &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/auth/logout-all")
                .header(
                    "authorization",
                    format!("Bearer {}", session_a.access_token),
                )
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let refresh_a = auth_service::refresh_session(
        &pool,
        &server_auth(),
        promiso_backend::models::auth::RefreshSessionInput {
            refresh_token: session_a.refresh_token,
            device_id: "device-a".to_string(),
        },
    )
    .await;
    let refresh_b = auth_service::refresh_session(
        &pool,
        &server_auth(),
        promiso_backend::models::auth::RefreshSessionInput {
            refresh_token: session_b.refresh_token,
            device_id: "device-b".to_string(),
        },
    )
    .await;

    assert!(refresh_a.is_err());
    assert!(refresh_b.is_err());
}
