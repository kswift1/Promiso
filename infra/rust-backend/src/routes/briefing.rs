use axum::extract::State;
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::response::ApiResponse;
use crate::services::briefing_service::{self, GenerateBriefingRequest, GenerateBriefingResponse};

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/briefing/generate", post(generate_briefing_handler))
}

// POST /api/v1/briefing/generate
async fn generate_briefing_handler(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<GenerateBriefingRequest>,
) -> Result<ApiResponse<GenerateBriefingResponse>, AppError> {
    let result = briefing_service::generate_briefing(&pool, &claims.uid, req).await?;
    ApiResponse::ok(result)
}
