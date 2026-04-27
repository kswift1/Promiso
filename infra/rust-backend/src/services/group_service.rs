use chrono::{DateTime, Utc};
use rand::random_range;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::group::*;
use crate::models::notification::PushSender;
use crate::services::notification_service;
use crate::services::storage_service::GcsUploadSigner;

/// [H5] build_group_response 단일 쿼리 결과를 매핑하기 위한 내부 구조체
#[derive(sqlx::FromRow)]
struct GroupWithMembership {
    // groups 테이블
    id: Uuid,
    name: String,
    description: Option<String>,
    image_url: Option<String>,
    max_members: i16,
    invite_code: String,
    #[allow(dead_code)]
    last_activity_at: DateTime<Utc>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    // group_members 테이블
    role: String,
    group_color: String,
    notifications_enabled: bool,
    schedule_invitation: bool,
    schedule_reminder: bool,
    schedule_confirmed: bool,
    schedule_cancelled: bool,
    schedule_updated: bool,
    attendance_response: bool,
    group_update: bool,
    calendar_sync: bool,
    #[allow(dead_code)]
    member_joined_at: DateTime<Utc>,
    last_read_at: DateTime<Utc>,
    // 서브쿼리 결과
    admin_uid: Option<String>,
    member_count: i64,
}

const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const INVITE_CODE_LEN: usize = 6;
const MAX_INVITE_CODE_RETRIES: usize = 5;

const ROLE_ADMIN: &str = "admin";
#[allow(dead_code)]
const ROLE_MEMBER: &str = "member";

const GROUP_COLOR_PALETTE: &[&str] = &[
    "#FF3B30", "#FF6F61", "#FF9500", "#FFCC00", "#84CC16", "#34C759", "#00C7BE", "#007AFF",
    "#1E3F8A", "#AF52DE", "#C4B5FD", "#E040FB", "#FF6B9D", "#C2185B", "#A0845C", "#8E8E93",
];

// ============================================================
// 헬퍼
// ============================================================

fn generate_invite_code() -> String {
    (0..INVITE_CODE_LEN)
        .map(|_| CHARSET[random_range(0..CHARSET.len())] as char)
        .collect()
}

fn validate_group_name(name: &str) -> Result<String, AppError> {
    let trimmed = name.trim().to_string();
    let char_count = trimmed.chars().count();

    if char_count < 2 {
        return Err(AppError::BadRequest(
            "그룹 이름은 2자 이상이어야 합니다".to_string(),
        ));
    }
    if char_count > 12 {
        return Err(AppError::BadRequest(
            "그룹 이름은 12자 이하여야 합니다".to_string(),
        ));
    }

    Ok(trimmed)
}

fn validate_description(description: &Option<String>) -> Result<Option<String>, AppError> {
    match description {
        None => Ok(None),
        Some(desc) => {
            let trimmed = desc.trim().to_string();
            if trimmed.chars().count() > 50 {
                return Err(AppError::BadRequest(
                    "그룹 설명은 50자 이하여야 합니다".to_string(),
                ));
            }
            if trimmed.is_empty() {
                Ok(None)
            } else {
                Ok(Some(trimmed))
            }
        }
    }
}

fn validate_max_members(max_members: Option<i16>) -> Result<i16, AppError> {
    let value = max_members.unwrap_or(10);
    if value < 2 {
        return Err(AppError::BadRequest(
            "최대 인원은 2명 이상이어야 합니다".to_string(),
        ));
    }
    if value > 10 {
        return Err(AppError::BadRequest(
            "최대 인원은 10명 이하여야 합니다".to_string(),
        ));
    }
    Ok(value)
}

