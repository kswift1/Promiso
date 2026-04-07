//! Users 도메인 비즈니스 규칙 테스트 (Red Phase)
//!
//! 단위 테스트: validate_nickname (DB 불필요)
//! 통합 테스트: create/get/update/check 등 (DB 필요)

use promiso_backend::errors::AppError;
use promiso_backend::models::user::*;
use promiso_backend::services::user_service;
use sqlx::PgPool;

// ============================================================
// 테스트 헬퍼
// ============================================================

fn make_create_request(nickname: &str) -> CreateUserRequest {
    CreateUserRequest {
        name: None,
        nickname: nickname.to_string(),
        provider: ProviderInfo {
            provider_type: "google".to_string(),
            provider_uid: "test-provider-uid".to_string(),
            email: "test@example.com".to_string(),
        },
    }
}

fn make_create_request_with_name(name: &str, nickname: &str) -> CreateUserRequest {
    CreateUserRequest {
        name: Some(name.to_string()),
        nickname: nickname.to_string(),
        provider: ProviderInfo {
            provider_type: "google".to_string(),
            provider_uid: "test-provider-uid".to_string(),
            email: "test@example.com".to_string(),
        },
    }
}

async fn insert_test_user(pool: &PgPool, id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', 'test-uid', 'test@test.com')",
    )
    .bind(id)
    .bind(nickname)
    .bind(nickname)
    .execute(pool)
    .await
    .expect("Failed to insert test user");
}

// ============================================================
// 단위 테스트: 닉네임 유효성 검증
// ============================================================

#[test]
fn u1_nickname_min_length_valid() {
    let result = user_service::validate_nickname("AB");
    assert!(result.is_ok());
}

