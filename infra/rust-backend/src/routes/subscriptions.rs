use axum::extract::State;
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::subscription::{
    AppleNotificationRequest, EntitlementResponse, SubscriptionStatusResponse, SuccessResponse,
    VerifyPurchaseRequest, VerifyPurchaseResponse,
};
use crate::response::ApiResponse;
use crate::services::app_store_service::SharedAppStoreVerifier;
use crate::services::subscription_service;

pub fn router() -> Router<PgPool> {
    Router::new()
        .route(
            "/api/v1/subscriptions/verify-purchase",
            post(verify_purchase),
        )
        .route("/api/v1/subscriptions/status", get(get_status))
        .route("/api/v1/subscriptions/entitlement", get(get_entitlement))
}

pub fn public_router() -> Router<PgPool> {
    Router::new().route(
        "/api/v1/subscriptions/apple-notifications",
        post(apple_notification),
    )
}

async fn verify_purchase(
    Extension(claims): Extension<Claims>,
    Extension(verifier): Extension<SharedAppStoreVerifier>,
    State(pool): State<PgPool>,
    Json(req): Json<VerifyPurchaseRequest>,
) -> Result<ApiResponse<VerifyPurchaseResponse>, AppError> {
    let response =
        subscription_service::verify_purchase(&pool, &claims.uid, req, verifier.as_ref()).await?;
    ApiResponse::ok(response)
}

async fn get_status(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<SubscriptionStatusResponse>, AppError> {
    let response = subscription_service::get_status(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn get_entitlement(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<EntitlementResponse>, AppError> {
    let response = subscription_service::get_entitlement(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn apple_notification(
    Extension(verifier): Extension<SharedAppStoreVerifier>,
    State(pool): State<PgPool>,
    Json(req): Json<AppleNotificationRequest>,
) -> Result<ApiResponse<SuccessResponse>, AppError> {
    subscription_service::handle_apple_notification(&pool, req, verifier.as_ref()).await?;
    ApiResponse::ok(SuccessResponse { success: true })
}
