use axum::extract::{Path, Query, State};
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use serde::Deserialize;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::user::*;
use crate::response::ApiResponse;
use crate::services::user_service;

pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/users", post(create_user))
        .route("/api/v1/users/me", get(get_my_profile).patch(update_user))
        .route("/api/v1/users/me/profile-image", post(upload_profile_image))
        .route(
            "/api/v1/users/nickname-check",
            get(check_nickname_available),
        )
        .route("/api/v1/users/batch", post(batch_get_users))
        .route("/api/v1/users/{id}", get(get_user_public))
}

async fn create_user(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<CreateUserRequest>,
) -> Result<ApiResponse<CreateUserResponse>, AppError> {
    let response = user_service::create_user(&pool, &claims.uid, req).await?;
    ApiResponse::created(response)
}

async fn get_my_profile(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<UserPrivateResponse>, AppError> {
    let response = user_service::get_my_profile(&pool, &claims.uid).await?;
    ApiResponse::ok(response)
}

async fn get_user_public(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(target_id): Path<String>,
) -> Result<ApiResponse<UserPublicResponse>, AppError> {
    let response = user_service::get_user_public(&pool, &claims.uid, &target_id).await?;
    ApiResponse::ok(response)
}

async fn update_user(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateUserRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    user_service::update_user(&pool, &claims.uid, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn upload_profile_image(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<UploadProfileImageRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    let url = user_service::upload_profile_image(&pool, &claims.uid, req).await?;
    ApiResponse::ok(serde_json::json!({"profile_url": url}))
}

#[derive(Deserialize)]
struct NicknameQuery {
    q: String,
}

async fn check_nickname_available(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Query(query): Query<NicknameQuery>,
) -> Result<ApiResponse<NicknameCheckResponse>, AppError> {
    let response = user_service::check_nickname_available(&pool, &claims.uid, &query.q).await?;
    ApiResponse::ok(response)
}

async fn batch_get_users(
    Extension(_claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<BatchGetUsersRequest>,
) -> Result<ApiResponse<Vec<UserPublicResponse>>, AppError> {
    let response = user_service::batch_get_users(&pool, &req.user_ids).await?;
    ApiResponse::ok(response)
}
