use std::sync::Arc;

use axum::extract::{Path, State};
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::live_activity::*;
use crate::response::ApiResponse;
use crate::services::apns_service::RealApnsSender;
use crate::services::live_activity_service;

pub fn router() -> Router<PgPool> {
    let la_routes = Router::new()
        .route(
            "/{id}/live-activity/start",
            post(start_live_activity),
        )
        .route("/{id}/live-activity/eta", post(update_eta))
        .route("/{id}/vote/start", post(start_vote))
        .route("/{id}/vote/respond", post(respond_vote))
        .route("/{id}/vote/finalize", post(finalize_vote))
        .route("/{id}/vote/end", post(end_vote));

    Router::new().nest("/api/v1/schedules", la_routes)
}

// ============================================================
// Schedule LiveActivity
// ============================================================

async fn start_live_activity(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<LiveActivityResponse>, AppError> {
    let result =
        live_activity_service::start_live_activity(&pool, apns.as_ref(), &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn update_eta(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateETARequest>,
) -> Result<ApiResponse<LiveActivityResponse>, AppError> {
    let result =
        live_activity_service::update_eta(&pool, apns.as_ref(), &claims.uid, id, req).await?;
    ApiResponse::ok(result)
}

// ============================================================
// Vote LiveActivity
// ============================================================

async fn start_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<VoteStartResponse>, AppError> {
    let result =
        live_activity_service::start_vote(&pool, apns.as_ref(), &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn respond_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
    Json(req): Json<VoteRespondRequest>,
) -> Result<ApiResponse<VoteRespondResponse>, AppError> {
    let result =
        live_activity_service::respond_vote(&pool, apns.as_ref(), &claims.uid, id, req).await?;
    ApiResponse::ok(result)
}

async fn finalize_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<VoteRespondResponse>, AppError> {
    let result =
        live_activity_service::finalize_vote(&pool, apns.as_ref(), &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn end_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(apns): Extension<Arc<RealApnsSender>>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<()>, AppError> {
    live_activity_service::end_vote(&pool, apns.as_ref(), &claims.uid, id).await?;
    ApiResponse::ok(())
}
