use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::middleware::auth::ServerAuth;
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
use uuid::Uuid;

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

async fn create_session(pool: &PgPool, user_id: &str) -> String {
    let tokens = auth_service::create_session(
        pool,
        &server_auth(),
        CreateSessionInput {
            user_id: user_id.to_string(),
            device_id: "device-media-upload".to_string(),
            platform: "ios".to_string(),
            app_version: Some("1.0.0".to_string()),
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    tokens.access_token
}

async fn create_group(pool: &PgPool, user_id: &str) -> Uuid {
    let group_id: (Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, last_activity_at) \
         VALUES ('미디어그룹', 'MED123', 10, NOW()) \
         RETURNING id",
    )
    .fetch_one(pool)
    .await
    .expect("insert group");

    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')")
        .bind(group_id.0)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("insert group host");

    group_id.0
}

#[sqlx::test(migrations = "./migrations")]
async fn issue_schedule_media_upload_urls_for_group_member(pool: PgPool) {
    insert_auth_account(&pool, "media_user").await;
    insert_user(&pool, "media_user").await;
    let group_id = create_group(&pool, "media_user").await;
    let access_token = create_session(&pool, "media_user").await;

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/media/upload-urls")
                .header("authorization", format!("Bearer {}", access_token))
                .header("content-type", "application/json")
                .body(Body::from(format!(
                    r#"{{"base_path":"schedule_images/{group_id}/schedule-123","count":2,"content_type":"image/jpeg"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).expect("parse body");
    let uploads = json["data"].as_array().expect("uploads");

    assert_eq!(uploads.len(), 2);
    assert!(uploads[0]["object_path"]
        .as_str()
        .expect("object_path")
        .starts_with(&format!("schedule_images/{group_id}/schedule-123/")));
    assert!(uploads[0]["upload_url"]
        .as_str()
        .expect("upload_url")
        .contains("X-Goog-Algorithm=GOOG4-RSA-SHA256"));
}

#[sqlx::test(migrations = "./migrations")]
async fn issue_schedule_media_upload_urls_for_non_member_is_forbidden(pool: PgPool) {
    insert_auth_account(&pool, "media_owner").await;
    insert_user(&pool, "media_owner").await;
    let group_id = create_group(&pool, "media_owner").await;

    insert_auth_account(&pool, "media_stranger").await;
    insert_user(&pool, "media_stranger").await;
    let access_token = create_session(&pool, "media_stranger").await;

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/media/upload-urls")
                .header("authorization", format!("Bearer {}", access_token))
                .header("content-type", "application/json")
                .body(Body::from(format!(
                    r#"{{"base_path":"schedule_images/{group_id}/schedule-123","count":1,"content_type":"image/jpeg"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[sqlx::test(migrations = "./migrations")]
async fn issue_schedule_media_delete_urls_for_group_member(pool: PgPool) {
    insert_auth_account(&pool, "media_delete_user").await;
    insert_user(&pool, "media_delete_user").await;
    let group_id = create_group(&pool, "media_delete_user").await;
    let access_token = create_session(&pool, "media_delete_user").await;
    let object_path = format!("schedule_images/{group_id}/schedule-123/image.jpg");
    let encoded_object_path = object_path.replace('/', "%2F");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/media/delete-urls")
                .header("authorization", format!("Bearer {}", access_token))
                .header("content-type", "application/json")
                .body(Body::from(format!(
                    r#"{{"targets":["https://firebasestorage.googleapis.com/v0/b/promiso-test-media/o/{encoded_object_path}?alt=media&token=test"]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).expect("parse body");
    let deletions = json["data"].as_array().expect("deletions");

    assert_eq!(deletions.len(), 1);
    assert_eq!(
        deletions[0]["object_path"].as_str().expect("object_path"),
        object_path
    );
    assert!(deletions[0]["delete_url"]
        .as_str()
        .expect("delete_url")
        .contains("X-Goog-Algorithm=GOOG4-RSA-SHA256"));
}

#[sqlx::test(migrations = "./migrations")]
async fn issue_schedule_media_delete_urls_for_non_member_is_forbidden(pool: PgPool) {
    insert_auth_account(&pool, "media_delete_owner").await;
    insert_user(&pool, "media_delete_owner").await;
    let group_id = create_group(&pool, "media_delete_owner").await;

    insert_auth_account(&pool, "media_delete_stranger").await;
    insert_user(&pool, "media_delete_stranger").await;
    let access_token = create_session(&pool, "media_delete_stranger").await;

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/media/delete-urls")
                .header("authorization", format!("Bearer {}", access_token))
                .header("content-type", "application/json")
                .body(Body::from(format!(
                    r#"{{"targets":["schedule_images/{group_id}/schedule-123/image.jpg"]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}
