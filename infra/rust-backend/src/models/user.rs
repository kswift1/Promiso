use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

// DB 모델
#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct User {
    pub id: String,
    pub name: String,
    pub nickname: String,
    pub provider_type: String,
    pub provider_uid: String,
    pub email: String,
    pub profile_url: Option<String>,
    pub notification_enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// API 요청/응답 DTO
#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub name: Option<String>,
    pub nickname: String,
    pub provider: ProviderInfo,
}

#[derive(Debug, Deserialize)]
pub struct ProviderInfo {
    pub provider_type: String,
    pub provider_uid: String,
    pub email: String,
}

#[derive(Debug, Serialize)]
pub struct CreateUserResponse {
    pub user_id: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct UserPublicResponse {
    pub user_id: String,
    pub name: String,
    pub nickname: String,
    pub profile_url: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct UserPrivateResponse {
    pub user_id: String,
    pub name: String,
    pub nickname: String,
    pub email: String,
    pub provider: String,
    pub profile_url: Option<String>,
    pub notification_enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub nickname: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UploadProfileImageRequest {
    pub image_path: String,
}

#[derive(Debug, Serialize)]
pub struct NicknameCheckResponse {
    pub available: bool,
    pub nickname: String,
}

#[derive(Debug, Deserialize)]
pub struct BatchGetUsersRequest {
    pub user_ids: Vec<String>,
}
