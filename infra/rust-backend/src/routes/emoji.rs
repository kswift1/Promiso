use axum::extract::State;
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::response::ApiResponse;
use crate::services::emoji_service;

#[derive(Debug, serde::Deserialize)]
struct GenerateEmojiRequest {
    title: String,
}

#[derive(Debug, serde::Serialize)]
struct GenerateEmojiResponse {
    emoji: String,
}

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/emoji/generate", post(generate_emoji))
}

// POST /api/v1/emoji/generate — 인증 필수
async fn generate_emoji(
    State(_pool): State<PgPool>,
    Extension(_claims): Extension<Claims>,
    Json(req): Json<GenerateEmojiRequest>,
) -> Result<ApiResponse<GenerateEmojiResponse>, AppError> {
    // api_key는 Green Phase에서 config extension으로 주입
    let api_key = std::env::var("GEMINI_API_KEY").unwrap_or_default();
    let emoji = emoji_service::generate_emoji(&req.title, &api_key).await?;
    ApiResponse::ok(GenerateEmojiResponse { emoji })
}