/// 멤버십 확인 — 멤버가 아니면 Forbidden 반환
async fn check_member(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<GroupMember, AppError> {
    sqlx::query_as::<_, GroupMember>(
        "SELECT group_id, user_id, role::TEXT as role, group_color, \
                notifications_enabled, schedule_invitation, schedule_reminder, \
                schedule_confirmed, schedule_cancelled, schedule_updated, \
                attendance_response, group_update, calendar_sync, \
                joined_at, last_read_at \
         FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?
    .ok_or_else(|| AppError::Forbidden("그룹 멤버가 아닙니다".to_string()))
}

/// 호스트(admin) 권한 확인 — 멤버가 아니거나 admin이 아니면 Forbidden 반환
async fn check_admin(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<GroupMember, AppError> {
    let member = check_member(pool, user_uid, group_id).await?;
    if member.role != ROLE_ADMIN {
        return Err(AppError::Forbidden(
            "호스트만 수행할 수 있습니다".to_string(),
        ));
    }
    Ok(member)
}

/// 그룹 멤버 수 조회
async fn get_member_count(pool: &PgPool, group_id: Uuid) -> Result<i64, AppError> {
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
        .bind(group_id)
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;
    Ok(count.0)
}

/// [H5] GroupResponse 조립 헬퍼 — 단일 쿼리로 group + membership + admin + member_count 통합
async fn build_group_response(
    pool: &PgPool,
    group_id: Uuid,
    user_uid: &str,
) -> Result<GroupResponse, AppError> {
    let row = sqlx::query_as::<_, GroupWithMembership>(
        "SELECT g.id, g.name, g.description, g.image_url, g.max_members, \
                g.invite_code, g.last_activity_at, g.created_at, g.updated_at, \
                gm.role::TEXT as role, gm.group_color, gm.notifications_enabled, \
                gm.schedule_invitation, gm.schedule_reminder, gm.schedule_confirmed, \
                gm.schedule_cancelled, gm.schedule_updated, gm.attendance_response, \
                gm.group_update, gm.calendar_sync, gm.joined_at as member_joined_at, gm.last_read_at, \
                (SELECT user_id FROM group_members WHERE group_id = g.id AND role = 'admin'::group_member_role) AS admin_uid, \
                (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) AS member_count \
         FROM groups g \
         JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = $2 \
         WHERE g.id = $1",
    )
    .bind(group_id)
    .bind(user_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 결과 없음: 그룹 자체가 없는지 vs 멤버가 아닌지 구분
    let row = match row {
        Some(r) => r,
        None => {
            let group_exists = sqlx::query_as::<_, (Uuid,)>("SELECT id FROM groups WHERE id = $1")
                .bind(group_id)
                .fetch_optional(pool)
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

            return if group_exists.is_none() {
                Err(AppError::NotFound("그룹을 찾을 수 없습니다".to_string()))
            } else {
                Err(AppError::Forbidden("그룹 멤버가 아닙니다".to_string()))
            };
        }
    };

    Ok(GroupResponse {
        group_id: row.id.to_string(),
        name: row.name,
        description: row.description,
        image_url: row.image_url,
        max_members: row.max_members,
        invite_code: row.invite_code,
        created_by: row.admin_uid.unwrap_or_default(),
        member_count: row.member_count,
        role: row.role,
        group_color: row.group_color,
        notification_settings: NotificationSettingsResponse {
            enabled: row.notifications_enabled,
            schedule: ScheduleNotificationSettingsResponse {
                invitation: row.schedule_invitation,
                reminder: row.schedule_reminder,
                confirmed: row.schedule_confirmed,
                cancelled: row.schedule_cancelled,
                updated: row.schedule_updated,
                attendance_response: row.attendance_response,
            },
            group: GroupNotificationSettingsResponse {
                update: row.group_update,
            },
            calendar_sync: row.calendar_sync,
        },
        last_read_at: row.last_read_at,
        created_at: row.created_at,
        updated_at: row.updated_at,
    })
}

// ============================================================
// 서비스 함수
// ============================================================

/// [H1] 그룹 생성 -- 트랜잭션으로 groups INSERT + admin INSERT를 원자적으로 실행
pub async fn create_group(
    pool: &PgPool,
    creator_uid: &str,
    req: CreateGroupRequest,
) -> Result<CreateGroupResponse, AppError> {
    // 검증
    let name = validate_group_name(&req.name)?;
    let description = validate_description(&req.description)?;
    let max_members = validate_max_members(req.max_members)?;

    // 트랜잭션 시작
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // 초대 코드 생성 (충돌 시 재시도) — 트랜잭션 안에서 실행
    let mut invite_code = generate_invite_code();
    let mut group_row: Option<Group> = None;

    for attempt in 0..MAX_INVITE_CODE_RETRIES {
        let result = sqlx::query_as::<_, Group>(
            "INSERT INTO groups (name, description, max_members, invite_code) \
             VALUES ($1, $2, $3, $4) \
             RETURNING *",
        )
        .bind(&name)
        .bind(&description)
        .bind(max_members)
        .bind(&invite_code)
        .fetch_one(&mut *tx)
        .await;

        match result {
            Ok(g) => {
                group_row = Some(g);
                break;
            }
            Err(sqlx::Error::Database(ref db_err))
                if db_err.code().as_deref() == Some("23505")
                    && db_err
                        .constraint()
                        .map_or(false, |c| c.contains("invite_code")) =>
            {
                if attempt == MAX_INVITE_CODE_RETRIES - 1 {
                    return Err(AppError::Internal(
                        "초대 코드 생성에 실패했습니다".to_string(),
                    ));
                }
                invite_code = generate_invite_code();
            }
            Err(e) => return Err(AppError::Internal(e.to_string())),
        }
    }

    let group =
        group_row.ok_or_else(|| AppError::Internal("초대 코드 생성에 실패했습니다".to_string()))?;

    // 생성자를 admin으로 등록 — 같은 트랜잭션
    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) \
         VALUES ($1, $2, 'admin'::group_member_role)",
    )
    .bind(group.id)
    .bind(creator_uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 커밋
    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(CreateGroupResponse {
        group_id: group.id.to_string(),
        invite_code: group.invite_code,
        created_at: group.created_at,
    })
}

/// 초대 코드로 그룹 미리보기 -- 인증 불필요, 멤버 최대 10명 반환
pub async fn preview_group(
    pool: &PgPool,
    invite_code: &str,
) -> Result<GroupPreviewResponse, AppError> {
    let normalized = invite_code.trim().to_uppercase();

    let group = sqlx::query_as::<_, Group>("SELECT * FROM groups WHERE invite_code = $1")
        .bind(&normalized)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("그룹을 찾을 수 없습니다".to_string()))?;

    let member_count = get_member_count(pool, group.id).await?;

    // 멤버 미리보기 (최대 10명, users JOIN)
    let preview_members = sqlx::query_as::<_, (String, String, Option<String>)>(
        "SELECT gm.user_id, u.nickname, u.profile_url \
         FROM group_members gm \
         JOIN users u ON gm.user_id = u.id \
         WHERE gm.group_id = $1 \
         ORDER BY gm.joined_at ASC \
         LIMIT 10",
    )
    .bind(group.id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?
    .into_iter()
    .map(|(user_id, nickname, profile_url)| GroupMemberPreview {
        user_id,
        nickname,
        profile_url,
    })
    .collect();

    Ok(GroupPreviewResponse {
        group_id: group.id.to_string(),
        name: group.name,
        description: group.description,
        image_url: group.image_url,
        member_count,
        max_members: group.max_members,
        preview_members,
    })
}

/// [H2] 초대 코드로 그룹 가입 -- 트랜잭션으로 원자적 read-check-write + PK 충돌 처리
pub async fn join_group(
    pool: &PgPool,
    user_uid: &str,
    invite_code: &str,
) -> Result<GroupResponse, AppError> {
    join_group_impl(pool, None, user_uid, invite_code).await
}

pub async fn join_group_with_push_sender(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    user_uid: &str,
    invite_code: &str,
) -> Result<GroupResponse, AppError> {
    join_group_impl(pool, Some(push_sender), user_uid, invite_code).await
}

async fn join_group_impl(
    pool: &PgPool,
    push_sender: Option<&dyn PushSender>,
    user_uid: &str,
    invite_code: &str,
) -> Result<GroupResponse, AppError> {
    let normalized = invite_code.trim().to_uppercase();

    // 그룹 조회 (트랜잭션 밖 -- 그룹 존재 확인은 읽기 전용)
    let group = sqlx::query_as::<_, Group>("SELECT * FROM groups WHERE invite_code = $1")
        .bind(&normalized)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("그룹을 찾을 수 없습니다".to_string()))?;

    // 트랜잭션: 멤버십 확인 + 정원 확인 + INSERT를 원자적으로 실행
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // 이미 멤버인지 확인 (트랜잭션 안에서)
    let existing = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group.id)
    .bind(user_uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if existing.is_some() {
        return Err(AppError::Conflict(
            "이미 그룹에 가입되어 있습니다".to_string(),
        ));
    }

    // 정원 확인 (트랜잭션 안에서)
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
        .bind(group.id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if count.0 >= group.max_members as i64 {
        return Err(AppError::BadRequest(
            "그룹 정원이 가득 찼습니다".to_string(),
        ));
    }

    // 멤버 추가 (PK 충돌 시 Conflict로 처리)
    let insert_result = sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) \
         VALUES ($1, $2, 'member'::group_member_role)",
    )
    .bind(group.id)
    .bind(user_uid)
    .execute(&mut *tx)
    .await;

    match insert_result {
        Ok(_) => {}
        Err(sqlx::Error::Database(ref db_err))
            if db_err.code().as_deref() == Some("23505")
                && db_err
                    .constraint()
                    .map_or(false, |c| c.contains("group_members_pkey")) =>
        {
            return Err(AppError::Conflict(
                "이미 그룹에 가입되어 있습니다".to_string(),
            ));
        }
        Err(e) => return Err(AppError::Internal(e.to_string())),
    }

    // 커밋
    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if let Some(push_sender) = push_sender {
        if let Err(error) =
            notification_service::notify_group_member_joined(pool, push_sender, group.id, user_uid)
                .await
        {
            tracing::error!(
                "Failed to notify group join for group {} and user {}: {}",
                group.id,
                user_uid,
                error
            );
        }
    }

    // 가입 후 GroupResponse 반환
    build_group_response(pool, group.id, user_uid).await
}

/// 그룹 탈퇴 -- 호스트는 탈퇴 불가
pub async fn leave_group(pool: &PgPool, user_uid: &str, group_id: Uuid) -> Result<(), AppError> {
    let member = check_member(pool, user_uid, group_id).await?;

    if member.role == ROLE_ADMIN {
        return Err(AppError::PreconditionFailed(
            "호스트는 그룹을 탈퇴할 수 없습니다. 먼저 호스트를 양도해주세요.".to_string(),
        ));
    }

    sqlx::query("DELETE FROM group_members WHERE group_id = $1 AND user_id = $2")
        .bind(group_id)
        .bind(user_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// [M1] 그룹 정보 수정 -- 호스트만 가능, Option<Option<String>>으로 null 클리어 지원
pub async fn update_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: UpdateGroupRequest,
) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    // 검증: description
    // Some(Some(val)) -> 값 변경 (검증 필요)
    // Some(None) -> 삭제 (검증 불필요)
    // None -> 변경 없음
    if let Some(Some(ref desc)) = req.description {
        if desc.trim().chars().count() > 50 {
            return Err(AppError::BadRequest(
                "그룹 설명은 50자 이하여야 합니다".to_string(),
            ));
        }
    }

    // 검증: max_members
    if let Some(max) = req.max_members {
        if max < 2 || max > 10 {
            return Err(AppError::BadRequest(
                "최대 인원은 2명 이상 10명 이하여야 합니다".to_string(),
            ));
        }
        // 현재 멤버 수보다 작으면 거부
        let current_count = get_member_count(pool, group_id).await?;
        if (max as i64) < current_count {
            return Err(AppError::BadRequest(
                "현재 멤버 수보다 작게 설정할 수 없습니다".to_string(),
            ));
        }
    }

    // 동적 UPDATE 빌드
    let mut set_clauses: Vec<String> = Vec::new();
    let mut param_index = 1u32;

    // description: Some(_) -> 변경 또는 삭제
    if req.description.is_some() {
        set_clauses.push(format!("description = ${}", param_index));
        param_index += 1;
    }
    if req.max_members.is_some() {
        set_clauses.push(format!("max_members = ${}", param_index));
        param_index += 1;
    }
    // image_url: Some(_) -> 변경 또는 삭제
    if req.image_url.is_some() {
        set_clauses.push(format!("image_url = ${}", param_index));
        param_index += 1;
    }

    if set_clauses.is_empty() {
        // 변경할 것이 없으면 바로 성공
        return Ok(());
    }

    set_clauses.push("updated_at = NOW()".to_string());

    let sql = format!(
        "UPDATE groups SET {} WHERE id = ${}",
        set_clauses.join(", "),
        param_index
    );

    let mut query = sqlx::query(&sql);

    // description 바인딩: Option<Option<String>> -> Option<String>
    if let Some(ref inner) = req.description {
        match inner {
            None => {
                // Some(None) -> SET description = NULL
                query = query.bind(None::<String>);
            }
            Some(desc) => {
                let trimmed = desc.trim();
                if trimmed.is_empty() {
                    query = query.bind(None::<String>);
                } else {
                    query = query.bind(Some(trimmed.to_string()));
                }
            }
        }
    }
    if let Some(max) = req.max_members {
        query = query.bind(max);
    }
    // image_url 바인딩: Option<Option<String>> -> Option<String>
    if let Some(ref inner) = req.image_url {
        match inner {
            None => {
                // Some(None) -> SET image_url = NULL
                query = query.bind(None::<String>);
            }
            Some(url) => {
                query = query.bind(Some(url.clone()));
            }
        }
    }

    query = query.bind(group_id);

    query
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn issue_group_image_upload_url(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: IssueGroupImageUploadUrlRequest,
    signer: &GcsUploadSigner,
) -> Result<IssueGroupImageUploadUrlResponse, AppError> {
    check_admin(pool, user_uid, group_id).await?;

    let content_type = req
        .content_type
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("image/jpeg");

    if content_type != "image/jpeg" {
        return Err(AppError::BadRequest(
            "그룹 이미지는 image/jpeg만 지원합니다".to_string(),
        ));
    }

    let object_path = format!("group_images/{group_id}/{}.jpg", Uuid::new_v4());
    let target = signer.sign_put_object(&object_path, content_type)?;

    Ok(IssueGroupImageUploadUrlResponse {
        object_path: target.object_path,
        upload_url: target.upload_url,
        image_url: target.public_url,
        expires_at: target.expires_at,
        content_type: target.content_type,
    })
}

/// 그룹 삭제 -- 호스트만 가능, cascade 처리
pub async fn delete_group(pool: &PgPool, user_uid: &str, group_id: Uuid) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    sqlx::query("DELETE FROM groups WHERE id = $1")
        .bind(group_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// [H3] 호스트 양도 -- 트랜잭션 안에서 모든 검증 + role 변경 + rows_affected 확인
pub async fn transfer_host(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: TransferHostRequest,
) -> Result<(), AppError> {
    // 자기 자신에게 양도 불가 (트랜잭션 전 빠른 검증)
    if req.new_host_uid == user_uid {
        return Err(AppError::BadRequest(
            "자기 자신에게 호스트를 양도할 수 없습니다".to_string(),
        ));
    }

    // 트랜잭션 시작 — 모든 검증을 트랜잭션 안에서 수행
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // admin 확인 (트랜잭션 안에서)
    let caller = sqlx::query_as::<_, (String,)>(
        "SELECT role::TEXT FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?
    .ok_or_else(|| AppError::Forbidden("그룹 멤버가 아닙니다".to_string()))?;

    if caller.0 != ROLE_ADMIN {
        return Err(AppError::Forbidden(
            "호스트만 수행할 수 있습니다".to_string(),
        ));
    }

    // 대상이 그룹 멤버인지 확인 (트랜잭션 안에서)
    let target = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.new_host_uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if target.is_none() {
        return Err(AppError::BadRequest(
            "양도 대상이 그룹 멤버가 아닙니다".to_string(),
        ));
    }

    // 기존 호스트 -> member
    sqlx::query(
        "UPDATE group_members SET role = 'member'::group_member_role \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 신규 호스트 -> admin (rows_affected 확인)
    let result = sqlx::query(
        "UPDATE group_members SET role = 'admin'::group_member_role \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.new_host_uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(AppError::BadRequest(
            "양도 대상이 그룹 멤버가 아닙니다".to_string(),
        ));
    }

    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 멤버 추방 -- 호스트만 가능, 자기 자신 추방 불가
pub async fn expel_member(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: ExpelMemberRequest,
) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    // 자기 자신 추방 불가
    if req.target_uid == user_uid {
        return Err(AppError::BadRequest(
            "자기 자신을 추방할 수 없습니다".to_string(),
        ));
    }

    // 대상이 그룹 멤버인지 확인 + role 조회
    let target = sqlx::query_as::<_, (String, String)>(
        "SELECT user_id, role::TEXT as role FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.target_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    match &target {
        None => {
            return Err(AppError::BadRequest(
                "추방 대상이 그룹 멤버가 아닙니다".to_string(),
            ));
        }
        Some((_, role)) if role == ROLE_ADMIN => {
            return Err(AppError::BadRequest(
                "호스트는 추방할 수 없습니다. 먼저 호스트를 양도해주세요.".to_string(),
            ));
        }
        _ => {}
    }

    sqlx::query("DELETE FROM group_members WHERE group_id = $1 AND user_id = $2")
        .bind(group_id)
        .bind(&req.target_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// [H4] 내 그룹 목록 조회 -- 서브쿼리로 member_count 포함, N+1 제거
pub async fn fetch_my_groups(
    pool: &PgPool,
    user_uid: &str,
) -> Result<Vec<GroupSummaryResponse>, AppError> {
    let rows = sqlx::query_as::<_, (
        Uuid,          // g.id
        String,        // g.name
        Option<String>,// g.description
        Option<String>,// g.image_url
        i16,           // g.max_members
        String,        // gm.role
        String,        // gm.group_color
        chrono::DateTime<chrono::Utc>, // g.last_activity_at
        chrono::DateTime<chrono::Utc>, // gm.last_read_at
        chrono::DateTime<chrono::Utc>, // gm.joined_at
        i64,           // member_count
    )>(
        "SELECT g.id, g.name, g.description, g.image_url, g.max_members, \
                gm.role::TEXT as role, gm.group_color, g.last_activity_at, gm.last_read_at, gm.joined_at, \
                (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) AS member_count \
         FROM group_members gm \
         JOIN groups g ON gm.group_id = g.id \
         WHERE gm.user_id = $1 \
         ORDER BY gm.joined_at DESC",
    )
    .bind(user_uid)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let result = rows
        .into_iter()
        .map(
            |(
                id,
                name,
                description,
                image_url,
                max_members,
                role,
                group_color,
                last_activity_at,
                last_read_at,
                joined_at,
                member_count,
            )| {
                let has_new_activity = last_activity_at > last_read_at;

                GroupSummaryResponse {
                    group_id: id.to_string(),
                    name,
                    description,
                    image_url,
                    max_members,
                    member_count,
                    role,
                    group_color,
                    has_new_activity,
                    joined_at,
                }
            },
        )
        .collect();

    Ok(result)
}

/// 그룹 상세 조회 -- 멤버만 접근 가능
pub async fn fetch_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<GroupResponse, AppError> {
    // build_group_response 내부에서 그룹 존재 + 멤버십 확인을 한 번에 처리
    build_group_response(pool, group_id, user_uid).await
}

/// 그룹 멤버 목록 조회 -- 멤버만 접근 가능
pub async fn fetch_group_members(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<Vec<GroupMemberResponse>, AppError> {
    check_member(pool, user_uid, group_id).await?;

    let members = sqlx::query_as::<_, (String, String, Option<String>, String, String, chrono::DateTime<chrono::Utc>)>(
        "SELECT gm.user_id, u.nickname, u.profile_url, gm.role::TEXT as role, gm.group_color, gm.joined_at \
         FROM group_members gm \
         JOIN users u ON gm.user_id = u.id \
         WHERE gm.group_id = $1 \
         ORDER BY gm.joined_at ASC",
    )
    .bind(group_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(members
        .into_iter()
        .map(
            |(user_id, nickname, profile_url, role, group_color, joined_at)| GroupMemberResponse {
                user_id,
                nickname,
                profile_url,
                role,
                group_color,
                joined_at,
            },
        )
        .collect())
}

/// 그룹 읽음 마커 갱신 -- last_read_at 업데이트
pub async fn mark_group_read(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<(), AppError> {
    check_member(pool, user_uid, group_id).await?;

    sqlx::query(
        "UPDATE group_members SET last_read_at = NOW() \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 알림 설정 업데이트
pub async fn update_notification_settings(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    settings: NotificationSettingsRequest,
) -> Result<(), AppError> {
    check_member(pool, user_uid, group_id).await?;

    sqlx::query(
        "UPDATE group_members SET \
         notifications_enabled = $1, \
         schedule_invitation = $2, \
         schedule_reminder = $3, \
         schedule_confirmed = $4, \
         schedule_cancelled = $5, \
         schedule_updated = $6, \
         attendance_response = $7, \
         group_update = $8, \
         calendar_sync = $9 \
         WHERE group_id = $10 AND user_id = $11",
    )
    .bind(settings.enabled)
    .bind(settings.schedule.invitation)
    .bind(settings.schedule.reminder)
    .bind(settings.schedule.confirmed)
    .bind(settings.schedule.cancelled)
    .bind(settings.schedule.updated)
    .bind(settings.schedule.attendance_response)
    .bind(settings.group.update)
    .bind(settings.calendar_sync)
    .bind(group_id)
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 여러 그룹 batch 조회 -- 사용자가 멤버인 그룹만 반환, 입력 순서 보존
pub async fn get_groups_batch(
    pool: &PgPool,
    user_uid: &str,
    ids: Vec<Uuid>,
) -> Result<Vec<GroupResponse>, AppError> {
    if ids.is_empty() {
        return Ok(vec![]);
    }

    let rows = sqlx::query_as::<_, GroupWithMembership>(
        "SELECT g.id, g.name, g.description, g.image_url, g.max_members, \
                g.invite_code, g.last_activity_at, g.created_at, g.updated_at, \
                gm.role::TEXT as role, gm.group_color, gm.notifications_enabled, \
                gm.schedule_invitation, gm.schedule_reminder, gm.schedule_confirmed, \
                gm.schedule_cancelled, gm.schedule_updated, gm.attendance_response, \
                gm.group_update, gm.calendar_sync, gm.joined_at as member_joined_at, gm.last_read_at, \
                (SELECT user_id FROM group_members WHERE group_id = g.id AND role = 'admin'::group_member_role) AS admin_uid, \
                (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) AS member_count \
         FROM groups g \
         JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = $2 \
         WHERE g.id = ANY($1)",
    )
    .bind(&ids)
    .bind(user_uid)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 입력 순서 보존 (iOS가 순서를 기대할 수 있음)
    let row_map: std::collections::HashMap<Uuid, &GroupWithMembership> =
        rows.iter().map(|r| (r.id, r)).collect();

    Ok(ids
        .iter()
        .filter_map(|id| row_map.get(id))
        .map(|row| GroupResponse {
            group_id: row.id.to_string(),
            name: row.name.clone(),
            description: row.description.clone(),
            image_url: row.image_url.clone(),
            max_members: row.max_members,
            invite_code: row.invite_code.clone(),
            created_by: row.admin_uid.clone().unwrap_or_default(),
            member_count: row.member_count,
            role: row.role.clone(),
            group_color: row.group_color.clone(),
            notification_settings: NotificationSettingsResponse {
                enabled: row.notifications_enabled,
                schedule: ScheduleNotificationSettingsResponse {
                    invitation: row.schedule_invitation,
                    reminder: row.schedule_reminder,
                    confirmed: row.schedule_confirmed,
                    cancelled: row.schedule_cancelled,
                    updated: row.schedule_updated,
                    attendance_response: row.attendance_response,
                },
                group: GroupNotificationSettingsResponse {
                    update: row.group_update,
                },
                calendar_sync: row.calendar_sync,
            },
            last_read_at: row.last_read_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
        .collect())
}

/// 그룹 색상 업데이트
pub async fn update_group_color(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: UpdateGroupColorRequest,
) -> Result<(), AppError> {
    check_member(pool, user_uid, group_id).await?;

    // 팔레트 검증
    if !GROUP_COLOR_PALETTE.contains(&req.color.as_str()) {
        return Err(AppError::BadRequest("허용되지 않은 색상입니다".to_string()));
    }

    sqlx::query(
        "UPDATE group_members SET group_color = $1 \
         WHERE group_id = $2 AND user_id = $3",
    )
    .bind(&req.color)
    .bind(group_id)
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}
