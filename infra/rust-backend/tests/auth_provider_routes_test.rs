use std::sync::Arc;

use async_trait::async_trait;
use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Extension;
use http_body_util::BodyExt;
use promiso_backend::middleware::auth::ServerAuth;
use promiso_backend::routes::auth;
use promiso_backend::services::provider_verifier::{ProviderVerifier, VerifiedProviderProfile};
use sqlx::PgPool;
use tower::ServiceExt;

#[derive(Clone)]
struct FakeProviderVerifier {
    apple_profile: Option<VerifiedProviderProfile>,
    google_profile: Option<VerifiedProviderProfile>,
}

#[async_trait]
impl ProviderVerifier for FakeProviderVerifier {
    async fn verify_apple_sign_in(
        &self,
        _req: &promiso_backend::models::auth::AppleSignInRequest,
    ) -> Result<VerifiedProviderProfile, promiso_backend::errors::AppError> {
        self.apple_profile.clone().ok_or_else(|| {
            promiso_backend::errors::AppError::Unauthorized("apple verification failed".to_string())
        })
    }

    async fn verify_google_sign_in(
        &self,
        _req: &promiso_backend::models::auth::GoogleSignInRequest,
    ) -> Result<VerifiedProviderProfile, promiso_backend::errors::AppError> {
        self.google_profile.clone().ok_or_else(|| {
            promiso_backend::errors::AppError::Unauthorized(
                "google verification failed".to_string(),
            )
        })
    }
}

fn server_auth() -> ServerAuth {
    ServerAuth::new(
        Some("test-server-secret".to_string()),
        "promiso-test".to_string(),
        900,
    )
}

#[sqlx::test(migrations = "./migrations")]
async fn apple_auth_route_creates_session_for_new_user(pool: PgPool) {
    let verifier: Arc<dyn ProviderVerifier> = Arc::new(FakeProviderVerifier {
        apple_profile: Some(VerifiedProviderProfile {
            provider_type: "apple".to_string(),
            provider_uid: "apple-user-123".to_string(),
            email: Some("apple@test.com".to_string()),
            display_name: Some("Apple User".to_string()),
            profile_image_url: None,
        }),
        google_profile: None,
    });

    let app = auth::public_router()
        .layer(Extension(server_auth()))
        .layer(Extension(verifier))
        .with_state(pool);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/auth/apple")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "identityToken": "apple-id-token",
                        "userIdentifier": "apple-user-123",
                        "email": "apple@test.com",
                        "fullName": "Apple User",
                        "rawNonce": "raw-nonce",
                        "deviceId": "device-apple",
                        "appVersion": "1.0.0"
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

    assert_eq!(json["data"]["user"]["provider"], "apple");
    assert_eq!(json["data"]["hasProfile"], false);
    assert!(json["data"]["accessToken"].as_str().is_some());
    assert!(json["data"]["refreshToken"].as_str().is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn google_auth_route_reuses_existing_account(pool: PgPool) {
    sqlx::query(
        "INSERT INTO auth_accounts (user_id, provider_type, provider_uid, email, display_name) \
         VALUES ('existing_user', 'google', 'google-user-123', 'existing@test.com', 'Existing User')",
    )
    .execute(&pool)
    .await
    .expect("insert auth account");

    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ('existing_user', 'Existing User', '기존유저', 'google', 'google-user-123', 'existing@test.com')",
    )
    .execute(&pool)
    .await
    .expect("insert user");

    let verifier: Arc<dyn ProviderVerifier> = Arc::new(FakeProviderVerifier {
        apple_profile: None,
        google_profile: Some(VerifiedProviderProfile {
            provider_type: "google".to_string(),
            provider_uid: "google-user-123".to_string(),
            email: Some("existing@test.com".to_string()),
            display_name: Some("Existing User".to_string()),
            profile_image_url: Some("https://example.com/google-user-123.jpg".to_string()),
        }),
    });

    let app = auth::public_router()
        .layer(Extension(server_auth()))
        .layer(Extension(verifier))
        .with_state(pool);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/auth/google")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "idToken": "google-id-token",
                        "accessToken": "google-access-token",
                        "userIdentifier": "google-user-123",
                        "email": "existing@test.com",
                        "fullName": "Existing User",
                        "profileImageUrl": "https://example.com/google-user-123.jpg",
                        "deviceId": "device-google",
                        "appVersion": "1.0.0"
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

    assert_eq!(json["data"]["user"]["userId"], "existing_user");
    assert_eq!(json["data"]["user"]["provider"], "google");
    assert_eq!(json["data"]["hasProfile"], true);
}
