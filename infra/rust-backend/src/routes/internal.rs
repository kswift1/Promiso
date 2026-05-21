use std::sync::Arc;

use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Extension, Json, Router};
use chrono::Utc;
use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::LiveActivitySender;
use crate::models::notification::PushSender;
use crate::services::briefing_scheduler_service::{
    self, dispatch_due_briefings, verify_scheduler_secret,
};
use crate::services::live_activity_service::{self, LiveActivityJobScheduler};

pub fn router() -> Router<PgPool> {
    Router::new()
        .route(
            "/api/v1/internal/briefing/dispatch",
            post(dispatch_briefings_handler),
        )
        .route(
            "/api/v1/internal/live-activity/jobs/{job_id}/dispatch",
            post(dispatch_live_activity_job_handler),
        )
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DispatchResponse {
    summary: briefing_scheduler_service::DispatchSummary,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LiveActivityJobDispatchResponse {
    processed: bool,
}

/// POST /api/v1/internal/briefing/dispatch
///
/// 인증: X-Scheduler-Secret 헤더 vs SCHEDULER_SECRET 환경변수
async fn dispatch_briefings_handler(
    State(pool): State<PgPool>,
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    headers: HeaderMap,
) -> Result<Json<DispatchResponse>, AppError> {
    // 1. X-Scheduler-Secret 헤더 추출
    let provided = headers
        .get("x-scheduler-secret")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");

    // 2. SCHEDULER_SECRET 환경변수 — 미설정 또는 빈 값이면 서버 설정 오류
    let expected = match std::env::var("SCHEDULER_SECRET") {
        Ok(v) if !v.is_empty() => v,
        _ => {
            return Err(AppError::Internal(
                "SCHEDULER_SECRET not configured".to_string(),
            ))
        }
    };

    // 3. 검증
    if !verify_scheduler_secret(provided, &expected) {
        return Err(AppError::Unauthorized("Invalid scheduler secret".into()));
    }

    // 4. dispatch
    let summary = dispatch_due_briefings(&pool, push_sender.as_ref(), Utc::now(), 50).await?;

    // 5. 응답
    Ok(Json(DispatchResponse { summary }))
}

async fn dispatch_live_activity_job_handler(
    State(pool): State<PgPool>,
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    Extension(live_activity_sender): Extension<Arc<dyn LiveActivitySender>>,
    Extension(live_activity_job_scheduler): Extension<Arc<dyn LiveActivityJobScheduler>>,
    headers: HeaderMap,
    Path(job_id): Path<Uuid>,
) -> Result<Json<LiveActivityJobDispatchResponse>, AppError> {
    let provided = headers
        .get("x-scheduler-secret")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");

    let expected = match std::env::var("SCHEDULER_SECRET") {
        Ok(v) if !v.is_empty() => v,
        _ => {
            return Err(AppError::Internal(
                "SCHEDULER_SECRET not configured".to_string(),
            ))
        }
    };

    if !verify_scheduler_secret(provided, &expected) {
        return Err(AppError::Unauthorized("Invalid scheduler secret".into()));
    }

    let result = live_activity_service::dispatch_live_activity_job_with_scheduler(
        &pool,
        live_activity_sender.as_ref(),
        push_sender.as_ref(),
        live_activity_job_scheduler.as_ref(),
        job_id,
    )
    .await?;

    Ok(Json(LiveActivityJobDispatchResponse {
        processed: result.processed,
    }))
}
