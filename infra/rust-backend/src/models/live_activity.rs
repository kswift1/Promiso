use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::errors::AppError;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "live_activity_job_type", rename_all = "lowercase")]
#[serde(rename_all = "snake_case")]
pub enum LiveActivityJobType {
    Start,
    End,
    Nudge,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "live_activity_job_status", rename_all = "lowercase")]
#[serde(rename_all = "snake_case")]
pub enum LiveActivityJobStatus {
    Pending,
    Succeeded,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct LiveActivityJob {
    pub id: Uuid,
    pub schedule_id: Uuid,
    pub job_type: LiveActivityJobType,
    pub scheduled_at: DateTime<Utc>,
    pub status: LiveActivityJobStatus,
    pub locked_until: Option<DateTime<Utc>>,
    pub attempts: i32,
    pub payload: Option<serde_json::Value>,
    pub last_error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LiveActivityParticipant {
    pub id: String,
    pub name: String,
    pub estimated_arrival_minutes: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VoteLiveActivityMember {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VoteLiveActivityContentState {
    pub accepted_members: Vec<VoteLiveActivityMember>,
    pub declined_members: Vec<VoteLiveActivityMember>,
    pub pending_count: i32,
    pub is_finalized: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateScheduleLiveActivityRequest {
    pub channel_id: String,
    pub participants: Vec<LiveActivityParticipant>,
    pub tracking_duration_minutes: Option<i16>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetUpdateScheduleLiveActivityRequest {
    pub schedule_id: Uuid,
    pub channel_id: String,
    pub participants: Vec<LiveActivityParticipant>,
    pub tracking_duration_minutes: Option<i16>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetVoteLiveActivityRequest {
    pub schedule_id: Uuid,
    pub channel_id: Option<String>,
    pub response: String,
    pub user_name: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartScheduleLiveActivityResponse {
    pub success: bool,
    pub success_count: i32,
    pub failure_count: i32,
    pub channel_id: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateScheduleLiveActivityResponse {
    pub success: bool,
    pub success_count: i32,
    pub failure_count: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateVoteLiveActivityResponse {
    pub success: bool,
    pub content_state: VoteLiveActivityContentState,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LiveActivityJobPayload {
    pub channel_id: Option<String>,
}

#[async_trait::async_trait]
pub trait LiveActivitySender: Send + Sync {
    async fn create_channel(&self) -> Result<String, AppError>;
    async fn send_push_to_start(
        &self,
        push_to_start_token: &str,
        payload: &serde_json::Value,
    ) -> Result<(), AppError>;
    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &serde_json::Value,
    ) -> Result<(), AppError>;
}
