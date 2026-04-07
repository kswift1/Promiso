//! Groups 도메인 비즈니스 규칙 테스트 (Red Phase)
//!
//! 모든 테스트는 컴파일은 되지만 실행 시 실패해야 한다.
//! service 함수들이 todo!("Red phase")를 반환하기 때문.

use promiso_backend::errors::AppError;
use promiso_backend::models::group::*;
use promiso_backend::services::group_service;
use sqlx::PgPool;
use uuid::Uuid;

// ============================================================
// 테스트 헬퍼
// ============================================================

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

async fn create_test_group(pool: &PgPool, creator_id: &str, name: &str) -> CreateGroupResponse {
    let req = CreateGroupRequest {
        name: name.to_string(),
        description: None,
        max_members: Some(10),
    };
    group_service::create_group(pool, creator_id, req)
        .await
        .expect("Failed to create test group")
}

async fn join_test_group(pool: &PgPool, user_id: &str, invite_code: &str) -> GroupResponse {
    group_service::join_group(pool, user_id, invite_code)
        .await
        .expect("Failed to join test group")
}

// ============================================================
// 제약 — 이름
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn c1_create_name_min_2_valid(pool: PgPool) {
    insert_test_user(&pool, "creator_c1a", "호스트1").await;
    let req = CreateGroupRequest {
        name: "AB".to_string(),
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c1a", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c1_create_name_min_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c1b", "호스트2").await;
    let req = CreateGroupRequest {
        name: "A".to_string(),
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c1b", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c1_create_name_empty_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c1c", "호스트3").await;
    let req = CreateGroupRequest {
        name: "".to_string(),
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c1c", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c2_create_name_max_12_valid(pool: PgPool) {
    insert_test_user(&pool, "creator_c2a", "호스트4").await;
    let req = CreateGroupRequest {
        name: "가나다라마바사아자차카타".to_string(), // 12자
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c2a", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c2_create_name_max_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c2b", "호스트5").await;
    let req = CreateGroupRequest {
        name: "가나다라마바사아자차카타마".to_string(), // 13자
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c2b", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c3_create_name_trimmed(pool: PgPool) {
    insert_test_user(&pool, "creator_c3", "호스트6").await;
    let req = CreateGroupRequest {
        name: "  우리팀  ".to_string(), // 앞뒤 공백 포함 — trim 후 4자
        description: None,
        max_members: None,
    };
    // trim 후 유효 범위이면 성공해야 함
    let result = group_service::create_group(&pool, "creator_c3", req).await;
    assert!(result.is_ok());
}

// ============================================================
// 제약 — 설명
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn c4_create_description_none_ok(pool: PgPool) {
    insert_test_user(&pool, "creator_c4a", "호스트7").await;
    let req = CreateGroupRequest {
        name: "설명없음그룹".to_string(),
        description: None,
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c4a", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c4_create_description_max_50_valid(pool: PgPool) {
    insert_test_user(&pool, "creator_c4b", "호스트8").await;
    let desc_50 = "가".repeat(50);
    let req = CreateGroupRequest {
        name: "설명50자".to_string(),
        description: Some(desc_50),
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c4b", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c4_create_description_max_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c4c", "호스트9").await;
    let desc_51 = "가".repeat(51);
    let req = CreateGroupRequest {
        name: "설명51자".to_string(),
        description: Some(desc_51),
        max_members: None,
    };
    let result = group_service::create_group(&pool, "creator_c4c", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c4_update_description_max_validated(pool: PgPool) {
    // 버그 수정 #1: update 시에도 description 50자 검증
    insert_test_user(&pool, "creator_c4d", "호스트10").await;
    let group = create_test_group(&pool, "creator_c4d", "수정테스트").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let desc_51 = "가".repeat(51);
    let req = UpdateGroupRequest {
        description: Some(Some(desc_51)),
        max_members: None,
        image_url: None,
    };
    let result = group_service::update_group(&pool, "creator_c4d", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 제약 — maxMembers
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn c5_create_max_members_min_2(pool: PgPool) {
    insert_test_user(&pool, "creator_c5a", "호스트11").await;
    let req = CreateGroupRequest {
        name: "최소인원".to_string(),
        description: None,
        max_members: Some(2),
    };
    let result = group_service::create_group(&pool, "creator_c5a", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c5_create_max_members_below_min_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c5b", "호스트12").await;
    let req = CreateGroupRequest {
        name: "최소미만".to_string(),
        description: None,
        max_members: Some(1),
    };
    let result = group_service::create_group(&pool, "creator_c5b", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c5_create_max_members_max_10(pool: PgPool) {
    insert_test_user(&pool, "creator_c5c", "호스트13").await;
    let req = CreateGroupRequest {
        name: "최대인원".to_string(),
        description: None,
        max_members: Some(10),
    };
    let result = group_service::create_group(&pool, "creator_c5c", req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c5_create_max_members_above_max_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_c5d", "호스트14").await;
    let req = CreateGroupRequest {
        name: "초과인원".to_string(),
        description: None,
        max_members: Some(11),
    };
    let result = group_service::create_group(&pool, "creator_c5d", req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c5_update_max_members_validated(pool: PgPool) {
    // 버그 수정 #2: update 시에도 maxMembers 범위 검증
    insert_test_user(&pool, "creator_c5e", "호스트15").await;
    let group = create_test_group(&pool, "creator_c5e", "인원수정").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupRequest {
        description: None,
        max_members: Some(11),
        image_url: None,
    };
    let result = group_service::update_group(&pool, "creator_c5e", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn c5_update_max_members_floor_is_current_member_count(pool: PgPool) {
    // maxMembers 하한 = max(2, 현재 멤버 수)
    insert_test_user(&pool, "creator_c5f", "호스트16").await;
    insert_test_user(&pool, "member_c5f1", "멤버1").await;
    insert_test_user(&pool, "member_c5f2", "멤버2").await;

    let group = create_test_group(&pool, "creator_c5f", "멤버3명그룹").await;
    join_test_group(&pool, "member_c5f1", &group.invite_code).await;
    join_test_group(&pool, "member_c5f2", &group.invite_code).await;
    // 현재 멤버 수 = 3 (호스트 포함)

    let group_id = Uuid::parse_str(&group.group_id).unwrap();
    let req = UpdateGroupRequest {
        description: None,
        max_members: Some(2), // 현재 멤버 수(3)보다 작으면 거부
        image_url: None,
    };
    let result = group_service::update_group(&pool, "creator_c5f", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[test]
fn c6_update_group_request_rejects_unknown_name_field() {
    // 이름 변경 불가 — unknown field는 DTO 역직렬화 단계에서 거부되어야 함
    let body = serde_json::json!({
        "name": "새이름",
        "description": "새 설명"
    });

    let result = serde_json::from_value::<UpdateGroupRequest>(body);
    assert!(result.is_err());
}

// ============================================================
// 제약 — 초대 코드
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn c7_invite_code_is_6_chars(pool: PgPool) {
    insert_test_user(&pool, "creator_c7", "호스트17").await;
    let group = create_test_group(&pool, "creator_c7", "코드테스트").await;
    assert_eq!(group.invite_code.len(), 6);
}

#[sqlx::test(migrations = "./migrations")]
async fn c7_invite_code_is_uppercase_alphanumeric(pool: PgPool) {
    insert_test_user(&pool, "creator_c7b", "호스트18").await;
    let group = create_test_group(&pool, "creator_c7b", "코드형식").await;
    assert!(group
        .invite_code
        .chars()
        .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit()));
}

#[sqlx::test(migrations = "./migrations")]
async fn c8_join_accepts_lowercase_invite_code(pool: PgPool) {
    // 소문자 초대 코드 → 대문자로 정규화 후 가입 성공
    insert_test_user(&pool, "creator_c8", "호스트c8").await;
    insert_test_user(&pool, "member_c8", "멤버c8").await;

    let group = create_test_group(&pool, "creator_c8", "소문자코드").await;
    let lowercase_code = group.invite_code.to_lowercase();

    let result = group_service::join_group(&pool, "member_c8", &lowercase_code).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn c8_preview_accepts_lowercase_invite_code(pool: PgPool) {
    // 소문자 초대 코드 → 대문자로 정규화 후 미리보기 성공
    insert_test_user(&pool, "creator_c8p", "호스트c8p").await;

    let group = create_test_group(&pool, "creator_c8p", "소문자미리보기").await;
    let lowercase_code = group.invite_code.to_lowercase();

    let result = group_service::preview_group(&pool, &lowercase_code).await;
    assert!(result.is_ok());
}

// ============================================================
// 권한 — 수정/삭제
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p1_update_by_non_host_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p1", "호스트19").await;
    insert_test_user(&pool, "member_p1", "멤버19").await;

    let group = create_test_group(&pool, "creator_p1", "권한테스트").await;
    join_test_group(&pool, "member_p1", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupRequest {
        description: Some(Some("불법수정".to_string())),
        max_members: None,
        image_url: None,
    };
    let result = group_service::update_group(&pool, "member_p1", group_id, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p2_delete_by_non_host_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p2", "호스트20").await;
    insert_test_user(&pool, "member_p2", "멤버20").await;

    let group = create_test_group(&pool, "creator_p2", "삭제권한테스트").await;
    join_test_group(&pool, "member_p2", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::delete_group(&pool, "member_p2", group_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// 권한 — 호스트 양도
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p3_transfer_by_non_host_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p3", "호스트21").await;
    insert_test_user(&pool, "member_p3a", "멤버21a").await;
    insert_test_user(&pool, "member_p3b", "멤버21b").await;

    let group = create_test_group(&pool, "creator_p3", "양도권한").await;
    join_test_group(&pool, "member_p3a", &group.invite_code).await;
    join_test_group(&pool, "member_p3b", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "member_p3b".to_string(),
    };
    let result = group_service::transfer_host(&pool, "member_p3a", group_id, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p3_single_member_group_transfer_request_rejected(pool: PgPool) {
    // 현재 API shape상 G12(다른 멤버 존재)와 G14(대상 멤버)를 완전히 분리하기 어렵다.
    // 최소한 "혼자 있는 그룹에서는 양도 요청이 거부된다"는 동작은 고정한다.
    insert_test_user(&pool, "creator_p3s", "호스트solo").await;
    insert_test_user(&pool, "phantom_p3s", "허상대상").await;

    let group = create_test_group(&pool, "creator_p3s", "혼자양도").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "phantom_p3s".to_string(), // 그룹 비멤버
    };
    let result = group_service::transfer_host(&pool, "creator_p3s", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p4_transfer_to_self_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p4", "호스트22").await;
    insert_test_user(&pool, "member_p4", "멤버22").await;

    let group = create_test_group(&pool, "creator_p4", "자기양도").await;
    join_test_group(&pool, "member_p4", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "creator_p4".to_string(), // 자기 자신
    };
    let result = group_service::transfer_host(&pool, "creator_p4", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p5_transfer_to_non_member_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p5", "호스트23").await;
    insert_test_user(&pool, "outsider_p5", "외부인").await;

    let group = create_test_group(&pool, "creator_p5", "비멤버양도").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "outsider_p5".to_string(), // 그룹 비멤버
    };
    let result = group_service::transfer_host(&pool, "creator_p5", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 권한 — 탈퇴
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p6_host_leave_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p6", "호스트24").await;

    let group = create_test_group(&pool, "creator_p6", "호스트탈퇴불가").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::leave_group(&pool, "creator_p6", group_id).await;
    assert!(matches!(result, Err(AppError::PreconditionFailed(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p7_non_member_leave_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p7", "호스트25").await;
    insert_test_user(&pool, "outsider_p7", "외부인2").await;

    let group = create_test_group(&pool, "creator_p7", "비멤버탈퇴").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::leave_group(&pool, "outsider_p7", group_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// 권한 — 가입
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p8_join_already_member_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p8", "호스트26").await;

    let group = create_test_group(&pool, "creator_p8", "중복가입").await;

    // 이미 멤버인 호스트가 재가입 시도
    let result = group_service::join_group(&pool, "creator_p8", &group.invite_code).await;
    assert!(matches!(result, Err(AppError::Conflict(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p9_join_full_group_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p9", "호스트27").await;
    insert_test_user(&pool, "member_p9a", "멤버27a").await;

    // max_members = 2인 그룹 생성 (호스트 포함 총 2명)
    let req = CreateGroupRequest {
        name: "꽉찬그룹".to_string(),
        description: None,
        max_members: Some(2),
    };
    let group = group_service::create_group(&pool, "creator_p9", req)
        .await
        .expect("create failed");
    join_test_group(&pool, "member_p9a", &group.invite_code).await;

    // 세 번째 유저가 가입 시도 → 정원 초과
    insert_test_user(&pool, "member_p9b", "멤버27b").await;
    let result = group_service::join_group(&pool, "member_p9b", &group.invite_code).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 권한 — 조회
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p10_non_member_fetch_group_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p10", "호스트28").await;
    insert_test_user(&pool, "outsider_p10", "외부인3").await;

    let group = create_test_group(&pool, "creator_p10", "비공개그룹").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::fetch_group(&pool, "outsider_p10", group_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// 권한 — 추방
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn p11_expel_by_non_host_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p11", "호스트29").await;
    insert_test_user(&pool, "member_p11a", "멤버29a").await;
    insert_test_user(&pool, "member_p11b", "멤버29b").await;

    let group = create_test_group(&pool, "creator_p11", "추방권한").await;
    join_test_group(&pool, "member_p11a", &group.invite_code).await;
    join_test_group(&pool, "member_p11b", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = ExpelMemberRequest {
        target_uid: "member_p11b".to_string(),
    };
    let result = group_service::expel_member(&pool, "member_p11a", group_id, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p12_expel_self_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p12", "호스트30").await;
    insert_test_user(&pool, "member_p12", "멤버30").await;

    let group = create_test_group(&pool, "creator_p12", "자기추방").await;
    join_test_group(&pool, "member_p12", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = ExpelMemberRequest {
        target_uid: "creator_p12".to_string(), // 호스트가 자기 자신 추방
    };
    let result = group_service::expel_member(&pool, "creator_p12", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn p13_expel_non_member_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_p13", "호스트31").await;
    insert_test_user(&pool, "outsider_p13", "외부인4").await;

    let group = create_test_group(&pool, "creator_p13", "비멤버추방").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = ExpelMemberRequest {
        target_uid: "outsider_p13".to_string(),
    };
    let result = group_service::expel_member(&pool, "creator_p13", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// CRUD — 생성 성공
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s1_create_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s1", "호스트32").await;
    let req = CreateGroupRequest {
        name: "성공그룹".to_string(),
        description: Some("설명입니다".to_string()),
        max_members: Some(5),
    };
    let result = group_service::create_group(&pool, "creator_s1", req).await;
    assert!(result.is_ok());

    let response = result.unwrap();
    assert!(!response.group_id.is_empty());
    assert_eq!(response.invite_code.len(), 6);
}

#[sqlx::test(migrations = "./migrations")]
async fn s2_create_creator_becomes_admin(pool: PgPool) {
    insert_test_user(&pool, "creator_s2", "호스트33").await;
    let group = create_test_group(&pool, "creator_s2", "역할확인").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::fetch_group(&pool, "creator_s2", group_id).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().role, "admin");
}

#[sqlx::test(migrations = "./migrations")]
async fn s3_create_invite_code_generated(pool: PgPool) {
    insert_test_user(&pool, "creator_s3", "호스트34").await;
    let group = create_test_group(&pool, "creator_s3", "코드생성").await;
    // 초대 코드는 6자리 A-Z0-9
    assert_eq!(group.invite_code.len(), 6);
    assert!(group
        .invite_code
        .chars()
        .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit()));
}

// ============================================================
// CRUD — 가입 성공
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s4_join_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s4", "호스트35").await;
    insert_test_user(&pool, "joiner_s4", "가입자1").await;

    let group = create_test_group(&pool, "creator_s4", "가입성공").await;
    let result = group_service::join_group(&pool, "joiner_s4", &group.invite_code).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn s5_join_role_is_member(pool: PgPool) {
    insert_test_user(&pool, "creator_s5", "호스트36").await;
    insert_test_user(&pool, "joiner_s5", "가입자2").await;

    let group = create_test_group(&pool, "creator_s5", "역할검증").await;
    let response = group_service::join_group(&pool, "joiner_s5", &group.invite_code)
        .await
        .unwrap();
    assert_eq!(response.role, "member");
}

#[sqlx::test(migrations = "./migrations")]
async fn s6_join_default_notifications_on(pool: PgPool) {
    insert_test_user(&pool, "creator_s6", "호스트37").await;
    insert_test_user(&pool, "joiner_s6", "가입자3").await;

    let group = create_test_group(&pool, "creator_s6", "알림기본값").await;
    let response = group_service::join_group(&pool, "joiner_s6", &group.invite_code)
        .await
        .unwrap();

    let ns = &response.notification_settings;
    assert!(ns.enabled);
    assert!(ns.schedule.invitation);
    assert!(ns.schedule.reminder);
    assert!(ns.schedule.confirmed);
    assert!(ns.schedule.cancelled);
    assert!(ns.schedule.updated);
    assert!(ns.schedule.attendance_response);
    assert!(ns.group.update);
    assert!(ns.calendar_sync);
}

#[sqlx::test(migrations = "./migrations")]
async fn s6_join_default_group_color_is_purple_hex(pool: PgPool) {
    insert_test_user(&pool, "creator_s6c", "호스트37c").await;
    insert_test_user(&pool, "joiner_s6c", "가입자3c").await;

    let group = create_test_group(&pool, "creator_s6c", "색상기본값").await;
    let response = group_service::join_group(&pool, "joiner_s6c", &group.invite_code)
        .await
        .unwrap();

    assert_eq!(response.group_color, "#AF52DE");
}

// ============================================================
// CRUD — 탈퇴 성공
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s7_leave_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s7", "호스트38").await;
    insert_test_user(&pool, "member_s7", "멤버38").await;

    let group = create_test_group(&pool, "creator_s7", "탈퇴성공").await;
    join_test_group(&pool, "member_s7", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::leave_group(&pool, "member_s7", group_id).await;
    assert!(result.is_ok());

    // 탈퇴 후 멤버 목록에서 제거됨
    let members = group_service::fetch_group_members(&pool, "creator_s7", group_id)
        .await
        .unwrap();
    assert!(!members.iter().any(|m| m.user_id == "member_s7"));
}

// ============================================================
// CRUD — 수정 성공
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s8_update_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s8", "호스트39").await;
    let group = create_test_group(&pool, "creator_s8", "수정전그룹").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupRequest {
        description: Some(Some("새 설명".to_string())),
        max_members: Some(7),
        image_url: None,
    };
    let result = group_service::update_group(&pool, "creator_s8", group_id, req).await;
    assert!(result.is_ok());

    // 수정 확인
    let updated = group_service::fetch_group(&pool, "creator_s8", group_id)
        .await
        .unwrap();
    assert_eq!(updated.description.as_deref(), Some("새 설명"));
    assert_eq!(updated.max_members, 7);
}

#[sqlx::test(migrations = "./migrations")]
async fn s9_update_partial_only_changed_fields(pool: PgPool) {
    insert_test_user(&pool, "creator_s9", "호스트40").await;
    let group = create_test_group(&pool, "creator_s9", "부분수정").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    // description만 수정, max_members는 None (변경 안 함)
    let req = UpdateGroupRequest {
        description: Some(Some("설명만 바꿈".to_string())),
        max_members: None,
        image_url: None,
    };
    let result = group_service::update_group(&pool, "creator_s9", group_id, req).await;
    assert!(result.is_ok());

    let updated = group_service::fetch_group(&pool, "creator_s9", group_id)
        .await
        .unwrap();
    assert_eq!(updated.description.as_deref(), Some("설명만 바꿈"));
    assert_eq!(updated.max_members, 10); // 기존값 유지
}

// ============================================================
// CRUD — 삭제 성공 + cascade
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s10_delete_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s10", "호스트41").await;
    insert_test_user(&pool, "member_s10", "멤버41").await;

    let group = create_test_group(&pool, "creator_s10", "삭제그룹").await;
    join_test_group(&pool, "member_s10", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::delete_group(&pool, "creator_s10", group_id).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn s10_delete_cascades_members(pool: PgPool) {
    insert_test_user(&pool, "creator_s10b", "호스트42").await;
    insert_test_user(&pool, "member_s10b", "멤버42").await;

    let group = create_test_group(&pool, "creator_s10b", "캐스케이드").await;
    join_test_group(&pool, "member_s10b", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    group_service::delete_group(&pool, "creator_s10b", group_id)
        .await
        .unwrap();

    // 삭제 후 그룹 조회 → NotFound
    let result = group_service::fetch_group(&pool, "creator_s10b", group_id).await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

// ============================================================
// CRUD — 호스트 양도
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s11_transfer_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s11", "호스트43").await;
    insert_test_user(&pool, "new_host_s11", "새호스트").await;

    let group = create_test_group(&pool, "creator_s11", "양도그룹").await;
    join_test_group(&pool, "new_host_s11", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "new_host_s11".to_string(),
    };
    let result = group_service::transfer_host(&pool, "creator_s11", group_id, req).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn s11_transfer_old_host_becomes_member(pool: PgPool) {
    insert_test_user(&pool, "creator_s11b", "호스트44").await;
    insert_test_user(&pool, "new_host_s11b", "새호스트2").await;

    let group = create_test_group(&pool, "creator_s11b", "양도후역할").await;
    join_test_group(&pool, "new_host_s11b", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = TransferHostRequest {
        new_host_uid: "new_host_s11b".to_string(),
    };
    group_service::transfer_host(&pool, "creator_s11b", group_id, req)
        .await
        .unwrap();

    let members = group_service::fetch_group_members(&pool, "new_host_s11b", group_id)
        .await
        .unwrap();

    let old_host = members.iter().find(|m| m.user_id == "creator_s11b");
    let new_host = members.iter().find(|m| m.user_id == "new_host_s11b");
    assert!(old_host.is_some());
    assert_eq!(old_host.unwrap().role, "member");
    assert!(new_host.is_some());
    assert_eq!(new_host.unwrap().role, "admin");
}

// ============================================================
// CRUD — 추방 성공
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn s12_expel_success(pool: PgPool) {
    insert_test_user(&pool, "creator_s12", "호스트45").await;
    insert_test_user(&pool, "target_s12", "추방대상").await;

    let group = create_test_group(&pool, "creator_s12", "추방성공").await;
    join_test_group(&pool, "target_s12", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = ExpelMemberRequest {
        target_uid: "target_s12".to_string(),
    };
    let result = group_service::expel_member(&pool, "creator_s12", group_id, req).await;
    assert!(result.is_ok());

    // 추방 후 멤버 목록에서 제거됨
    let members = group_service::fetch_group_members(&pool, "creator_s12", group_id)
        .await
        .unwrap();
    assert!(!members.iter().any(|m| m.user_id == "target_s12"));
}

// ============================================================
// 쿼리
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn q1_fetch_my_groups_orders_by_joined_at_desc(pool: PgPool) {
    // joined_at 내림차순 — 나중에 가입한 그룹이 먼저 나와야 함
    insert_test_user(&pool, "user_q1", "유저1").await;
    insert_test_user(&pool, "creator_q1a", "호스트q1a").await;
    insert_test_user(&pool, "creator_q1b", "호스트q1b").await;
    insert_test_user(&pool, "creator_q1c", "호스트q1c").await;

    let group_a = create_test_group(&pool, "creator_q1a", "첫번째그룹").await;
    let group_b = create_test_group(&pool, "creator_q1b", "두번째그룹").await;
    let group_c = create_test_group(&pool, "creator_q1c", "세번째그룹").await;

    // 순서대로 가입: A → B → C
    join_test_group(&pool, "user_q1", &group_a.invite_code).await;
    join_test_group(&pool, "user_q1", &group_b.invite_code).await;
    join_test_group(&pool, "user_q1", &group_c.invite_code).await;

    let result = group_service::fetch_my_groups(&pool, "user_q1").await;
    assert!(result.is_ok());
    let groups = result.unwrap();
    assert_eq!(groups.len(), 3);
    // 내림차순: C(마지막 가입) → B → A(첫 가입)
    assert_eq!(groups[0].group_id, group_c.group_id);
    assert_eq!(groups[1].group_id, group_b.group_id);
    assert_eq!(groups[2].group_id, group_a.group_id);
}

#[sqlx::test(migrations = "./migrations")]
async fn q2_fetch_my_groups_empty_returns_empty_list(pool: PgPool) {
    insert_test_user(&pool, "user_q2", "유저2").await;

    let result = group_service::fetch_my_groups(&pool, "user_q2").await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[sqlx::test(migrations = "./migrations")]
async fn q3_fetch_group_returns_member_count(pool: PgPool) {
    insert_test_user(&pool, "creator_q3", "호스트q3").await;
    insert_test_user(&pool, "member_q3a", "멤버q3a").await;
    insert_test_user(&pool, "member_q3b", "멤버q3b").await;

    let group = create_test_group(&pool, "creator_q3", "멤버수확인").await;
    join_test_group(&pool, "member_q3a", &group.invite_code).await;
    join_test_group(&pool, "member_q3b", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::fetch_group(&pool, "creator_q3", group_id).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().member_count, 3); // 호스트 + 2명
}

#[sqlx::test(migrations = "./migrations")]
async fn q4_fetch_group_members_returns_list(pool: PgPool) {
    insert_test_user(&pool, "creator_q4", "호스트q4").await;
    insert_test_user(&pool, "member_q4", "멤버q4").await;

    let group = create_test_group(&pool, "creator_q4", "멤버목록").await;
    join_test_group(&pool, "member_q4", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::fetch_group_members(&pool, "creator_q4", group_id).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().len(), 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn q5_preview_group_no_auth_needed(pool: PgPool) {
    insert_test_user(&pool, "creator_q5", "호스트q5").await;
    let group = create_test_group(&pool, "creator_q5", "미리보기").await;

    // 인증 없이 (user_uid 없이) 초대 코드만으로 미리보기
    let result = group_service::preview_group(&pool, &group.invite_code).await;
    assert!(result.is_ok());
}

#[sqlx::test(migrations = "./migrations")]
async fn q6_preview_group_max_10_members(pool: PgPool) {
    insert_test_user(&pool, "creator_q6", "호스트q6").await;
    let group = create_test_group(&pool, "creator_q6", "미리보기10명").await;

    // 9명 추가 가입
    for i in 0..9 {
        let uid = format!("member_q6_{}", i);
        let nick = format!("멤버q6_{}", i);
        insert_test_user(&pool, &uid, &nick).await;
        join_test_group(&pool, &uid, &group.invite_code).await;
    }
    // 총 10명 (호스트 + 9)

    let result = group_service::preview_group(&pool, &group.invite_code).await;
    assert!(result.is_ok());
    let preview = result.unwrap();
    assert!(preview.preview_members.len() <= 10);
}

#[sqlx::test(migrations = "./migrations")]
async fn q7_preview_invalid_code_rejected(pool: PgPool) {
    let result = group_service::preview_group(&pool, "XXXXXX").await;
    assert!(matches!(result, Err(AppError::NotFound(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn q8_get_groups_batch_preserves_order_and_filters_non_members(pool: PgPool) {
    insert_test_user(&pool, "batch_host", "배치호스트").await;
    insert_test_user(&pool, "batch_member", "배치멤버").await;
    insert_test_user(&pool, "batch_outsider", "배치외부인").await;

    let first_group = create_test_group(&pool, "batch_host", "첫번째그룹").await;
    let second_group = create_test_group(&pool, "batch_host", "두번째그룹").await;
    let outsider_group = create_test_group(&pool, "batch_outsider", "외부그룹").await;

    let first_group_id = Uuid::parse_str(&first_group.group_id).unwrap();
    let second_group_id = Uuid::parse_str(&second_group.group_id).unwrap();
    let outsider_group_id = Uuid::parse_str(&outsider_group.group_id).unwrap();

    join_test_group(&pool, "batch_member", &first_group.invite_code).await;
    join_test_group(&pool, "batch_member", &second_group.invite_code).await;

    let result = group_service::get_groups_batch(
        &pool,
        "batch_member",
        vec![second_group_id, outsider_group_id, first_group_id],
    )
    .await
    .expect("batch fetch should succeed");

    assert_eq!(result.len(), 2);
    assert_eq!(result[0].group_id, second_group.group_id);
    assert_eq!(result[1].group_id, first_group.group_id);
}

// ============================================================
// 멤버십 설정 — 알림
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn n1_update_notification_settings_success_and_persists(pool: PgPool) {
    insert_test_user(&pool, "creator_n1", "호스트n1").await;
    insert_test_user(&pool, "member_n1", "멤버n1").await;

    let group = create_test_group(&pool, "creator_n1", "알림설정").await;
    join_test_group(&pool, "member_n1", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let settings = NotificationSettingsRequest {
        enabled: false,
        schedule: ScheduleNotificationSettings {
            invitation: false,
            reminder: true,
            confirmed: false,
            cancelled: true,
            updated: false,
            attendance_response: true,
        },
        group: GroupNotificationSettings { update: false },
        calendar_sync: true,
    };
    let result =
        group_service::update_notification_settings(&pool, "member_n1", group_id, settings).await;
    assert!(result.is_ok());

    // 변경이 실제로 반영됐는지 확인
    let my_group = group_service::fetch_group(&pool, "member_n1", group_id)
        .await
        .unwrap();
    let ns = &my_group.notification_settings;
    assert!(!ns.enabled);
    assert!(!ns.schedule.invitation);
    assert!(ns.schedule.reminder);
    assert!(!ns.group.update);
}

#[sqlx::test(migrations = "./migrations")]
async fn n2_update_notification_settings_non_member_forbidden(pool: PgPool) {
    insert_test_user(&pool, "creator_n2", "호스트n2").await;
    insert_test_user(&pool, "outsider_n2", "외부인n2").await;

    let group = create_test_group(&pool, "creator_n2", "알림권한").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let settings = NotificationSettingsRequest {
        enabled: false,
        schedule: ScheduleNotificationSettings {
            invitation: false,
            reminder: false,
            confirmed: false,
            cancelled: false,
            updated: false,
            attendance_response: false,
        },
        group: GroupNotificationSettings { update: false },
        calendar_sync: false,
    };
    let result =
        group_service::update_notification_settings(&pool, "outsider_n2", group_id, settings).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// 멤버십 설정 — 그룹 색상
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn d1_update_group_color_success_and_persists(pool: PgPool) {
    insert_test_user(&pool, "creator_d1", "호스트d1").await;
    insert_test_user(&pool, "member_d1", "멤버d1").await;

    let group = create_test_group(&pool, "creator_d1", "색상변경").await;
    join_test_group(&pool, "member_d1", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupColorRequest {
        color: "#FF3B30".to_string(),
    };
    let result = group_service::update_group_color(&pool, "member_d1", group_id, req).await;
    assert!(result.is_ok());

    // 변경이 실제로 반영됐는지 확인
    let my_group = group_service::fetch_group(&pool, "member_d1", group_id)
        .await
        .unwrap();
    assert_eq!(my_group.group_color, "#FF3B30");
}

#[sqlx::test(migrations = "./migrations")]
async fn d2_update_group_color_non_member_forbidden(pool: PgPool) {
    insert_test_user(&pool, "creator_d2", "호스트d2").await;
    insert_test_user(&pool, "outsider_d2", "외부인d2").await;

    let group = create_test_group(&pool, "creator_d2", "색상권한").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupColorRequest {
        color: "#007AFF".to_string(),
    };
    let result = group_service::update_group_color(&pool, "outsider_d2", group_id, req).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn d3_update_group_color_outside_palette_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_d3", "호스트d3").await;
    insert_test_user(&pool, "member_d3", "멤버d3").await;

    let group = create_test_group(&pool, "creator_d3", "색상팔레트").await;
    join_test_group(&pool, "member_d3", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let req = UpdateGroupColorRequest {
        color: "#123456".to_string(),
    };
    let result = group_service::update_group_color(&pool, "member_d3", group_id, req).await;
    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// 배지 / 읽음 마커
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn b1_mark_group_read_updates_last_read_at(pool: PgPool) {
    insert_test_user(&pool, "creator_b1", "호스트b1").await;
    insert_test_user(&pool, "member_b1", "멤버b1").await;

    let group = create_test_group(&pool, "creator_b1", "읽음마커").await;
    join_test_group(&pool, "member_b1", &group.invite_code).await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::mark_group_read(&pool, "member_b1", group_id).await;
    assert!(result.is_ok());

    // last_read_at이 갱신됨 확인
    let groups = group_service::fetch_my_groups(&pool, "member_b1")
        .await
        .unwrap();
    let my_group = groups
        .iter()
        .find(|g| g.group_id == group.group_id)
        .unwrap();
    // 읽음 마커 갱신 후 has_new_activity = false 여야 함
    assert!(!my_group.has_new_activity);
}

// b2: promise 스키마 추가 후 "promise created after last_read_at => has_new_activity = true" 테스트 추가 예정

#[sqlx::test(migrations = "./migrations")]
async fn b3_mark_group_read_by_non_member_rejected(pool: PgPool) {
    insert_test_user(&pool, "creator_b3", "호스트b3").await;
    insert_test_user(&pool, "outsider_b3", "외부인b3").await;

    let group = create_test_group(&pool, "creator_b3", "읽음권한").await;
    let group_id = Uuid::parse_str(&group.group_id).unwrap();

    let result = group_service::mark_group_read(&pool, "outsider_b3", group_id).await;
    assert!(matches!(result, Err(AppError::Forbidden(_))));
}

// ============================================================
// HTTP 레벨 테스트: 인증 없이 보호 라우트 호출 → 401
// ============================================================

#[sqlx::test(migrations = "./migrations")]
async fn auth_required_groups_returns_401(pool: PgPool) {
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt; // oneshot

    let config = promiso_backend::config::Config::from_env();
    let apns_sender =
        std::sync::Arc::new(promiso_backend::services::apns_service::RealApnsSender::new(&config));
    let app = promiso_backend::routes::create_router(pool, &config, apns_sender);

    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/api/v1/groups/me")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
