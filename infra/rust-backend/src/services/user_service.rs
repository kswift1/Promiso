use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::user::*;
use crate::services::storage_service::GcsUploadSigner;

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

/// 사용자 생성 (U5, U10, U13, auth_accounts에서 provider 정보 조회)
pub async fn create_user(
    pool: &PgPool,
    uid: &str,
    req: CreateUserRequest,
) -> Result<CreateUserResponse, AppError> {
    // 닉네임 검증
    let nickname = validate_nickname(&req.nickname)?;

    // auth_accounts에서 서버가 검증한 provider 정보 조회
    let auth = sqlx::query_as::<_, (String, String, Option<String>)>(
        "SELECT provider_type, provider_uid, email FROM auth_accounts WHERE user_id = $1",
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?
    .ok_or_else(|| AppError::BadRequest("인증 정보를 찾을 수 없습니다".to_string()))?;

    let (provider_type, provider_uid, email_opt) = auth;
    let email = email_opt.unwrap_or_default();

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
    .bind(&provider_type)
    .bind(&provider_uid)
    .bind(&email)
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
pub async fn get_user_public(
    pool: &PgPool,
    requester_uid: &str,
    target_uid: &str,
) -> Result<UserPublicResponse, AppError> {
    // 대상 사용자 존재 확인
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(target_uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("사용자를 찾을 수 없습니다".to_string()))?;

    // U8: 공통 그룹 체크 — 같은 그룹에 속한 사용자만 조회 가능
    let shares_group: (bool,) = sqlx::query_as(
        "SELECT EXISTS(\
           SELECT 1 FROM group_members gm1 \
           JOIN group_members gm2 ON gm1.group_id = gm2.group_id \
           WHERE gm1.user_id = $1 AND gm2.user_id = $2\
         )",
    )
    .bind(requester_uid)
    .bind(target_uid)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if !shares_group.0 {
        return Err(AppError::Forbidden(
            "같은 그룹에 속한 사용자만 조회할 수 있습니다".to_string(),
        ));
    }

    Ok(UserPublicResponse {
        user_id: user.id,
        name: user.name,
        nickname: user.nickname,
        profile_url: user.profile_url,
        created_at: user.created_at,
        updated_at: user.updated_at,
    })
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

/// 사용자 탈퇴 — U9: 그룹 호스트는 탈퇴 불가, Storage 프로필 이미지 삭제 (실패 무시)
pub async fn delete_user(
    pool: &PgPool,
    uid: &str,
    gcs_signer: Option<&GcsUploadSigner>,
) -> Result<(), AppError> {
    // 트랜잭션 전에 profile_url 조회 (GCS cleanup에 사용)
    let profile_url: Option<String> =
        sqlx::query_scalar("SELECT profile_url FROM users WHERE id = $1")
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
            .flatten();

    let mut tx = pool.begin().await?;

    let is_group_host: (bool,) = sqlx::query_as(
        "SELECT EXISTS( \
           SELECT 1 FROM group_members \
           WHERE user_id = $1 AND role = 'admin' \
         )",
    )
    .bind(uid)
    .fetch_one(tx.as_mut())
    .await?;

    if is_group_host.0 {
        return Err(AppError::PreconditionFailed(
            "그룹 호스트는 탈퇴할 수 없습니다".to_string(),
        ));
    }

    sqlx::query("DELETE FROM user_settings WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM briefing_subscriptions WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM entitlements WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM entitlement_overrides WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM admin_users WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM auth_accounts WHERE user_id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(uid)
        .execute(tx.as_mut())
        .await?;

    tx.commit().await?;

    // 단계 5: Storage 프로필 이미지 삭제 (실패 무시, best-effort)
    let expected_prefix = format!("profile_images/{uid}/");
    if let (Some(signer), Some(url)) = (gcs_signer, profile_url) {
        // GCS public URL에서 object path 추출
        let object_path_opt = extract_gcs_object_path(signer.bucket(), &url)
            .filter(|p| p.starts_with(&expected_prefix));

        if let Some(object_path) = object_path_opt {
            if let Ok(target) = signer.sign_delete_object(&object_path) {
                let _ = reqwest::Client::new()
                    .delete(&target.delete_url)
                    .send()
                    .await;
            }
        }
    }

    Ok(())
}

/// GCS public URL에서 object path를 추출하는 헬퍼
/// "https://storage.googleapis.com/{bucket}/{object_path}" 형식을 파싱
fn extract_gcs_object_path(bucket: &str, url: &str) -> Option<String> {
    let prefix = format!("https://storage.googleapis.com/{bucket}/");
    url.strip_prefix(&prefix).map(|s| s.to_string())
}

/// 프로필 이미지 URL 저장
pub async fn upload_profile_image(
    pool: &PgPool,
    uid: &str,
    req: UploadProfileImageRequest,
    gcs_upload_bucket: Option<&str>,
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

    let url = match gcs_upload_bucket {
        Some(bucket) => format!("https://storage.googleapis.com/{bucket}/{path}"),
        None => path,
    };

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

pub fn issue_profile_image_upload_url(
    uid: &str,
    req: IssueProfileImageUploadUrlRequest,
    signer: &GcsUploadSigner,
) -> Result<IssueProfileImageUploadUrlResponse, AppError> {
    let content_type = req
        .content_type
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("image/jpeg");

    if content_type != "image/jpeg" {
        return Err(AppError::BadRequest(
            "프로필 이미지는 image/jpeg만 지원합니다".to_string(),
        ));
    }

    let object_path = format!("profile_images/{uid}/{}.jpg", Uuid::new_v4());
    let target = signer.sign_put_object(&object_path, content_type)?;

    Ok(IssueProfileImageUploadUrlResponse {
        object_path: target.object_path,
        upload_url: target.upload_url,
        profile_url: target.public_url,
        expires_at: target.expires_at,
        content_type: target.content_type,
    })
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

/// 여러 사용자 조회 (public, 공통 그룹 필터링)
pub async fn batch_get_users(
    pool: &PgPool,
    requester_uid: &str,
    user_ids: &[String],
) -> Result<Vec<UserPublicResponse>, AppError> {
    if user_ids.is_empty() {
        return Ok(vec![]);
    }

    // 요청자와 공통 그룹에 속한 사용자만 조회
    let users = sqlx::query_as::<_, User>(
        "SELECT DISTINCT u.* FROM users u \
         JOIN group_members gm1 ON gm1.user_id = u.id \
         JOIN group_members gm2 ON gm2.group_id = gm1.group_id \
         WHERE u.id = ANY($1) AND gm2.user_id = $2",
    )
    .bind(user_ids)
    .bind(requester_uid)
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
