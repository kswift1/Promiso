use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct CreateSessionInput {
    pub user_id: String,
    pub device_id: String,
    pub platform: String,
    pub app_version: Option<String>,
    pub user_agent: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RefreshSessionInput {
    pub refresh_token: String,
    pub device_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RefreshSessionRequest {
    pub refresh_token: String,
    pub device_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionTokensResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthSubjectResponse {
    pub user_id: String,
    pub email: Option<String>,
    pub provider: String,
    pub display_name: Option<String>,
    pub profile_image_url: Option<String>,
    pub has_profile: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppleSignInRequest {
    pub identity_token: String,
    pub user_identifier: String,
    pub email: Option<String>,
    pub full_name: Option<String>,
    pub raw_nonce: String,
    pub authorization_code: Option<String>,
    pub device_id: String,
    pub app_version: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GoogleSignInRequest {
    pub id_token: String,
    pub access_token: Option<String>,
    pub user_identifier: String,
    pub email: Option<String>,
    pub full_name: Option<String>,
    pub profile_image_url: Option<String>,
    pub device_id: String,
    pub app_version: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthUserResponse {
    pub user_id: String,
    pub email: Option<String>,
    pub provider: String,
    pub display_name: Option<String>,
    pub profile_image_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthLoginResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
    pub user: AuthUserResponse,
    pub has_profile: bool,
}
