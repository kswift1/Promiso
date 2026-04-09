use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::{
    verify_widget_or_firebase_token, Claims, FirebaseAuth, ServerAuth, WidgetAuth,
};
use crate::response::ApiResponse;
use crate::services::widget_service::{self, WidgetSnapshotResponse, WidgetTokenResponse};

#[derive(Debug, serde::Deserialize)]
struct GenerateTokenRequest {
    device_id: String,
}

pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/widget/token", post(generate_token))
        .route("/api/v1/widget/revoke", post(revoke_token))
}

pub fn widget_snapshot_router() -> Router<PgPool> {
    Router::new().route("/api/v1/widget/snapshot", get(get_snapshot))
}

// POST /api/v1/widget/token — 인증 필수 (Firebase)
async fn generate_token(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(widget_auth): Extension<WidgetAuth>,
    Json(req): Json<GenerateTokenRequest>,
) -> Result<ApiResponse<WidgetTokenResponse>, AppError> {
    let secret = widget_auth
        .secret()
        .ok_or_else(|| AppError::Internal("Widget JWT secret not configured".to_string()))?;
    let result =
        widget_service::generate_widget_token(&pool, &claims.uid, &req.device_id, secret).await?;
    ApiResponse::ok(result)
}

// POST /api/v1/widget/revoke — 인증 필수 (Firebase)
async fn revoke_token(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    widget_service::revoke_widget_tokens(&pool, &claims.uid).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

// GET /api/v1/widget/snapshot — Widget/Firebase 토큰
async fn get_snapshot(
    State(pool): State<PgPool>,
    Extension(firebase_auth): Extension<FirebaseAuth>,
    Extension(server_auth): Extension<ServerAuth>,
    Extension(widget_auth): Extension<WidgetAuth>,
    headers: HeaderMap,
) -> Result<ApiResponse<WidgetSnapshotResponse>, AppError> {
    let token = headers
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or_else(|| {
            AppError::Unauthorized("Missing or invalid Authorization header".to_string())
        })?;

    let device_id = headers
        .get("x-device-id")
        .and_then(|v| v.to_str().ok())
        .filter(|value| !value.trim().is_empty());

    let claims = verify_widget_or_firebase_token(
        &firebase_auth,
        &server_auth,
        &widget_auth,
        &pool,
        token,
        device_id,
    )
    .await?;
    let result = widget_service::get_widget_snapshot(&pool, &claims.uid).await?;
    ApiResponse::ok(result)
}
