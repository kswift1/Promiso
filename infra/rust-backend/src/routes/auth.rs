use axum::extract::State;
use axum::http::header::USER_AGENT;
use axum::http::HeaderMap;
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use serde_json::json;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::{Claims, ServerAuth};
use crate::models::auth::{
    AppleSignInRequest, AuthLoginResponse, AuthSubjectResponse, GoogleSignInRequest,
    RefreshSessionInput, RefreshSessionRequest, SessionTokensResponse,
};
use crate::response::ApiResponse;
use crate::services::auth_service;
use crate::services::provider_verifier::SharedProviderVerifier;

pub fn public_router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/auth/apple", post(apple_sign_in))
        .route("/api/v1/auth/google", post(google_sign_in))
        .route("/api/v1/auth/refresh", post(refresh_session))
}

pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/auth/me", get(get_me))
        .route("/api/v1/auth/logout", post(logout))
        .route("/api/v1/auth/logout-all", post(logout_all))
}

async fn refresh_session(
    Extension(server_auth): Extension<ServerAuth>,
    State(pool): State<PgPool>,
    Json(req): Json<RefreshSessionRequest>,
) -> Result<ApiResponse<SessionTokensResponse>, AppError> {
    let response = auth_service::refresh_session(
        &pool,
        &server_auth,
        RefreshSessionInput {
            refresh_token: req.refresh_token,
            device_id: req.device_id,
        },
    )
    .await?;

    ApiResponse::ok(response)
}

async fn apple_sign_in(
    Extension(server_auth): Extension<ServerAuth>,
    Extension(provider_verifier): Extension<SharedProviderVerifier>,
    State(pool): State<PgPool>,
    headers: HeaderMap,
    Json(req): Json<AppleSignInRequest>,
) -> Result<ApiResponse<AuthLoginResponse>, AppError> {
    let verified = provider_verifier.verify_apple_sign_in(&req).await?;
    let user_agent = headers
        .get(USER_AGENT)
        .and_then(|value| value.to_str().ok())
        .map(ToOwned::to_owned);

    let response = auth_service::sign_in_with_verified_provider(
        &pool,
        &server_auth,
        verified,
        req.device_id,
        req.app_version,
        user_agent,
    )
    .await?;

    ApiResponse::ok(response)
}

async fn google_sign_in(
    Extension(server_auth): Extension<ServerAuth>,
    Extension(provider_verifier): Extension<SharedProviderVerifier>,
    State(pool): State<PgPool>,
    headers: HeaderMap,
    Json(req): Json<GoogleSignInRequest>,
) -> Result<ApiResponse<AuthLoginResponse>, AppError> {
    let verified = provider_verifier.verify_google_sign_in(&req).await?;
    let user_agent = headers
        .get(USER_AGENT)
        .and_then(|value| value.to_str().ok())
        .map(ToOwned::to_owned);

    let response = auth_service::sign_in_with_verified_provider(
        &pool,
        &server_auth,
        verified,
        req.device_id,
        req.app_version,
        user_agent,
    )
    .await?;

    ApiResponse::ok(response)
}

async fn get_me(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<AuthSubjectResponse>, AppError> {
    let response = auth_service::get_auth_subject(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn logout(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    let session_id = claims.session_id.ok_or_else(|| {
        AppError::PreconditionFailed("Current token is not a server session".to_string())
    })?;

    auth_service::revoke_session_by_id(&pool, session_id).await?;
    ApiResponse::ok(json!({"success": true}))
}

async fn logout_all(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    auth_service::revoke_all_sessions(&pool, &claims.uid).await?;
    ApiResponse::ok(json!({"success": true}))
}
