use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;

/// 표준 성공 응답 wrapper
///
/// 사용법:
/// ```
/// async fn get_user() -> ApiResponse<User> {
///     let user = find_user().await?;
///     ApiResponse::ok(user)
/// }
/// ```
pub struct ApiResponse<T: Serialize>(StatusCode, T);

impl<T: Serialize> ApiResponse<T> {
    /// 200 OK 응답
    pub fn ok(data: T) -> Result<Self, crate::errors::AppError> {
        Ok(Self(StatusCode::OK, data))
    }

    /// 201 Created 응답
    pub fn created(data: T) -> Result<Self, crate::errors::AppError> {
        Ok(Self(StatusCode::CREATED, data))
    }
}

impl<T: Serialize> IntoResponse for ApiResponse<T> {
    fn into_response(self) -> Response {
        let body = serde_json::json!({
            "data": self.1
        });
        (self.0, Json(body)).into_response()
    }
}
