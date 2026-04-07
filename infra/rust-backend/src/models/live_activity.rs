use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ============================================================
// APNs 페이로드
// ============================================================

#[derive(Debug, Clone, Serialize)]
pub struct ApnsPayload {
    pub event: String, // "start", "update", "end"
    pub content_state: serde_json::Value,
    pub channel_id: Option<String>,
    pub dismissal_date: Option<i64>,
    pub alert: Option<ApnsAlert>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ApnsAlert {
    pub title: String,
    pub body: String,
}

// ============================================================
// APNs 결과
// ============================================================

#[derive(Debug, Clone)]
pub struct ApnsResult {
    pub success_count: i32,
    pub failure_count: i32,
}

// ============================================================
// APNs trait
// ============================================================

#[async_trait::async_trait]
pub trait ApnsSender: Send + Sync {
    async fn send_push_to_start(
        &self,
        tokens: &[String],
        payload: &ApnsPayload,
    ) -> ApnsResult;
    async fn create_channel(&self) -> Result<String, crate::errors::AppError>;
    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &ApnsPayload,
    ) -> ApnsResult;
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
pub struct UpdateETARequest {
    pub channel_id: String,
    pub participants: Vec<ParticipantState>,
    pub tracking_duration_minutes: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticipantState {
    pub id: String,
    pub name: String,
    pub estimated_arrival_minutes: Option<i32>, // null=waiting, 0=arrived, >0=N minutes
}

#[derive(Debug, Deserialize)]
pub struct VoteRespondRequest {
    pub response: String, // "accepted" | "declined"
    pub user_name: Option<String>,
}

// ============================================================
// 응답 DTO
// ============================================================

#[derive(Debug, Serialize)]
pub struct LiveActivityResponse {
    pub success: bool,
    pub success_count: i32,
    pub failure_count: i32,
}

#[derive(Debug, Serialize)]
pub struct VoteStartResponse {
    pub success: bool,
    pub success_count: i32,
    pub failure_count: i32,
    pub channel_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoteMember {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct VoteContentState {
    pub accepted: Vec<VoteMember>,
    pub declined: Vec<VoteMember>,
    pub pending_count: i32,
    pub is_finalized: bool,
}

#[derive(Debug, Serialize)]
pub struct VoteRespondResponse {
    pub success: bool,
    pub content_state: VoteContentState,
}

// ============================================================
// DB 모델 -- scheduled_tasks 테이블
// ============================================================

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ScheduledTask {
    pub id: Uuid,
    pub task_type: String,
    pub schedule_id: Uuid,
    pub execute_at: DateTime<Utc>,
    pub payload: serde_json::Value,
    pub status: String,
    pub retry_count: i16,
    pub max_retries: i16,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
