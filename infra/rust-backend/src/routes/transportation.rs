use axum::extract::State;
use axum::routing::post;
use axum::{Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::transportation::GetTransportationRequest;
use crate::response::ApiResponse;
use crate::services::transportation_service;

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/transportation", post(get_transportation))
}

async fn get_transportation(
    State(_pool): State<PgPool>,
    Json(req): Json<GetTransportationRequest>,
) -> Result<ApiResponse<crate::services::transportation_client::TransportationResult>, AppError> {
    let response = transportation_service::get_transportation(req).await?;
    ApiResponse::ok(response)
}
