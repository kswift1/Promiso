//! User Settings 도메인 비즈니스 규칙 테스트 (Red Phase)
//!
//! 비즈니스 규칙 참조: US-1 ~ US-12
//! 모든 서비스 함수는 todo!() stub — 테스트는 현재 전부 실패(Red)

use promiso_backend::errors::AppError;
use promiso_backend::services::user_settings_service::{
    self, UpdateLocationRequest, UpdateSettingsRequest,
};
use sqlx::PgPool;

// ============================================================
// 테스트 헬퍼
// ============================================================

async fn insert_test_user(pool: &PgPool, id: &str) {
    let suffix = if id.len() > 8 {
        &id[id.len() - 8..]
    } else {
        id
    };

    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $2, 'google', 'test-uid', 'test@test.com')",
    )
    .bind(id)
    .bind(suffix)
    .execute(pool)
    .await
    .expect("Failed to insert test user");
}

async fn insert_test_settings(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO user_settings (user_id) VALUES ($1) \
         ON CONFLICT (user_id) DO NOTHING",
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("Failed to insert test user_settings");
}

fn empty_update() -> UpdateSettingsRequest {
    UpdateSettingsRequest {
        group_sort_type: None,
        group_sort_order: None,
        conflict_threshold_min: None,
        briefing_style: None,
        briefing_notification_hour: None,
        briefing_timezone: None,
        briefing_language: None,
        briefing_available_transports: None,
        briefing_default_location: None,
    }
}

// ============================================================
// GET 기본 동작
// ============================================================

/// row 없을 때 기본값 반환
#[sqlx::test(migrations = "./migrations")]
async fn get_settings_returns_defaults_when_no_row(pool: PgPool) {
    insert_test_user(&pool, "us_get_default").await;

    let result = user_settings_service::get_settings(&pool, "us_get_default").await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    assert_eq!(settings.group_sort_type, "joinedRecent");
    assert_eq!(settings.conflict_threshold_min, 0);
    assert!(settings.briefing.notification_hour.is_none());
    assert_eq!(
        settings.briefing.available_transports,
        vec!["transit", "car"]
    );
}

/// 저장된 값 반환
#[sqlx::test(migrations = "./migrations")]
async fn get_settings_returns_stored_values(pool: PgPool) {
    insert_test_user(&pool, "us_get_stored").await;
    sqlx::query(
        "INSERT INTO user_settings \
         (user_id, group_sort_type, conflict_threshold_min, briefing_style, \
          briefing_notification_hour, briefing_timezone, briefing_language) \
         VALUES ($1, 'nameAscending', 15, 'concise', 8, 'Asia/Seoul', 'ko')",
    )
    .bind("us_get_stored")
    .execute(&pool)
    .await
    .unwrap();

    let result = user_settings_service::get_settings(&pool, "us_get_stored").await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    assert_eq!(settings.group_sort_type, "nameAscending");
    assert_eq!(settings.conflict_threshold_min, 15);
    assert_eq!(settings.briefing.style.as_deref(), Some("concise"));
    assert_eq!(settings.briefing.notification_hour, Some(8));
    assert_eq!(settings.briefing.timezone.as_deref(), Some("Asia/Seoul"));
    assert_eq!(settings.briefing.language.as_deref(), Some("ko"));
}

// ============================================================
// PATCH 기본 동작
// ============================================================

