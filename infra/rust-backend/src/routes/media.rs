use axum::routing::post;
use axum::{Extension, Json, Router};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::media::{
    IssueMediaDeleteUrlsRequest, IssueMediaUploadUrlsRequest, MediaDeleteTargetResponse,
    MediaUploadTargetResponse,
};
use crate::response::ApiResponse;
use crate::services::media_service;
use crate::services::storage_service::GcsUploadSigner;

pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/media/upload-urls", post(issue_upload_urls))
        .route("/api/v1/media/delete-urls", post(issue_delete_urls))
}

async fn issue_upload_urls(
    Extension(claims): Extension<Claims>,
    Extension(upload_signer): Extension<Option<GcsUploadSigner>>,
    axum::extract::State(pool): axum::extract::State<PgPool>,
    Json(req): Json<IssueMediaUploadUrlsRequest>,
) -> Result<ApiResponse<Vec<MediaUploadTargetResponse>>, AppError> {
    let signer = upload_signer.ok_or_else(|| {
        AppError::PreconditionFailed("GCS upload signing is not configured".to_string())
    })?;
    let response = media_service::issue_upload_urls(&pool, &claims.uid, req, &signer).await?;
    ApiResponse::ok(response)
}

async fn issue_delete_urls(
    Extension(claims): Extension<Claims>,
    Extension(upload_signer): Extension<Option<GcsUploadSigner>>,
    axum::extract::State(pool): axum::extract::State<PgPool>,
    Json(req): Json<IssueMediaDeleteUrlsRequest>,
) -> Result<ApiResponse<Vec<MediaDeleteTargetResponse>>, AppError> {
    let signer = upload_signer.ok_or_else(|| {
        AppError::PreconditionFailed("GCS upload signing is not configured".to_string())
    })?;
    let response = media_service::issue_delete_urls(&pool, &claims.uid, req, &signer).await?;
    ApiResponse::ok(response)
}
