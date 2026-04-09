use axum::extract::State;
use axum::routing::post;
use axum::{Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::weather::{GetWeatherRequest, WeatherResponse};
use crate::response::ApiResponse;
use crate::services::weather_service;

pub fn router() -> Router<PgPool> {
    Router::new().route("/api/v1/weather", post(get_weather))
}

async fn get_weather(
    State(_pool): State<PgPool>,
    Json(req): Json<GetWeatherRequest>,
) -> Result<ApiResponse<WeatherResponse>, AppError> {
    let response = weather_service::get_weather(req).await?;
    ApiResponse::ok(response)
}
