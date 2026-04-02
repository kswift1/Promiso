use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::user::*;

/// 사용자 생성
pub async fn create_user(
    pool: &PgPool,
    uid: &str,
    req: CreateUserRequest,
) -> Result<CreateUserResponse, AppError> {
    todo!()
}

/// 본인 프로필 조회 (private)
pub async fn get_my_profile(
    pool: &PgPool,
    uid: &str,
) -> Result<UserPrivateResponse, AppError> {
    todo!()
}

/// 타인 프로필 조회 (public, 공통 그룹 체크)
pub async fn get_user_public(
    pool: &PgPool,
    requester_uid: &str,
    target_uid: &str,
) -> Result<UserPublicResponse, AppError> {
    todo!()
}

/// 사용자 정보 수정 (닉네임)
pub async fn update_user(
    pool: &PgPool,
    uid: &str,
    req: UpdateUserRequest,
) -> Result<(), AppError> {
    todo!()
}

/// 프로필 이미지 업로드 (경로 저장)
pub async fn upload_profile_image(
    pool: &PgPool,
    uid: &str,
    req: UploadProfileImageRequest,
) -> Result<String, AppError> {
    todo!()
}

/// 닉네임 중복 확인
pub async fn check_nickname_available(
    pool: &PgPool,
    uid: &str,
    nickname: &str,
) -> Result<NicknameCheckResponse, AppError> {
    todo!()
}

/// 여러 사용자 조회 (public)
pub async fn batch_get_users(
    pool: &PgPool,
    user_ids: &[String],
) -> Result<Vec<UserPublicResponse>, AppError> {
    todo!()
}

// 닉네임 유효성 검증 헬퍼
pub fn validate_nickname(nickname: &str) -> Result<String, AppError> {
    todo!()
}
