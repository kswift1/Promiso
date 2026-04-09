use chrono::{DateTime, Utc};
use serde::de::Deserializer;
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

/// JSON에서 필드 없음 → `None`, `"field": null` → `Some(None)`, `"field": "val"` → `Some(Some("val"))`
/// `#[serde(default, deserialize_with = "deserialize_optional_field")]` 와 함께 사용
pub fn deserialize_optional_field<'de, D>(
    deserializer: D,
) -> Result<Option<Option<String>>, D::Error>
where
    D: Deserializer<'de>,
{
    Ok(Some(Option::deserialize(deserializer)?))
}

// ============================================================
// DB 모델
// ============================================================

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Group {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i16,
    pub invite_code: String,
    pub last_activity_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct GroupMember {
    pub group_id: Uuid,
    pub user_id: String,
    pub role: String,
    pub group_color: String,
    pub notifications_enabled: bool,
    pub schedule_invitation: bool,
    pub schedule_reminder: bool,
    pub schedule_confirmed: bool,
    pub schedule_cancelled: bool,
    pub schedule_updated: bool,
    pub attendance_response: bool,
    pub group_update: bool,
    pub calendar_sync: bool,
    pub joined_at: DateTime<Utc>,
    pub last_read_at: DateTime<Utc>,
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
pub struct CreateGroupRequest {
    pub name: String,
    pub description: Option<String>,
    pub max_members: Option<i16>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UpdateGroupRequest {
    // 이름은 변경 불가 — 필드 자체를 제외하여 컴파일타임 강제
    // deny_unknown_fields로 클라이언트가 name을 보내면 400 반환
    //
    // Option<Option<String>> 패턴:
    //   None          → 변경 없음 (JSON에서 필드 생략)
    //   Some(None)    → 삭제 (JSON에서 "field": null)
    //   Some(Some(v)) → 값 변경 (JSON에서 "field": "value")
    #[serde(default, deserialize_with = "deserialize_optional_field")]
    pub description: Option<Option<String>>,
    pub max_members: Option<i16>,
    #[serde(default, deserialize_with = "deserialize_optional_field")]
    pub image_url: Option<Option<String>>,
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

#[derive(Debug, Deserialize, Serialize)]
pub struct ScheduleNotificationSettings {
    pub invitation: bool,
    pub reminder: bool,
    pub confirmed: bool,
    pub cancelled: bool,
    pub updated: bool,
    pub attendance_response: bool,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct GroupNotificationSettings {
    pub update: bool,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct NotificationSettingsRequest {
    pub enabled: bool,
    pub schedule: ScheduleNotificationSettings,
    pub group: GroupNotificationSettings,
    pub calendar_sync: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGroupColorRequest {
    pub color: String,
}

#[derive(Debug, Deserialize)]
pub struct BatchGroupsRequest {
    pub ids: Vec<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct IssueGroupImageUploadUrlRequest {
    pub content_type: Option<String>,
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
pub struct ScheduleNotificationSettingsResponse {
    pub invitation: bool,
    pub reminder: bool,
    pub confirmed: bool,
    pub cancelled: bool,
    pub updated: bool,
    pub attendance_response: bool,
}

#[derive(Debug, Serialize)]
pub struct GroupNotificationSettingsResponse {
    pub update: bool,
}

#[derive(Debug, Serialize)]
pub struct NotificationSettingsResponse {
    pub enabled: bool,
    pub schedule: ScheduleNotificationSettingsResponse,
    pub group: GroupNotificationSettingsResponse,
    pub calendar_sync: bool,
}

#[derive(Debug, Serialize)]
pub struct GroupResponse {
    pub group_id: String,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i16,
    pub invite_code: String,
    pub created_by: String,
    pub member_count: i64,
    pub role: String,
    pub group_color: String,
    pub notification_settings: NotificationSettingsResponse,
    pub last_read_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct GroupSummaryResponse {
    pub group_id: String,
    pub name: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub max_members: i16,
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
    pub max_members: i16,
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

#[derive(Debug, Serialize)]
pub struct IssueGroupImageUploadUrlResponse {
    pub object_path: String,
    pub upload_url: String,
    pub image_url: String,
    pub expires_at: DateTime<Utc>,
    pub content_type: String,
}