#[test]
fn u1_nickname_min_length_rejected() {
    let result = user_service::validate_nickname("A");
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn u1_nickname_empty_rejected() {
    let result = user_service::validate_nickname("");
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn u2_nickname_max_12_valid() {
    let result = user_service::validate_nickname("가나다라마바사아자차카타"); // 12자
    assert!(result.is_ok());
}

#[test]
fn u2_nickname_max_12_rejected() {
    let result = user_service::validate_nickname("가나다라마바사아자차카타마"); // 13자
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn u3_nickname_middle_space_rejected() {
    let result = user_service::validate_nickname("hello world");
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn u3_nickname_tab_rejected() {
    let result = user_service::validate_nickname("hello\tworld");
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn u4_nickname_trimmed() {
    let result = user_service::validate_nickname("  hello  ");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "hello");
}

#[test]
fn nickname_valid_korean() {
    let result = user_service::validate_nickname("홍길동");
    assert!(result.is_ok());
}

#[test]
fn nickname_valid_english() {
    let result = user_service::validate_nickname("swift");
    assert!(result.is_ok());
}

#[test]
fn nickname_valid_mixed() {
    let result = user_service::validate_nickname("김swift");
    assert!(result.is_ok());
}

// ============================================================
// 통합 테스트: 유저 생성
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn create_user_success(pool: PgPool) {
    let req = make_create_request("테스트유저");
    let result = user_service::create_user(&pool, "test_create_1", req).await;

    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.user_id, "test_create_1");
}

#[sqlx::test(migrations = "./migrations")]
async fn u10_create_user_name_fallback_to_nickname(pool: PgPool) {
    // name 미제공 → nickname으로 대체되어야 함
    let req = make_create_request("폴백닉넴");
    let _ = user_service::create_user(&pool, "test_u10", req).await;

    let profile = user_service::get_my_profile(&pool, "test_u10").await;
    assert!(profile.is_ok());
    assert_eq!(profile.unwrap().name, "폴백닉넴");
}

#[sqlx::test(migrations = "./migrations")]
async fn u10_create_user_name_provided(pool: PgPool) {
    let req = make_create_request_with_name("김성원", "성원닉넴");
    let _ = user_service::create_user(&pool, "test_u10_name", req).await;

    let profile = user_service::get_my_profile(&pool, "test_u10_name").await;
    assert!(profile.is_ok());
    assert_eq!(profile.unwrap().name, "김성원");
}

#[sqlx::test(migrations = "./migrations")]
async fn u13_create_user_duplicate_rejected(pool: PgPool) {
    // 첫 번째 생성
    let req1 = make_create_request("중복테스트");
    let _ = user_service::create_user(&pool, "test_dup", req1).await;

    // 같은 uid로 재생성 시도
    let req2 = make_create_request("중복테스트2");
    let result = user_service::create_user(&pool, "test_dup", req2).await;

    assert!(matches!(result, Err(AppError::Conflict(_))));
}

// ============================================================
// 통합 테스트: 닉네임 중복 (U5)
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn u5_nickname_unique_rejected(pool: PgPool) {
    // 유저1 생성
    let req1 = make_create_request("유니크닉");
    let _ = user_service::create_user(&pool, "test_uniq1", req1).await;

    // 유저2가 같은 닉네임으로 생성 시도
    let req2 = make_create_request("유니크닉");
    let result = user_service::create_user(&pool, "test_uniq2", req2).await;

    assert!(result.is_err()); // Conflict 또는 BadRequest
}

#[sqlx::test(migrations = "./migrations")]
async fn u5_nickname_check_self_allowed(pool: PgPool) {
    // 유저 생성
    let req = make_create_request("셀프닉넴");
    let _ = user_service::create_user(&pool, "test_self_nick", req).await;

    // 본인 닉네임 체크 → 사용 가능
    let check = user_service::check_nickname_available(&pool, "test_self_nick", "셀프닉넴").await;
    assert!(check.is_ok());
    assert!(check.unwrap().available);
}

#[sqlx::test(migrations = "./migrations")]
async fn u5_nickname_check_taken_by_other(pool: PgPool) {
    // 유저1 생성
    let req = make_create_request("선점닉넴");
    let _ = user_service::create_user(&pool, "test_taken1", req).await;

    // 유저2가 같은 닉네임 체크 → 사용 불가
    let check = user_service::check_nickname_available(&pool, "test_taken2", "선점닉넴").await;
    assert!(check.is_ok());
    assert!(!check.unwrap().available);
}

// ============================================================
// 통합 테스트: 프로필 조회
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn get_my_profile_success(pool: PgPool) {
    let req = make_create_request("프로필조회");
    let _ = user_service::create_user(&pool, "test_profile", req).await;

    let result = user_service::get_my_profile(&pool, "test_profile").await;
    assert!(result.is_ok());
    let profile = result.unwrap();
    assert_eq!(profile.user_id, "test_profile");
    assert_eq!(profile.nickname, "프로필조회");
    assert_eq!(profile.email, "test@example.com");
    assert_eq!(profile.provider, "google");
}

#[sqlx::test(migrations = "./migrations")]
async fn get_my_profile_not_found(pool: PgPool) {
    let result = user_service::get_my_profile(&pool, "nonexistent_user").await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

// ============================================================
// 통합 테스트: 타인 조회 + 공통 그룹 체크 (U8)
// ============================================================
// 참고: groups 도메인 마이그레이션 전이라 group_members 테이블이 없음.
// 이 테스트는 현재 컴파일/실행은 되지만 groups 마이그레이션 후 의미가 완성됨.
// Red Phase에서는 todo!()로 실패하므로 문제 없음.

#[sqlx::test(migrations = "./migrations")]
async fn u8_get_other_user_no_common_group_rejected(pool: PgPool) {
    insert_test_user(&pool, "test_requester", "요청자").await;
    insert_test_user(&pool, "test_target", "대상자").await;

    // 공통 그룹 없이 타인 조회 → 거부
    let result = user_service::get_user_public(&pool, "test_requester", "test_target").await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// 통합 테스트: 유저 수정 (U6)
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn update_nickname_success(pool: PgPool) {
    let req = make_create_request("수정전닉");
    let _ = user_service::create_user(&pool, "test_update", req).await;

    let update_req = UpdateUserRequest {
        nickname: Some("수정후닉".to_string()),
    };
    let result = user_service::update_user(&pool, "test_update", update_req).await;
    assert!(result.is_ok());

    // 수정 확인
    let profile = user_service::get_my_profile(&pool, "test_update")
        .await
        .unwrap();
    assert_eq!(profile.nickname, "수정후닉");
}

#[test]
fn u6_name_email_immutable() {
    // name과 email은 updateUser에서 수정 불가
    // UpdateUserRequest에 name/email 필드 자체가 없으므로
    // 구조체 레벨에서 강제됨 — 컴파일타임 보장
    let req = UpdateUserRequest {
        nickname: Some("새닉네임".to_string()),
    };
    // name, email 필드가 없다는 것 자체가 U6 보장
    assert!(req.nickname.is_some());
}

// ============================================================
// 통합 테스트: 프로필 이미지 업로드
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn upload_profile_image_success(pool: PgPool) {
    let req = make_create_request("업로드테스트");
    let _ = user_service::create_user(&pool, "test_upload", req).await;

    let upload_req = UploadProfileImageRequest {
        image_path: "profile_images/test_upload/image.jpg".to_string(),
    };
    let result = user_service::upload_profile_image(&pool, "test_upload", upload_req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn upload_profile_image_empty_path_rejected(pool: PgPool) {
    let req = make_create_request("빈경로");
    let _ = user_service::create_user(&pool, "test_upload_empty", req).await;

    let upload_req = UploadProfileImageRequest {
        image_path: "".to_string(),
    };
    let result = user_service::upload_profile_image(&pool, "test_upload_empty", upload_req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 통합 테스트: batch 조회
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn batch_get_users_success(pool: PgPool) {
    insert_test_user(&pool, "test_batch_req", "배치요청자").await;
    insert_test_user(&pool, "test_batch1", "배치유저1").await;
    insert_test_user(&pool, "test_batch2", "배치유저2").await;

    // 공통 그룹 설정
    let group_id: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, last_activity_at) \
         VALUES ('batch_group', 'BATCH1', 10, NOW()) RETURNING id",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    for uid in &["test_batch_req", "test_batch1", "test_batch2"] {
        sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')")
            .bind(group_id.0)
            .bind(uid)
            .execute(&pool)
            .await
            .unwrap();
    }

    let ids = vec!["test_batch1".to_string(), "test_batch2".to_string()];
    let result = user_service::batch_get_users(&pool, "test_batch_req", &ids).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().len(), 2);
}

// ============================================================
// 통합 테스트: 공통 그룹 있을 때 타인 조회 (U8 성공 케이스)
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn u8_get_other_user_with_common_group_success(pool: PgPool) {
    insert_test_user(&pool, "test_req_grp", "그룹요청자").await;
    insert_test_user(&pool, "test_tgt_grp", "그룹대상자").await;

    // 공통 그룹 설정
    let group_id: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, last_activity_at) \
         VALUES ('u8_group', 'U8TEST', 10, NOW()) RETURNING id",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')")
        .bind(group_id.0)
        .bind("test_req_grp")
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')")
        .bind(group_id.0)
        .bind("test_tgt_grp")
        .execute(&pool)
        .await
        .unwrap();

    let result = user_service::get_user_public(&pool, "test_req_grp", "test_tgt_grp").await;
    assert!(result.is_ok());
    let user = result.unwrap();
    assert_eq!(user.nickname, "그룹대상자");
}

// ============================================================
// 단위 테스트: provider 빈 이메일 거부
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn provider_empty_email_rejected(pool: PgPool) {
    let req = CreateUserRequest {
        name: None,
        nickname: "프로바이더".to_string(),
        provider: ProviderInfo {
            provider_type: "google".to_string(),
            provider_uid: "uid-123".to_string(),
            email: "".to_string(), // 빈 이메일
        },
    };
    let result = user_service::create_user(&pool, "test_prov_empty", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 통합 테스트: notification_enabled 기본값 확인
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn notification_enabled_default_true(pool: PgPool) {
    let req = make_create_request("알림기본값");
    let _ = user_service::create_user(&pool, "test_notif", req).await;

    let profile = user_service::get_my_profile(&pool, "test_notif").await;
    assert!(profile.is_ok());
    assert!(profile.unwrap().notification_enabled);
}

// ============================================================
// HTTP 레벨 테스트: 인증 없이 보호 라우트 호출 → 401
// ============================================================
// users 라우트 구현 시 활성화. 현재 라우트 미존재로 404 반환되어 테스트 신호가 부정확.

#[sqlx::test(migrations = "./migrations")]
async fn auth_required_returns_401(pool: PgPool) {
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt; // oneshot

    let config = promiso_backend::config::Config::from_env();
    let apns_sender = std::sync::Arc::new(
        promiso_backend::services::apns_service::RealApnsSender::new(&config),
    );
    let app = promiso_backend::routes::create_router(pool, &config, apns_sender);

    // Authorization 헤더 없이 요청
    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/users/me")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================
// 통합 테스트: 타인 조회 404
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn get_other_user_not_found(pool: PgPool) {
    insert_test_user(&pool, "test_404_req", "요청자사").await;

    let result = user_service::get_user_public(&pool, "test_404_req", "nonexistent_user").await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}