/// 일부 필드만 수정 시 나머지 유지
#[sqlx::test(migrations = "./migrations")]
async fn update_settings_partial_update_preserves_other_fields(pool: PgPool) {
    insert_test_user(&pool, "us_partial").await;
    sqlx::query(
        "INSERT INTO user_settings \
         (user_id, conflict_threshold_min, briefing_style) \
         VALUES ($1, 30, 'humorous')",
    )
    .bind("us_partial")
    .execute(&pool)
    .await
    .unwrap();

    let req = UpdateSettingsRequest {
        group_sort_type: Some("nameDescending".to_string()),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_partial", req).await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    // 수정된 필드
    assert_eq!(settings.group_sort_type, "nameDescending");
    // 유지된 필드
    assert_eq!(settings.conflict_threshold_min, 30);
    assert_eq!(settings.briefing.style.as_deref(), Some("humorous"));
}

// ============================================================
// US-2, US-3: groupSortOption
// ============================================================

/// 잘못된 group_sort_type → 400
#[sqlx::test(migrations = "./migrations")]
async fn update_group_sort_type_validates_enum(pool: PgPool) {
    insert_test_user(&pool, "us_sort_enum").await;
    insert_test_settings(&pool, "us_sort_enum").await;

    let req = UpdateSettingsRequest {
        group_sort_type: Some("invalidSortType".to_string()),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_sort_enum", req).await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

/// custom sort인데 order 없으면 group_sort_order를 null로 저장 (동작 확인)
#[sqlx::test(migrations = "./migrations")]
async fn update_group_sort_custom_requires_order(pool: PgPool) {
    insert_test_user(&pool, "us_sort_custom").await;
    insert_test_settings(&pool, "us_sort_custom").await;

    let req = UpdateSettingsRequest {
        group_sort_type: Some("custom".to_string()),
        group_sort_order: Some(None), // order를 명시적으로 null로
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_sort_custom", req).await;

    // custom + null order → 저장은 성공하되 order는 None
    assert!(result.is_ok());
    let settings = result.unwrap();
    assert_eq!(settings.group_sort_type, "custom");
    assert!(settings.group_sort_order.is_none());
}

// ============================================================
// US-4: conflictDetectionThreshold
// ============================================================

/// 음수 threshold → 400
#[sqlx::test(migrations = "./migrations")]
async fn update_conflict_threshold_rejects_negative(pool: PgPool) {
    insert_test_user(&pool, "us_threshold_neg").await;
    insert_test_settings(&pool, "us_threshold_neg").await;

    let req = UpdateSettingsRequest {
        conflict_threshold_min: Some(-1),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_threshold_neg", req).await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// US-5: briefing style
// ============================================================

/// 잘못된 briefing_style → 400
#[sqlx::test(migrations = "./migrations")]
async fn update_briefing_style_validates_enum(pool: PgPool) {
    insert_test_user(&pool, "us_style_enum").await;
    insert_test_settings(&pool, "us_style_enum").await;

    let req = UpdateSettingsRequest {
        briefing_style: Some("invalid_style".to_string()),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_style_enum", req).await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// US-6, US-7, US-8: notificationHour + timezone + language 원자적
// ============================================================

/// hour 설정 시 tz, lang 함께 저장
#[sqlx::test(migrations = "./migrations")]
async fn update_notification_hour_sets_timezone_language(pool: PgPool) {
    insert_test_user(&pool, "us_hour_tz_lang").await;
    insert_test_settings(&pool, "us_hour_tz_lang").await;

    let req = UpdateSettingsRequest {
        briefing_notification_hour: Some(Some(9)),
        briefing_timezone: Some("America/New_York".to_string()),
        briefing_language: Some("en".to_string()),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_hour_tz_lang", req).await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    assert_eq!(settings.briefing.notification_hour, Some(9));
    assert_eq!(
        settings.briefing.timezone.as_deref(),
        Some("America/New_York")
    );
    assert_eq!(settings.briefing.language.as_deref(), Some("en"));
}

/// null 설정 시 3개 모두 NULL
#[sqlx::test(migrations = "./migrations")]
async fn update_notification_hour_null_clears_all_three(pool: PgPool) {
    insert_test_user(&pool, "us_hour_null").await;
    sqlx::query(
        "INSERT INTO user_settings \
         (user_id, briefing_notification_hour, briefing_timezone, briefing_language) \
         VALUES ($1, 8, 'Asia/Seoul', 'ko')",
    )
    .bind("us_hour_null")
    .execute(&pool)
    .await
    .unwrap();

    let req = UpdateSettingsRequest {
        briefing_notification_hour: Some(None), // null → 삭제
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_hour_null", req).await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    assert!(settings.briefing.notification_hour.is_none());
    assert!(settings.briefing.timezone.is_none());
    assert!(settings.briefing.language.is_none());
}

// ============================================================
// US-9: availableTransports
// ============================================================

/// 빈 배열 → 400
#[sqlx::test(migrations = "./migrations")]
async fn update_transports_rejects_empty_array(pool: PgPool) {
    insert_test_user(&pool, "us_transport_empty").await;
    insert_test_settings(&pool, "us_transport_empty").await;

    let req = UpdateSettingsRequest {
        briefing_available_transports: Some(vec![]),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_transport_empty", req).await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// US-10: defaultLocation
// ============================================================

/// null → 삭제
#[sqlx::test(migrations = "./migrations")]
async fn update_default_location_null_clears(pool: PgPool) {
    insert_test_user(&pool, "us_loc_null").await;
    sqlx::query(
        "INSERT INTO user_settings \
         (user_id, briefing_default_location_title, briefing_default_location_latitude, \
          briefing_default_location_longitude) \
         VALUES ($1, '집', 37.5665, 126.9780)",
    )
    .bind("us_loc_null")
    .execute(&pool)
    .await
    .unwrap();

    let req = UpdateSettingsRequest {
        briefing_default_location: Some(None), // null → 삭제
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_loc_null", req).await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    assert!(settings.briefing.default_location.is_none());
}

/// name 없으면 400
#[sqlx::test(migrations = "./migrations")]
async fn update_default_location_requires_name(pool: PgPool) {
    insert_test_user(&pool, "us_loc_noname").await;
    insert_test_settings(&pool, "us_loc_noname").await;

    let req = UpdateSettingsRequest {
        briefing_default_location: Some(Some(UpdateLocationRequest {
            name: "".to_string(), // 빈 name
            address: None,
            latitude: Some(37.5665),
            longitude: Some(126.9780),
        })),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_loc_noname", req).await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

// ============================================================
// US-11: initializePro
// ============================================================

/// Pro 기본값 일괄 세팅 확인
#[sqlx::test(migrations = "./migrations")]
async fn initialize_pro_sets_defaults(pool: PgPool) {
    insert_test_user(&pool, "us_init_pro").await;

    let result =
        user_settings_service::initialize_pro_defaults(&pool, "us_init_pro", "Asia/Seoul").await;

    assert!(result.is_ok());
    let settings = result.unwrap();
    // Pro 기본값: notification_hour 설정됨, style 설정됨
    assert!(settings.briefing.notification_hour.is_some());
    assert!(settings.briefing.style.is_some());
    assert_eq!(settings.briefing.timezone.as_deref(), Some("Asia/Seoul"));
}

// ============================================================
// US-12: projection 재계산
// ============================================================

/// settings 변경 후 briefing_subscriptions 갱신 확인
#[sqlx::test(migrations = "./migrations")]
async fn update_triggers_briefing_projection_reconcile(pool: PgPool) {
    insert_test_user(&pool, "us_proj_reconcile").await;
    // entitlement로 Pro 자격 부여
    sqlx::query(
        "INSERT INTO entitlements \
         (user_id, has_pro, source, subscription_status, override_active) \
         VALUES ($1, true, 'subscription', 'subscribed', false)",
    )
    .bind("us_proj_reconcile")
    .execute(&pool)
    .await
    .unwrap();

    let req = UpdateSettingsRequest {
        briefing_notification_hour: Some(Some(7)),
        briefing_timezone: Some("Asia/Seoul".to_string()),
        briefing_language: Some("ko".to_string()),
        briefing_style: Some("friendly".to_string()),
        ..empty_update()
    };
    let result = user_settings_service::update_settings(&pool, "us_proj_reconcile", req).await;

    assert!(result.is_ok());

    // briefing_subscriptions에 row가 생성(또는 갱신)되었는지 확인
    let row: Option<(i16,)> =
        sqlx::query_as("SELECT notification_hour FROM briefing_subscriptions WHERE user_id = $1")
            .bind("us_proj_reconcile")
            .fetch_optional(&pool)
            .await
            .unwrap();

    assert!(row.is_some());
    assert_eq!(row.unwrap().0, 7);
}
