use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::notification::*;

// ============================================================
// 디바이스 관리
// ============================================================

pub async fn upsert_device(
    _pool: &PgPool,
    _user_uid: &str,
    _req: UpsertDeviceRequest,
) -> Result<DeviceResponse, AppError> {
    todo!("Red phase")
}

pub async fn delete_device(
    _pool: &PgPool,
    _user_uid: &str,
    _device_id: &str,
) -> Result<(), AppError> {
    todo!("Red phase")
}

pub async fn delete_all_devices(_pool: &PgPool, _user_uid: &str) -> Result<(), AppError> {
    todo!("Red phase")
}

// ============================================================
// 알림 CRUD
// ============================================================

pub async fn get_notifications(
    _pool: &PgPool,
    _user_uid: &str,
    _query: GetNotificationsQuery,
) -> Result<Vec<NotificationResponse>, AppError> {
    todo!("Red phase")
}

pub async fn get_unread_count(
    _pool: &PgPool,
    _user_uid: &str,
) -> Result<UnreadCountResponse, AppError> {
    todo!("Red phase")
}

pub async fn mark_as_read(
    _pool: &PgPool,
    _user_uid: &str,
    _notification_id: Uuid,
) -> Result<(), AppError> {
    todo!("Red phase")
}

pub async fn mark_all_as_read(_pool: &PgPool, _user_uid: &str) -> Result<(), AppError> {
    todo!("Red phase")
}

pub async fn delete_notifications(
    _pool: &PgPool,
    _user_uid: &str,
    _req: DeleteNotificationsRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}

pub async fn delete_all_notifications(_pool: &PgPool, _user_uid: &str) -> Result<(), AppError> {
    todo!("Red phase")
}

// ============================================================
// 푸시 전송 (내부)
// ============================================================

pub async fn send_push_internal(
    _pool: &PgPool,
    _push_sender: &dyn PushSender,
    _params: SendPushRequest,
) -> Result<PushResult, AppError> {
    todo!("Red phase")
}

// ============================================================
// 이벤트 트리거 (내부)
// ============================================================

/// 일정 생성 시 그룹 멤버에게 알림 (호스트 제외)
pub async fn notify_schedule_created(
    _pool: &PgPool,
    _push_sender: &dyn PushSender,
    _schedule_id: Uuid,
    _group_id: Uuid,
    _creator_id: &str,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 투표 상태 변경 시 알림 (confirmed/cancelled)
pub async fn notify_schedule_votes_updated(
    _pool: &PgPool,
    _push_sender: &dyn PushSender,
    _schedule_id: Uuid,
    _old_votes: &[VoteInfo],
    _new_votes: &[VoteInfo],
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 일정 정보 변경 시 알림 (필드 diff 포함)
pub async fn notify_schedule_info_updated(
    _pool: &PgPool,
    _push_sender: &dyn PushSender,
    _schedule_id: Uuid,
    _changes: &[FieldChange],
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 새 멤버 가입 시 기존 멤버에게 알림
pub async fn notify_group_member_joined(
    _pool: &PgPool,
    _push_sender: &dyn PushSender,
    _group_id: Uuid,
    _new_member_id: &str,
) -> Result<(), AppError> {
    todo!("Red phase")
}
