use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::group::*;

/// 그룹 생성 — 생성자가 admin으로 등록되고 초대 코드 발급
pub async fn create_group(
    _pool: &PgPool,
    _creator_uid: &str,
    _req: CreateGroupRequest,
) -> Result<CreateGroupResponse, AppError> {
    todo!("Red phase")
}

/// 초대 코드로 그룹 미리보기 — 인증 불필요, 멤버 최대 10명 반환
pub async fn preview_group(
    _pool: &PgPool,
    _invite_code: &str,
) -> Result<GroupPreviewResponse, AppError> {
    todo!("Red phase")
}

/// 초대 코드로 그룹 가입 — 가입 시 알림 전체 ON + 캘린더 동기화 ON
pub async fn join_group(
    _pool: &PgPool,
    _user_uid: &str,
    _invite_code: &str,
) -> Result<GroupResponse, AppError> {
    todo!("Red phase")
}

/// 그룹 탈퇴 — 호스트는 탈퇴 불가
pub async fn leave_group(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 그룹 정보 수정 — 호스트만 가능, 이름 변경 불가
pub async fn update_group(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
    _req: UpdateGroupRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 그룹 삭제 — 호스트만 가능, cascade 처리
pub async fn delete_group(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 호스트 양도 — 기존 호스트 → member, 신규 호스트 → admin
pub async fn transfer_host(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
    _req: TransferHostRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 멤버 추방 — 호스트만 가능, 자기 자신 추방 불가
pub async fn expel_member(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
    _req: ExpelMemberRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 내 그룹 목록 조회 — joinedAt 내림차순, JOIN/aggregation 단일 쿼리
pub async fn fetch_my_groups(
    _pool: &PgPool,
    _user_uid: &str,
) -> Result<Vec<GroupSummaryResponse>, AppError> {
    todo!("Red phase")
}

/// 그룹 상세 조회 — 멤버만 접근 가능
pub async fn fetch_group(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
) -> Result<GroupResponse, AppError> {
    todo!("Red phase")
}

/// 그룹 멤버 목록 조회 — 멤버만 접근 가능
pub async fn fetch_group_members(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
) -> Result<Vec<GroupMemberResponse>, AppError> {
    todo!("Red phase")
}

/// 그룹 읽음 마커 갱신 — last_read_at 업데이트
pub async fn mark_group_read(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 알림 설정 업데이트
pub async fn update_notification_settings(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
    _settings: NotificationSettingsRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}

/// 그룹 색상 업데이트
pub async fn update_group_color(
    _pool: &PgPool,
    _user_uid: &str,
    _group_id: Uuid,
    _req: UpdateGroupColorRequest,
) -> Result<(), AppError> {
    todo!("Red phase")
}
