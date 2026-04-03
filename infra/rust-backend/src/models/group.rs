use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

// ============================================================
// DB 모델
// ============================================================

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Group {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i32,
    pub invite_code: String,
    pub created_by: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct GroupMember {
    pub group_id: Uuid,
    pub user_id: String,
    pub role: String,
    pub group_color: String,
    pub notification_settings: serde_json::Value,
    pub calendar_sync: bool,
    pub last_read_at: Option<DateTime<Utc>>,
    pub joined_at: DateTime<Utc>,
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
pub struct CreateGroupRequest {
    pub name: String,
    pub description: Option<String>,
    pub max_members: Option<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UpdateGroupRequest {
    // 이름은 변경 불가 — 필드 자체를 제외하여 컴파일타임 강제
    // deny_unknown_fields로 클라이언트가 name을 보내면 400 반환
    pub description: Option<String>,
    pub max_members: Option<i32>,
    pub image_url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct JoinGroupRequest {
    pub invite_code: String,
}

#[derive(Debug, Deserialize)]
pub struct TransferHostRequest {
    pub new_host_uid: String,
}

#[derive(Debug, Deserialize)]
pub struct ExpelMemberRequest {
    pub target_uid: String,
}

#[derive(Debug, Deserialize)]
pub struct BatchGetGroupsRequest {
    pub group_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct NotificationSettingsRequest {
    pub enabled: bool,
    pub promise: bool,
    pub group: bool,
    pub calendar_sync: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGroupColorRequest {
    pub color: String,
}

// ============================================================
// 응답 DTO
// ============================================================

#[derive(Debug, Serialize)]
pub struct CreateGroupResponse {
    pub group_id: String,
    pub invite_code: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct GroupResponse {
    pub group_id: String,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i32,
    pub invite_code: String,
    pub created_by: String,
    pub member_count: i64,
    pub role: String,
    pub group_color: String,
    pub notification_settings: serde_json::Value,
    pub calendar_sync: bool,
    pub last_read_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct GroupSummaryResponse {
    pub group_id: String,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i32,
    pub member_count: i64,
    pub role: String,
    pub group_color: String,
    pub has_new_activity: bool,
    pub joined_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct GroupPreviewResponse {
    pub group_id: String,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub member_count: i64,
    pub max_members: i32,
    pub preview_members: Vec<GroupMemberPreview>,
}

#[derive(Debug, Serialize)]
pub struct GroupMemberPreview {
    pub user_id: String,
    pub nickname: String,
    pub profile_url: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct GroupMemberResponse {
    pub user_id: String,
    pub nickname: String,
    pub profile_url: Option<String>,
    pub role: String,
    pub group_color: String,
    pub joined_at: DateTime<Utc>,
}
