use std::sync::Arc;

use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::*;
use crate::response::ApiResponse;
use crate::services::apns_service::RealApnsSender;
use crate::services::live_activity_service;

pub fn router() -> Router<PgPool> {
    Router::new()
        .route(
            "/api/v1/widget/schedules/{id}/eta",
            post(widget_update_eta),
        )
        .route(
            "/api/v1/widget/schedules/{id}/vote",
            post(widget_vote_response),
        )
}

/// Widget에서 ETA 업데이트.
///
/// - `X-User-Id` 헤더 필수 (없으면 401)
/// - `X-Auth-Token` 있으면 검증하되 만료는 허용 (Widget 특성상)
async fn widget_update_eta(
    State(pool): State<PgPool>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateETARequest>,
) -> Result<ApiResponse<LiveActivityResponse>, AppError> {
    let user_id = extract_user_id(&headers)?;

    // X-Auth-Token 있으면 검증 (만료 허용)
    // TODO: 토큰 검증 강화 (uid 불일치 체크)

    let result = live_activity_service::update_eta(&pool, apns.as_ref(), &user_id, id, req).await?;
    ApiResponse::ok(result)
}

/// Widget에서 투표 응답.
///
/// - `X-User-Id` 헤더 필수 (없으면 401)
/// - `X-Auth-Token` 헤더 필수 (ETA보다 엄격, 없으면 401)
/// - Widget Token 우선 검증, 만료 시 Firebase fallback
async fn widget_vote_response(
    State(pool): State<PgPool>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(req): Json<VoteRespondRequest>,
) -> Result<ApiResponse<VoteRespondResponse>, AppError> {
    let user_id = extract_user_id(&headers)?;

    // X-Auth-Token 필수 (투표는 ETA보다 엄격)
    let _auth_token = headers
        .get("x-auth-token")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| AppError::Unauthorized("X-Auth-Token header required".into()))?;

    // TODO: Widget Token 검증 -> 만료 시 Firebase ID Token fallback
    // 현재는 user_id 기반으로 처리

    let result =
        live_activity_service::respond_vote(&pool, apns.as_ref(), &user_id, id, req).await?;
    ApiResponse::ok(result)
}

/// `X-User-Id` 헤더에서 사용자 ID를 추출한다.
fn extract_user_id(headers: &HeaderMap) -> Result<String, AppError> {
    headers
        .get("x-user-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
        .ok_or_else(|| AppError::Unauthorized("X-User-Id header required".into()))
}
