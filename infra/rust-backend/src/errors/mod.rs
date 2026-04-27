use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Forbidden: {0}")]
    Forbidden(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Precondition failed: {0}")]
    PreconditionFailed(String),

    #[error("Internal error: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match &self {
            AppError::Unauthorized(msg) => {
                (StatusCode::UNAUTHORIZED, "unauthenticated", msg.as_str())
            }
            AppError::Forbidden(msg) => (StatusCode::FORBIDDEN, "permission-denied", msg.as_str()),
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, "not-found", msg.as_str()),
            AppError::BadRequest(msg) => {
                (StatusCode::BAD_REQUEST, "invalid-argument", msg.as_str())
            }
            AppError::Conflict(msg) => (StatusCode::CONFLICT, "already-exists", msg.as_str()),
            AppError::PreconditionFailed(msg) => (
                StatusCode::PRECONDITION_FAILED,
                "failed-precondition",
                msg.as_str(),
            ),
            AppError::Internal(msg) => {
                tracing::error!("Internal error: {}", msg);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal",
                    "Internal server error",
                )
            }
        };

        let body = json!({
            "error": {
                "code": code,
                "message": message,
            }
        });

        (status, Json(body)).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Internal(err.to_string())
    }
}
