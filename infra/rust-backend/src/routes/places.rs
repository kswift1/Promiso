use axum::extract::{Query, State};
use axum::routing::get;
use axum::Router;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::response::ApiResponse;
use crate::services::places_service::{self, PlaceResult};

#[derive(Debug, serde::Deserialize)]
struct PlacesSearchQuery {
    q: String,
    size: Option<i32>,
}

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/places/search", get(search_places))
}

// GET /api/v1/places/search?q=&size= — public (인증 불필요)
async fn search_places(
    State(_pool): State<PgPool>,
    Query(query): Query<PlacesSearchQuery>,
) -> Result<ApiResponse<Vec<PlaceResult>>, AppError> {
    // api_key는 Green Phase에서 config extension으로 주입
    let api_key = std::env::var("KAKAO_REST_API_KEY").unwrap_or_default();
    let size = query.size.unwrap_or(15).min(45);
    let result = places_service::search_places(&query.q, size, &api_key).await?;
    ApiResponse::ok(result)
}
