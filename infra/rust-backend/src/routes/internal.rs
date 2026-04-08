use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::post;
use axum::{Json, Router};
use chrono::Utc;
use serde::Serialize;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::services::briefing_scheduler_service::{
    self, dispatch_due_briefings, verify_scheduler_secret,
};

pub fn router() -> Router<PgPool> {
    Router::new().route(
        "/api/v1/internal/briefing/dispatch",
        post(dispatch_briefings_handler),
    )
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DispatchResponse {
    summary: briefing_scheduler_service::DispatchSummary,
}

/// POST /api/v1/internal/briefing/dispatch
///
/// 인증: X-Scheduler-Secret 헤더 vs SCHEDULER_SECRET 환경변수
async fn dispatch_briefings_handler(
    State(pool): State<PgPool>,
    headers: HeaderMap,
) -> Result<Json<DispatchResponse>, AppError> {
    // 1. X-Scheduler-Secret 헤더 추출
    let provided = headers
        .get("x-scheduler-secret")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");

    // 2. SCHEDULER_SECRET 환경변수
    let expected = std::env::var("SCHEDULER_SECRET").unwrap_or_default();

    // 3. 검증
    if !verify_scheduler_secret(provided, &expected) {
        return Err(AppError::Unauthorized("Invalid scheduler secret".into()));
    }

    // 4. dispatch
    let summary = dispatch_due_briefings(&pool, Utc::now(), 50).await?;

    // 5. 응답
    Ok(Json(DispatchResponse { summary }))
}
