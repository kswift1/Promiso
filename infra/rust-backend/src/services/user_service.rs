use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::user::*;

/// 닉네임 유효성 검증 (U1, U2, U3, U4)
pub fn validate_nickname(nickname: &str) -> Result<String, AppError> {
    let trimmed = nickname.trim();

    if trimmed.is_empty() || trimmed.chars().count() < 2 {
        return Err(AppError::BadRequest(
            "닉네임은 2자 이상이어야 합니다".to_string(),
        ));
    }

    if trimmed.chars().count() > 12 {
        return Err(AppError::BadRequest(
            "닉네임은 12자 이하여야 합니다".to_string(),
        ));
    }

    if trimmed.contains(char::is_whitespace) {
        return Err(AppError::BadRequest(
            "닉네임에 공백을 포함할 수 없습니다".to_string(),
        ));
    }

    Ok(trimmed.to_string())
}

/// 사용자 생성 (U5, U10, U13, provider 검증)
pub async fn create_user(
    pool: &PgPool,
    uid: &str,
    req: CreateUserRequest,
) -> Result<CreateUserResponse, AppError> {
    // 닉네임 검증
    let nickname = validate_nickname(&req.nickname)?;

    // provider 필수 필드 검증
    if req.provider.email.trim().is_empty() {
        return Err(AppError::BadRequest("이메일은 필수입니다".to_string()));
    }
    if req.provider.provider_type.trim().is_empty() {
        return Err(AppError::BadRequest(
            "인증 제공자 타입은 필수입니다".to_string(),
        ));
    }
    if req.provider.provider_uid.trim().is_empty() {
        return Err(AppError::BadRequest(
            "인증 제공자 UID는 필수입니다".to_string(),
        ));
    }

    // U10: name 미제공 시 nickname으로 대체
    let name = req
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(&nickname)
        .to_string();

    // INSERT (U13: 이미 존재하면 Conflict)
    let user = sqlx::query_as::<_, User>(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, $4, $5, $6) \
         RETURNING *",
    )
    .bind(uid)
    .bind(&name)
    .bind(&nickname)
    .bind(req.provider.provider_type.trim())
    .bind(req.provider.provider_uid.trim())
    .bind(req.provider.email.trim())
    .fetch_one(pool)
    .await
    .map_err(|e| map_unique_violation(e, "이미 존재하는 사용자입니다"))?;

    Ok(CreateUserResponse {
        user_id: user.id,
        created_at: user.created_at,
    })
}

/// 본인 프로필 조회 (private)
pub async fn get_my_profile(pool: &PgPool, uid: &str) -> Result<UserPrivateResponse, AppError> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("사용자를 찾을 수 없습니다".to_string()))?;

    Ok(UserPrivateResponse {
        user_id: user.id,
        name: user.name,
        nickname: user.nickname,
        email: user.email,
        provider: user.provider_type,
        profile_url: user.profile_url,
        notification_enabled: user.notification_enabled,
        created_at: user.created_at,
        updated_at: user.updated_at,
    })
}

/// 타인 프로필 조회 (public, 공통 그룹 체크)
/// groups 마이그레이션 전이므로 현재는 항상 Forbidden 반환 (공통 그룹 체크 불가)
pub async fn get_user_public(
    pool: &PgPool,
    requester_uid: &str,
    target_uid: &str,
) -> Result<UserPublicResponse, AppError> {
    // 대상 사용자 존재 확인
    let _user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(target_uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("사용자를 찾을 수 없습니다".to_string()))?;

    // U8: 공통 그룹 체크 — groups 마이그레이션 전이므로 항상 거부
    // TODO: groups 마이그레이션 후 group_members JOIN으로 교체
    // SELECT EXISTS(
    //   SELECT 1 FROM group_members gm1
    //   JOIN group_members gm2 ON gm1.group_id = gm2.group_id
    //   WHERE gm1.user_id = $1 AND gm2.user_id = $2
    // )
    let _ = requester_uid; // 컴파일러 경고 방지
    Err(AppError::Forbidden(
        "같은 그룹에 속한 사용자만 조회할 수 있습니다".to_string(),
    ))
}

