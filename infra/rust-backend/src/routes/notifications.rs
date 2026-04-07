use axum::extract::{Path, Query, State};
use axum::routing::{delete, get, patch, post, put};
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::notification::*;
use crate::response::ApiResponse;
use crate::services::notification_service;

pub fn router() -> Router<PgPool> {
    let device_routes = Router::new()
        .route("/", put(upsert_device))
        .route("/{device_id}", delete(delete_device))
        .route("/", delete(delete_all_devices));

    let notification_routes = Router::new()
        .route("/", get(get_notifications))
        .route("/unread-count", get(get_unread_count))
        .route("/{id}/read", patch(mark_as_read))
        .route("/mark-all-read", post(mark_all_as_read))
        .route("/delete-batch", post(delete_batch))
        .route("/", delete(delete_all_notifications));

    Router::new()
        .nest("/api/v1/devices", device_routes)
        .nest("/api/v1/notifications", notification_routes)
}

async fn upsert_device(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<UpsertDeviceRequest>,
) -> Result<ApiResponse<DeviceResponse>, AppError> {
    let response = notification_service::upsert_device(&pool, &claims.uid, req).await?;
    ApiResponse::ok(response)
}

async fn delete_device(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(device_id): Path<String>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::delete_device(&pool, &claims.uid, &device_id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_all_devices(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::delete_all_devices(&pool, &claims.uid).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn get_notifications(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Query(query): Query<GetNotificationsQuery>,
) -> Result<ApiResponse<Vec<NotificationResponse>>, AppError> {
    let response = notification_service::get_notifications(&pool, &claims.uid, query).await?;
    ApiResponse::ok(response)
}

async fn get_unread_count(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<UnreadCountResponse>, AppError> {
    let response = notification_service::get_unread_count(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn mark_as_read(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::mark_as_read(&pool, &claims.uid, id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn mark_all_as_read(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::mark_all_as_read(&pool, &claims.uid).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_batch(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<DeleteNotificationsRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::delete_notifications(&pool, &claims.uid, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_all_notifications(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    notification_service::delete_all_notifications(&pool, &claims.uid).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}
