use rand::Rng;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::group::*;

const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const INVITE_CODE_LEN: usize = 6;
const MAX_INVITE_CODE_RETRIES: usize = 5;

const GROUP_COLOR_PALETTE: &[&str] = &[
    "#FF3B30", "#FF6F61", "#FF9500", "#FFCC00",
    "#84CC16", "#34C759", "#00C7BE", "#007AFF",
    "#1E3F8A", "#AF52DE", "#C4B5FD", "#E040FB",
    "#FF6B9D", "#C2185B", "#A0845C", "#8E8E93",
];

// ============================================================
// 헬퍼
// ============================================================

fn generate_invite_code() -> String {
    let mut rng = rand::thread_rng();
    (0..INVITE_CODE_LEN)
        .map(|_| CHARSET[rng.gen_range(0..CHARSET.len())] as char)
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
async fn check_membership(
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
    let member = check_membership(pool, user_uid, group_id).await?;
    if member.role != "admin" {
        return Err(AppError::Forbidden(
            "호스트만 수행할 수 있습니다".to_string(),
        ));
    }
    Ok(member)
}

/// 그룹 멤버 수 조회
async fn get_member_count(pool: &PgPool, group_id: Uuid) -> Result<i64, AppError> {
    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
            .bind(group_id)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    Ok(count.0)
}

/// GroupResponse 조립 헬퍼
async fn build_group_response(
    pool: &PgPool,
    group_id: Uuid,
    user_uid: &str,
) -> Result<GroupResponse, AppError> {
    // 그룹 존재 확인
    let group = sqlx::query_as::<_, Group>("SELECT * FROM groups WHERE id = $1")
        .bind(group_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("그룹을 찾을 수 없습니다".to_string()))?;

    // 요청자의 멤버십 조회
    let member = check_membership(pool, user_uid, group_id).await?;

    // admin(호스트) user_id 조회
    let admin_uid: (String,) = sqlx::query_as(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND role = 'admin'::group_member_role",
    )
    .bind(group_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 멤버 수
    let member_count = get_member_count(pool, group_id).await?;

    Ok(GroupResponse {
        group_id: group.id.to_string(),
        name: group.name,
        description: group.description,
        image_url: group.image_url,
        max_members: group.max_members,
        invite_code: group.invite_code,
        created_by: admin_uid.0,
        member_count,
        role: member.role,
        group_color: member.group_color,
        notification_settings: NotificationSettingsResponse {
            enabled: member.notifications_enabled,
            schedule: ScheduleNotificationSettingsResponse {
                invitation: member.schedule_invitation,
                reminder: member.schedule_reminder,
                confirmed: member.schedule_confirmed,
                cancelled: member.schedule_cancelled,
                updated: member.schedule_updated,
                attendance_response: member.attendance_response,
            },
            group: GroupNotificationSettingsResponse {
                update: member.group_update,
            },
            calendar_sync: member.calendar_sync,
        },
        last_read_at: member.last_read_at,
        created_at: group.created_at,
        updated_at: group.updated_at,
    })
}

// ============================================================
// 서비스 함수
// ============================================================

/// 그룹 생성 -- 생성자가 admin으로 등록되고 초대 코드 발급
pub async fn create_group(
    pool: &PgPool,
    creator_uid: &str,
    req: CreateGroupRequest,
) -> Result<CreateGroupResponse, AppError> {
    // 검증
    let name = validate_group_name(&req.name)?;
    let description = validate_description(&req.description)?;
    let max_members = validate_max_members(req.max_members)?;

    // 초대 코드 생성 (충돌 시 재시도)
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
        .fetch_one(pool)
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

    let group = group_row.ok_or_else(|| {
        AppError::Internal("초대 코드 생성에 실패했습니다".to_string())
    })?;

    // 생성자를 admin으로 등록
    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) \
         VALUES ($1, $2, 'admin'::group_member_role)",
    )
    .bind(group.id)
    .bind(creator_uid)
    .execute(pool)
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

    let group = sqlx::query_as::<_, Group>(
        "SELECT * FROM groups WHERE invite_code = $1",
    )
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

/// 초대 코드로 그룹 가입 -- 가입 시 알림 전체 ON + 캘린더 동기화 ON
pub async fn join_group(
    pool: &PgPool,
    user_uid: &str,
    invite_code: &str,
) -> Result<GroupResponse, AppError> {
    let normalized = invite_code.trim().to_uppercase();

    // 그룹 조회
    let group = sqlx::query_as::<_, Group>(
        "SELECT * FROM groups WHERE invite_code = $1",
    )
    .bind(&normalized)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?
    .ok_or_else(|| AppError::NotFound("그룹을 찾을 수 없습니다".to_string()))?;

    // 이미 멤버인지 확인
    let existing = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group.id)
    .bind(user_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if existing.is_some() {
        return Err(AppError::Conflict("이미 그룹에 가입되어 있습니다".to_string()));
    }

    // 정원 확인
    let member_count = get_member_count(pool, group.id).await?;
    if member_count >= group.max_members as i64 {
        return Err(AppError::BadRequest("그룹 정원이 가득 찼습니다".to_string()));
    }

    // 멤버 추가 (기본값: role='member', 알림 전체 ON, 캘린더 동기화 ON)
    sqlx::query(
        "INSERT INTO group_members (group_id, user_id, role) \
         VALUES ($1, $2, 'member'::group_member_role)",
    )
    .bind(group.id)
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 가입 후 GroupResponse 반환
    build_group_response(pool, group.id, user_uid).await
}

/// 그룹 탈퇴 -- 호스트는 탈퇴 불가
pub async fn leave_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<(), AppError> {
    let member = check_membership(pool, user_uid, group_id).await?;

    if member.role == "admin" {
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

/// 그룹 정보 수정 -- 호스트만 가능, 이름 변경 불가
pub async fn update_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: UpdateGroupRequest,
) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    // 검증: description
    if let Some(ref desc) = req.description {
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

    // description은 항상 Some/None 모두 유효 (None이면 해제)
    if req.description.is_some() {
        set_clauses.push(format!("description = ${}", param_index));
        param_index += 1;
    }
    if req.max_members.is_some() {
        set_clauses.push(format!("max_members = ${}", param_index));
        param_index += 1;
    }
    if req.image_url.is_some() {
        set_clauses.push(format!("image_url = ${}", param_index));
        param_index += 1;
    }

    if set_clauses.is_empty() {
        // 변경할 것이 없으면 바로 성공
        return Ok(());
    }

    set_clauses.push(format!("updated_at = NOW()"));

    let sql = format!(
        "UPDATE groups SET {} WHERE id = ${}",
        set_clauses.join(", "),
        param_index
    );

    let mut query = sqlx::query(&sql);

    if let Some(ref desc) = req.description {
        let trimmed = desc.trim();
        if trimmed.is_empty() {
            query = query.bind(None::<String>);
        } else {
            query = query.bind(Some(trimmed.to_string()));
        }
    }
    if let Some(max) = req.max_members {
        query = query.bind(max);
    }
    if let Some(ref url) = req.image_url {
        query = query.bind(url.clone());
    }

    query = query.bind(group_id);

    query
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 그룹 삭제 -- 호스트만 가능, cascade 처리
pub async fn delete_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    sqlx::query("DELETE FROM groups WHERE id = $1")
        .bind(group_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 호스트 양도 -- 기존 호스트 -> member, 신규 호스트 -> admin
pub async fn transfer_host(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: TransferHostRequest,
) -> Result<(), AppError> {
    check_admin(pool, user_uid, group_id).await?;

    // 자기 자신에게 양도 불가
    if req.new_host_uid == user_uid {
        return Err(AppError::BadRequest(
            "자기 자신에게 호스트를 양도할 수 없습니다".to_string(),
        ));
    }

    // 대상이 그룹 멤버인지 확인
    let target = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.new_host_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if target.is_none() {
        return Err(AppError::BadRequest(
            "양도 대상이 그룹 멤버가 아닙니다".to_string(),
        ));
    }

    // 트랜잭션: 기존 admin -> member, 신규 호스트 -> admin
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

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

    // 신규 호스트 -> admin
    sqlx::query(
        "UPDATE group_members SET role = 'admin'::group_member_role \
         WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.new_host_uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

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

    // 대상이 그룹 멤버인지 확인
    let target = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(&req.target_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if target.is_none() {
        return Err(AppError::BadRequest(
            "추방 대상이 그룹 멤버가 아닙니다".to_string(),
        ));
    }

    sqlx::query("DELETE FROM group_members WHERE group_id = $1 AND user_id = $2")
        .bind(group_id)
        .bind(&req.target_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 내 그룹 목록 조회 -- joinedAt 내림차순, JOIN/aggregation 단일 쿼리
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
    )>(
        "SELECT g.id, g.name, g.description, g.image_url, g.max_members, \
                gm.role::TEXT as role, gm.group_color, g.last_activity_at, gm.last_read_at, gm.joined_at \
         FROM group_members gm \
         JOIN groups g ON gm.group_id = g.id \
         WHERE gm.user_id = $1 \
         ORDER BY gm.joined_at DESC",
    )
    .bind(user_uid)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let mut result = Vec::with_capacity(rows.len());

    for (id, name, description, image_url, max_members, role, group_color, last_activity_at, last_read_at, joined_at) in rows {
        let member_count = get_member_count(pool, id).await?;
        let has_new_activity = last_activity_at > last_read_at;

        result.push(GroupSummaryResponse {
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
        });
    }

    Ok(result)
}

/// 그룹 상세 조회 -- 멤버만 접근 가능
pub async fn fetch_group(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<GroupResponse, AppError> {
    // 그룹 존재 확인 -- 그룹이 없으면 NotFound
    let group_exists = sqlx::query_as::<_, (Uuid,)>(
        "SELECT id FROM groups WHERE id = $1",
    )
    .bind(group_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if group_exists.is_none() {
        return Err(AppError::NotFound("그룹을 찾을 수 없습니다".to_string()));
    }

    build_group_response(pool, group_id, user_uid).await
}

/// 그룹 멤버 목록 조회 -- 멤버만 접근 가능
pub async fn fetch_group_members(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<Vec<GroupMemberResponse>, AppError> {
    check_membership(pool, user_uid, group_id).await?;

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
        .map(|(user_id, nickname, profile_url, role, group_color, joined_at)| {
            GroupMemberResponse {
                user_id,
                nickname,
                profile_url,
                role,
                group_color,
                joined_at,
            }
        })
        .collect())
}

/// 그룹 읽음 마커 갱신 -- last_read_at 업데이트
pub async fn mark_group_read(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
) -> Result<(), AppError> {
    check_membership(pool, user_uid, group_id).await?;

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
    check_membership(pool, user_uid, group_id).await?;

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

/// 그룹 색상 업데이트
pub async fn update_group_color(
    pool: &PgPool,
    user_uid: &str,
    group_id: Uuid,
    req: UpdateGroupColorRequest,
) -> Result<(), AppError> {
    check_membership(pool, user_uid, group_id).await?;

    // 팔레트 검증
    if !GROUP_COLOR_PALETTE.contains(&req.color.as_str()) {
        return Err(AppError::BadRequest(
            "허용되지 않은 색상입니다".to_string(),
        ));
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
