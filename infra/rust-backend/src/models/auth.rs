use chrono::{DateTime, Utc};
use serde::Serialize;

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

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionTokensResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}

