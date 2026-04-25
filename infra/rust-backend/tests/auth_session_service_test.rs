use promiso_backend::middleware::auth::ServerAuth;
use promiso_backend::models::auth::{CreateSessionInput, RefreshSessionInput};
use promiso_backend::services::auth_service;
use sqlx::PgPool;

async fn insert_auth_account(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO auth_accounts (user_id, provider_type, provider_uid, email) \
         VALUES ($1, 'google', $2, $3)",
    )
    .bind(user_id)
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .execute(pool)
    .await
    .expect("insert auth account");
}

fn server_auth() -> ServerAuth {
    ServerAuth::new(
        Some("test-server-secret".to_string()),
        "promiso-test".to_string(),
        900,
    )
}

#[sqlx::test(migrations = "./migrations")]
async fn create_session_persists_hashed_refresh_token(pool: PgPool) {
    insert_auth_account(&pool, "auth_user_1").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_user_1".to_string(),
            device_id: "device-1".to_string(),
            platform: "ios".to_string(),
            app_version: Some("1.2.3".to_string()),
            user_agent: Some("PromisoTests".to_string()),
        },
    )
    .await
    .expect("create session");

    let stored_hash: (String,) =
        sqlx::query_as("SELECT refresh_token_hash FROM auth_sessions WHERE user_id = $1")
            .bind("auth_user_1")
            .fetch_one(&pool)
            .await
            .expect("fetch stored hash");

    assert!(!tokens.access_token.is_empty());
    assert!(!tokens.refresh_token.is_empty());
    assert_ne!(stored_hash.0, tokens.refresh_token);

    let claims = server_auth()
        .verify_access_token(&tokens.access_token)
        .expect("access token should verify");
    assert_eq!(claims.uid, "auth_user_1");
    assert_eq!(claims.email.as_deref(), Some("auth_user_1@test.com"));
}

#[sqlx::test(migrations = "./migrations")]
async fn refresh_session_rotates_token_and_rejects_reuse(pool: PgPool) {
    insert_auth_account(&pool, "auth_user_2").await;

    let initial = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_user_2".to_string(),
            device_id: "device-2".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let rotated = auth_service::refresh_session(
        &pool,
        &server_auth(),
        RefreshSessionInput {
            refresh_token: initial.refresh_token.clone(),
            device_id: "device-2".to_string(),
        },
    )
    .await
    .expect("refresh session");

    assert_ne!(initial.refresh_token, rotated.refresh_token);

    let reused = auth_service::refresh_session(
        &pool,
        &server_auth(),
        RefreshSessionInput {
            refresh_token: initial.refresh_token,
            device_id: "device-2".to_string(),
        },
    )
    .await;

    assert!(reused.is_err());
}

#[sqlx::test(migrations = "./migrations")]
async fn refresh_session_rejects_device_mismatch(pool: PgPool) {
    insert_auth_account(&pool, "auth_user_3").await;

    let initial = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "auth_user_3".to_string(),
            device_id: "device-3".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let refreshed = auth_service::refresh_session(
        &pool,
        &server_auth(),
        RefreshSessionInput {
            refresh_token: initial.refresh_token,
            device_id: "device-other".to_string(),
        },
    )
    .await;

    assert!(refreshed.is_err());
}
