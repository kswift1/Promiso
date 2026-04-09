use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::models::auth::CreateSessionInput;
use promiso_backend::routes;
use promiso_backend::services::auth_service;
use rsa::pkcs8::{EncodePrivateKey, LineEnding};
use rsa::rand_core::OsRng;
use rsa::RsaPrivateKey;
use serde_json::Value;
use sqlx::PgPool;
use std::sync::OnceLock;
use tower::ServiceExt;

fn test_config() -> Config {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");
    std::env::set_var("AUTH_JWT_SECRET", "test-server-secret");
    std::env::set_var("AUTH_JWT_ISSUER", "promiso-test");
    std::env::set_var("GCS_UPLOAD_BUCKET", "promiso-test-media");
    std::env::set_var(
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        service_account_json().to_string(),
    );
    Config::from_env()
}

fn service_account_json() -> String {
    static SERVICE_ACCOUNT_JSON: OnceLock<String> = OnceLock::new();

    SERVICE_ACCOUNT_JSON
        .get_or_init(|| {
            let mut rng = OsRng;
            let key = RsaPrivateKey::new(&mut rng, 2048).expect("generate rsa key");
            let private_key = key
                .to_pkcs8_pem(LineEnding::LF)
                .expect("encode pem")
                .to_string();

            serde_json::json!({
                "client_email": "upload-signer@test-project.iam.gserviceaccount.com",
                "private_key": private_key,
                "token_uri": "https://oauth2.googleapis.com/token"
            })
            .to_string()
        })
        .clone()
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
    .bind(format!(
        "nick{}",
        &user_id[user_id.len().saturating_sub(4)..]
    ))
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .execute(pool)
    .await
    .expect("insert user");
}

#[sqlx::test(migrations = "./migrations")]
async fn issue_profile_image_upload_url(pool: PgPool) {
    insert_auth_account(&pool, "upload_url_user").await;
    insert_user(&pool, "upload_url_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &promiso_backend::middleware::auth::ServerAuth::new(
            Some("test-server-secret".to_string()),
            "promiso-test".to_string(),
            900,
        ),
        CreateSessionInput {
            user_id: "upload_url_user".to_string(),
            device_id: "device-upload-url".to_string(),
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
                .method("POST")
                .uri("/api/v1/users/me/profile-image/upload-url")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .header("content-type", "application/json")
                .body(Body::from(r#"{"content_type":"image/jpeg"}"#))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).expect("parse body");

    let object_path = json["data"]["object_path"].as_str().expect("object_path");
    let upload_url = json["data"]["upload_url"].as_str().expect("upload_url");
    let profile_url = json["data"]["profile_url"].as_str().expect("profile_url");

    assert!(object_path.starts_with("profile_images/upload_url_user/"));
    assert!(upload_url.contains("X-Goog-Algorithm=GOOG4-RSA-SHA256"));
    assert!(profile_url.starts_with(
        "https://storage.googleapis.com/promiso-test-media/profile_images/upload_url_user/"
    ));
}
