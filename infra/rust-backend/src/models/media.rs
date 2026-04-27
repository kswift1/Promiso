use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IssueMediaUploadUrlsRequest {
    pub base_path: String,
    pub count: usize,
    pub content_type: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IssueMediaDeleteUrlsRequest {
    pub targets: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaUploadTargetResponse {
    pub object_path: String,
    pub upload_url: String,
    pub public_url: String,
    pub expires_at: DateTime<Utc>,
    pub content_type: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaDeleteTargetResponse {
    pub object_path: String,
    pub delete_url: String,
    pub expires_at: DateTime<Utc>,
}
