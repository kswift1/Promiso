use axum::extract::State;
use axum::routing::get;
use axum::Router;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::app_config::AppConfigResponse;
use crate::response::ApiResponse;
use crate::services::app_config_service;

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/app-config", get(get_app_config))
}

async fn get_app_config(
    State(pool): State<PgPool>,
) -> Result<ApiResponse<AppConfigResponse>, AppError> {
    let response = app_config_service::get_app_config(&pool).await?;
    ApiResponse::ok(response)
}
