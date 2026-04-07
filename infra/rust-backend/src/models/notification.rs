use std::collections::HashMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

// ============================================================
// DB 열거형 (PostgreSQL 타입 매핑)
// ============================================================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "notification_type", rename_all = "snake_case")]
pub enum NotificationType {
    ScheduleInvitation,
    ScheduleReminder,
    ScheduleConfirmed,
    ScheduleCancelled,
    ScheduleUpdated,
    LocationSharingReminder,
    GroupInvitation,
    GroupUpdate,
    AttendanceResponse,
    System,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "notification_provider", rename_all = "snake_case")]
pub enum NotificationProvider {
    Fcm,
}

// ============================================================
// DB 모델
// ============================================================

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Device {
    pub id: Uuid,
    pub user_id: String,
    pub device_id: String,
    pub platform: String,
    pub last_active_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct NotificationEndpoint {
    pub id: Uuid,
    pub device_id: Uuid,
    pub provider: NotificationProvider,
    pub token: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct LiveActivityEndpoint {
    pub id: Uuid,
    pub device_id: Uuid,
    pub push_to_start_token: Option<String>,
    pub live_activity_push_token: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Notification {
    pub id: Uuid,
    pub user_id: String,
    pub notification_type: NotificationType,
    pub title: String,
    pub body: String,
    pub schedule_id: Option<Uuid>,
    pub group_id: Option<Uuid>,
    pub related_user_id: Option<String>,
    pub is_read: bool,
    pub is_delivered: bool,
    pub created_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
    pub delivered_at: Option<DateTime<Utc>>,
    pub data: Option<serde_json::Value>,
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
pub struct UpsertDeviceRequest {
    pub device_id: String,
    pub platform: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpsertNotificationEndpointRequest {
    pub token: String,
}

#[derive(Debug, Deserialize)]
pub struct UpsertLiveActivityEndpointRequest {
    pub push_to_start_token: Option<String>,
    pub live_activity_push_token: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct GetNotificationsQuery {
    pub limit: Option<i64>,
    pub before: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct DeleteNotificationsRequest {
    pub notification_ids: Vec<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct SendPushRequest {
    pub user_ids: Vec<String>,
    pub notification_type: NotificationType,
    pub title: String,
    pub body: String,
    pub schedule_id: Option<Uuid>,
    pub group_id: Option<Uuid>,
    pub related_user_id: Option<String>,
    pub data: Option<HashMap<String, String>>,
}

// ============================================================
// 응답 DTO
// ============================================================

#[derive(Debug, Serialize)]
pub struct DeviceResponse {
    pub device_id: String,
    pub platform: String,
    pub last_active_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct NotificationEndpointResponse {
    pub device_id: String,
    pub provider: NotificationProvider,
    pub token: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct LiveActivityEndpointResponse {
    pub device_id: String,
    pub push_to_start_token: Option<String>,
    pub live_activity_push_token: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct NotificationResponse {
    pub id: Uuid,
    pub notification_type: NotificationType,
    pub title: String,
    pub body: String,
    pub schedule_id: Option<Uuid>,
    pub group_id: Option<Uuid>,
    pub related_user_id: Option<String>,
    pub is_read: bool,
    pub created_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
    pub data: Option<HashMap<String, String>>,
}

#[derive(Debug, Serialize)]
pub struct UnreadCountResponse {
    pub count: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct PushResult {
    pub success: bool,
    pub success_count: i32,
    pub failure_count: i32,
}

// ============================================================
// FCM 추상화
// ============================================================

#[derive(Debug, Clone)]
pub struct FcmMessage {
    pub title: String,
    pub body: String,
    pub notification_type: NotificationType,
    pub data: Option<HashMap<String, String>>,
    pub schedule_id: Option<Uuid>,
    pub group_id: Option<Uuid>,
    pub related_user_id: Option<String>,
}

#[async_trait::async_trait]
pub trait PushSender: Send + Sync {
    async fn send_multicast(&self, tokens: &[String], message: &FcmMessage) -> PushResult;
}

// ============================================================
// 이벤트 트리거용 보조 구조체
// ============================================================

#[derive(Debug, Clone)]
pub struct VoteInfo {
    pub user_id: String,
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct FieldChange {
    pub field: String,
    pub old_value: Option<String>,
    pub new_value: Option<String>,
}
