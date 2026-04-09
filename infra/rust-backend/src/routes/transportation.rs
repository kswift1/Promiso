use axum::extract::State;
use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::transportation::GetTransportationRequest;
use crate::response::ApiResponse;
use crate::services::transportation_service;

#[derive(Clone)]
pub struct TransportationKeys {
    pub odsay_api_key: Option<String>,
    pub kakao_rest_api_key: Option<String>,
}

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/transportation", post(get_transportation))
}

async fn get_transportation(
    State(_pool): State<PgPool>,
    Extension(keys): Extension<TransportationKeys>,
    Json(req): Json<GetTransportationRequest>,
) -> Result<ApiResponse<crate::services::transportation_client::TransportationResult>, AppError> {
    let response = transportation_service::get_transportation(
        req,
        keys.odsay_api_key.as_deref(),
        keys.kakao_rest_api_key.as_deref(),
    )
    .await?;
    ApiResponse::ok(response)
}
