use axum::extract::State;
use axum::routing::get;
use axum::Router;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::faq::FAQItemResponse;
use crate::response::ApiResponse;
use crate::services::faq_service;

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/faq", get(get_faqs))
}

async fn get_faqs(
    State(pool): State<PgPool>,
) -> Result<ApiResponse<Vec<FAQItemResponse>>, AppError> {
    let faqs = faq_service::fetch_faqs(&pool).await?;
    ApiResponse::ok(faqs)
}
