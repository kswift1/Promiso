use axum::extract::{Path, State};
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::live_activity::*;
use crate::response::ApiResponse;
use crate::services::live_activity_service;

// ApnsSender는 아직 실제 구현체가 없으므로 stub 사용
// TODO: 실제 APNs HTTP/2 구현체로 교체 (ADR-009)
struct StubApnsSender;

#[async_trait::async_trait]
impl ApnsSender for StubApnsSender {
    async fn send_push_to_start(&self, _tokens: &[String], _payload: &ApnsPayload) -> ApnsResult {
        ApnsResult {
            success_count: 0,
            failure_count: 0,
        }
    }
    async fn create_channel(&self) -> Result<String, AppError> {
        Err(AppError::Internal(
            "APNs not configured".to_string(),
        ))
    }
    async fn send_broadcast(
        &self,
        _channel_id: &str,
        _payload: &ApnsPayload,
    ) -> ApnsResult {
        ApnsResult {
            success_count: 0,
            failure_count: 0,
        }
    }
}

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
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<LiveActivityResponse>, AppError> {
    let apns = StubApnsSender;
    let result = live_activity_service::start_live_activity(&pool, &apns, &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn update_eta(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateETARequest>,
) -> Result<ApiResponse<LiveActivityResponse>, AppError> {
    let apns = StubApnsSender;
    let result =
        live_activity_service::update_eta(&pool, &apns, &claims.uid, id, req).await?;
    ApiResponse::ok(result)
}

// ============================================================
// Vote LiveActivity
// ============================================================

async fn start_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<VoteStartResponse>, AppError> {
    let apns = StubApnsSender;
    let result = live_activity_service::start_vote(&pool, &apns, &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn respond_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
    Json(req): Json<VoteRespondRequest>,
) -> Result<ApiResponse<VoteRespondResponse>, AppError> {
    let apns = StubApnsSender;
    let result =
        live_activity_service::respond_vote(&pool, &apns, &claims.uid, id, req).await?;
    ApiResponse::ok(result)
}

async fn finalize_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<VoteRespondResponse>, AppError> {
    let apns = StubApnsSender;
    let result = live_activity_service::finalize_vote(&pool, &apns, &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn end_vote(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<()>, AppError> {
    let apns = StubApnsSender;
    live_activity_service::end_vote(&pool, &apns, &claims.uid, id).await?;
    ApiResponse::ok(())
}