/// 사용자 정보 수정 (닉네임) — U6: name/email은 UpdateUserRequest에 필드 자체가 없음
pub async fn update_user(pool: &PgPool, uid: &str, req: UpdateUserRequest) -> Result<(), AppError> {
    if let Some(ref nickname) = req.nickname {
        let validated = validate_nickname(nickname)?;

        let result =
            sqlx::query("UPDATE users SET nickname = $1, updated_at = NOW() WHERE id = $2")
                .bind(&validated)
                .bind(uid)
                .execute(pool)
                .await
                .map_err(|e| map_unique_violation(e, "닉네임 변경 실패"))?;

        if result.rows_affected() == 0 {
            return Err(AppError::NotFound("사용자를 찾을 수 없습니다".to_string()));
        }
    }

    Ok(())
}

/// 프로필 이미지 URL 저장
pub async fn upload_profile_image(
    pool: &PgPool,
    uid: &str,
    req: UploadProfileImageRequest,
) -> Result<String, AppError> {
    let path = req.image_path.trim().to_string();

    if path.is_empty() {
        return Err(AppError::BadRequest("이미지 경로는 필수입니다".to_string()));
    }

    // 보안: 사용자 소유 경로인지 검증 (임의 파일 참조 방지)
    let expected_prefix = format!("profile_images/{}/", uid);
    if !path.starts_with(&expected_prefix) {
        return Err(AppError::BadRequest(
            "이미지 경로가 올바르지 않습니다".to_string(),
        ));
    }

    // 실제 Storage URL 생성은 Firebase Storage에서 처리 (ADR-007)
    let url = path;

    let result = sqlx::query("UPDATE users SET profile_url = $1, updated_at = NOW() WHERE id = $2")
        .bind(&url)
        .bind(uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("사용자를 찾을 수 없습니다".to_string()));
    }

    Ok(url)
}

/// 닉네임 중복 확인 (U5: 본인 닉네임은 사용 가능)
pub async fn check_nickname_available(
    pool: &PgPool,
    uid: &str,
    nickname: &str,
) -> Result<NicknameCheckResponse, AppError> {
    let trimmed = validate_nickname(nickname)?;

    // 같은 닉네임을 가진 사용자 검색 (본인 제외)
    let existing =
        sqlx::query_scalar::<_, String>("SELECT id FROM users WHERE nickname = $1 LIMIT 1")
            .bind(&trimmed)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

    let available = match existing {
        None => true,                      // 아무도 안 씀
        Some(ref id) if id == uid => true, // 본인이 쓰고 있음
        Some(_) => false,                  // 다른 사람이 쓰고 있음
    };

    Ok(NicknameCheckResponse {
        available,
        nickname: trimmed,
    })
}

/// 여러 사용자 조회 (public)
/// TODO(U8): groups 마이그레이션 후 requester_uid를 받아 공통 그룹 체크 추가
/// 현재는 인증된 사용자 전체 허용 (전환 기간 임시)
pub async fn batch_get_users(
    pool: &PgPool,
    user_ids: &[String],
) -> Result<Vec<UserPublicResponse>, AppError> {
    if user_ids.is_empty() {
        return Ok(vec![]);
    }

    let users = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = ANY($1)")
        .bind(user_ids)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // 입력 순서 보존 (iOS가 순서를 기대할 수 있음)
    let user_map: std::collections::HashMap<&str, &User> =
        users.iter().map(|u| (u.id.as_str(), u)).collect();

    Ok(user_ids
        .iter()
        .filter_map(|id| user_map.get(id.as_str()))
        .map(|u| UserPublicResponse {
            user_id: u.id.clone(),
            name: u.name.clone(),
            nickname: u.nickname.clone(),
            profile_url: u.profile_url.clone(),
            created_at: u.created_at,
            updated_at: u.updated_at,
        })
        .collect())
}

/// PostgreSQL unique violation(23505)을 constraint name으로 분기하는 헬퍼
fn map_unique_violation(e: sqlx::Error, default_msg: &str) -> AppError {
    if let sqlx::Error::Database(ref db_err) = e {
        if db_err.code().as_deref() == Some("23505") {
            // constraint name으로 분기 (메시지 문자열 의존 제거)
            let constraint = db_err.constraint().unwrap_or("");
            if constraint == "uq_users_nickname" {
                return AppError::Conflict("이미 사용 중인 닉네임입니다".to_string());
            }
            return AppError::Conflict(default_msg.to_string());
        }
    }
    AppError::Internal(e.to_string())
}
