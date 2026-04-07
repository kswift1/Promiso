use std::sync::Arc;

use axum::extract::{Path, Query, State};
use axum::routing::{get, patch, post};
use axum::{Extension, Json, Router};
use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::group::*;
use crate::models::notification::PushSender;
use crate::response::ApiResponse;
use crate::services::group_service;

/// 인증 불필요 라우트 (그룹 미리보기)
pub fn public_router() -> Router<PgPool> {
    Router::new().route("/api/v1/groups/preview", get(preview_group))
}

/// 인증 필요 라우트
pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/groups", post(create_group))
        .route("/api/v1/groups/batch", post(get_groups_batch))
        .route("/api/v1/groups/join", post(join_group))
        .route("/api/v1/groups/me", get(fetch_my_groups))
        .route(
            "/api/v1/groups/{id}",
            get(fetch_group).patch(update_group).delete(delete_group),
        )
        .route("/api/v1/groups/{id}/members", get(fetch_group_members))
        .route("/api/v1/groups/{id}/transfer-host", post(transfer_host))
        .route("/api/v1/groups/{id}/expel", post(expel_member))
        .route("/api/v1/groups/{id}/leave", post(leave_group))
        .route("/api/v1/groups/{id}/mark-read", post(mark_group_read))
        .route(
            "/api/v1/groups/{id}/notification-settings",
            patch(update_notification_settings),
        )
        .route("/api/v1/groups/{id}/color", patch(update_group_color))
}

async fn create_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<CreateGroupRequest>,
) -> Result<ApiResponse<CreateGroupResponse>, AppError> {
    let response = group_service::create_group(&pool, &claims.uid, req).await?;
    ApiResponse::created(response)
}

async fn get_groups_batch(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<BatchGroupsRequest>,
) -> Result<ApiResponse<Vec<GroupResponse>>, AppError> {
    let result = group_service::get_groups_batch(&pool, &claims.uid, req.ids).await?;
    ApiResponse::ok(result)
}

#[derive(Deserialize)]
struct PreviewQuery {
    code: String,
}

async fn preview_group(
    State(pool): State<PgPool>,
    Query(query): Query<PreviewQuery>,
) -> Result<ApiResponse<GroupPreviewResponse>, AppError> {
    let response = group_service::preview_group(&pool, &query.code).await?;
    ApiResponse::ok(response)
}

async fn join_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    Json(req): Json<JoinGroupRequest>,
) -> Result<ApiResponse<GroupResponse>, AppError> {
    let response = group_service::join_group_with_push_sender(
        &pool,
        push_sender.as_ref(),
        &claims.uid,
        &req.invite_code,
    )
    .await?;
    ApiResponse::ok(response)
}

async fn fetch_my_groups(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<Vec<GroupSummaryResponse>>, AppError> {
    let response = group_service::fetch_my_groups(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn fetch_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<GroupResponse>, AppError> {
    let response = group_service::fetch_group(&pool, &claims.uid, group_id).await?;
    ApiResponse::ok(response)
}

async fn update_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<UpdateGroupRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::update_group(&pool, &claims.uid, group_id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::delete_group(&pool, &claims.uid, group_id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn fetch_group_members(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<Vec<GroupMemberResponse>>, AppError> {
    let response = group_service::fetch_group_members(&pool, &claims.uid, group_id).await?;
    ApiResponse::ok(response)
}

async fn transfer_host(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<TransferHostRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::transfer_host(&pool, &claims.uid, group_id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn expel_member(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<ExpelMemberRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::expel_member(&pool, &claims.uid, group_id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn leave_group(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::leave_group(&pool, &claims.uid, group_id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn mark_group_read(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::mark_group_read(&pool, &claims.uid, group_id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn update_notification_settings(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<NotificationSettingsRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::update_notification_settings(&pool, &claims.uid, group_id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn update_group_color(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<UpdateGroupColorRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    group_service::update_group_color(&pool, &claims.uid, group_id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}
