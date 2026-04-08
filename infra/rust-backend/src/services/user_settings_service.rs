use chrono::Utc;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::services::briefing_projection_service;

// ============================================================
// 허용 enum 목록
// ============================================================

const VALID_GROUP_SORT_TYPES: &[&str] = &[
    "joinedRecent",
    "joinedOldest",
    "nameAscending",
    "nameDescending",
    "custom",
];

const VALID_BRIEFING_STYLES: &[&str] =
    &["friendly", "humorous", "concise", "motivational", "calm"];

// ============================================================
// 응답 DTO
// ============================================================

/// 설정 응답 DTO
#[derive(Debug, Clone, serde::Serialize)]
pub struct UserSettingsResponse {
    pub notification_enabled: bool,
    pub group_sort_type: String,
    pub group_sort_order: Option<Vec<String>>,
    pub conflict_threshold_min: i16,
    pub briefing: BriefingSettingsResponse,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct BriefingSettingsResponse {
    pub style: Option<String>,
    pub notification_hour: Option<i16>,
    pub timezone: Option<String>,
    pub language: Option<String>,
    pub available_transports: Vec<String>,
    pub default_location: Option<DefaultLocationResponse>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct DefaultLocationResponse {
    pub name: String,
    pub address: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

// ============================================================
// 요청 DTO
// ============================================================

/// 설정 수정 요청 DTO
#[derive(Debug, Clone, serde::Deserialize)]
pub struct UpdateSettingsRequest {
    pub group_sort_type: Option<String>,
    pub group_sort_order: Option<Option<Vec<String>>>,
    pub conflict_threshold_min: Option<i16>,
    pub briefing_style: Option<String>,
    pub briefing_notification_hour: Option<Option<i16>>,
    pub briefing_timezone: Option<String>,
    pub briefing_language: Option<String>,
    pub briefing_available_transports: Option<Vec<String>>,
    pub briefing_default_location: Option<Option<UpdateLocationRequest>>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct UpdateLocationRequest {
    pub name: String,
    pub address: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

// ============================================================
// DB row 매핑용 내부 타입
// ============================================================

#[derive(Debug, sqlx::FromRow)]
struct UserSettingsRow {
    group_sort_type: String,
    group_sort_order: Option<Vec<String>>,
    conflict_threshold_min: i16,
    briefing_style: Option<String>,
    briefing_notification_hour: Option<i16>,
    briefing_timezone: Option<String>,
    briefing_language: Option<String>,
    briefing_available_transports: Vec<String>,
    briefing_default_location_title: Option<String>,
    briefing_default_location_latitude: Option<f64>,
    briefing_default_location_longitude: Option<f64>,
    // briefing_location_address는 별칭으로 매핑
    briefing_location_address: Option<String>,
}

// ============================================================
// 내부 헬퍼
// ============================================================

fn row_to_response(row: UserSettingsRow, notification_enabled: bool) -> UserSettingsResponse {
    let default_location = row
        .briefing_default_location_title
        .map(|name| DefaultLocationResponse {
            name,
            address: row.briefing_location_address,
            latitude: row.briefing_default_location_latitude,
            longitude: row.briefing_default_location_longitude,
        });

    UserSettingsResponse {
        notification_enabled,
        group_sort_type: row.group_sort_type,
        group_sort_order: row.group_sort_order,
        conflict_threshold_min: row.conflict_threshold_min,
        briefing: BriefingSettingsResponse {
            style: row.briefing_style,
            notification_hour: row.briefing_notification_hour,
            timezone: row.briefing_timezone,
            language: row.briefing_language,
            available_transports: row.briefing_available_transports,
            default_location,
        },
    }
}

fn default_response(notification_enabled: bool) -> UserSettingsResponse {
    UserSettingsResponse {
        notification_enabled,
        group_sort_type: "joinedRecent".to_string(),
        group_sort_order: None,
        conflict_threshold_min: 0,
        briefing: BriefingSettingsResponse {
            style: None,
            notification_hour: None,
            timezone: None,
            language: None,
            available_transports: vec!["transit".to_string(), "car".to_string()],
            default_location: None,
        },
    }
}

// ============================================================
// 서비스 함수
// ============================================================

/// 설정 전체 조회
pub async fn get_settings(pool: &PgPool, user_id: &str) -> Result<UserSettingsResponse, AppError> {
    let notification_enabled: bool = sqlx::query_as(
        "SELECT notification_enabled FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .map(|(enabled,)| enabled)
    .unwrap_or(true);

    let row = sqlx::query_as::<_, UserSettingsRow>(
        "SELECT group_sort_type, group_sort_order, conflict_threshold_min,
                briefing_style, briefing_notification_hour,
                briefing_timezone, briefing_language,
                briefing_available_transports,
                briefing_default_location_title,
                briefing_default_location_latitude,
                briefing_default_location_longitude,
                briefing_location_address
         FROM user_settings
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    match row {
        Some(r) => Ok(row_to_response(r, notification_enabled)),
        None => Ok(default_response(notification_enabled)),
    }
}

/// 설정 부분 수정 + briefing projection 재계산
pub async fn update_settings(
    pool: &PgPool,
    user_id: &str,
    req: UpdateSettingsRequest,
) -> Result<UserSettingsResponse, AppError> {
    // ---- 유효성 검증 ----
    if let Some(ref sort_type) = req.group_sort_type {
        if !VALID_GROUP_SORT_TYPES.contains(&sort_type.as_str()) {
            return Err(AppError::BadRequest(format!(
                "Invalid group_sort_type: {}",
                sort_type
            )));
        }
    }

    if let Some(threshold) = req.conflict_threshold_min {
        if threshold < 0 {
            return Err(AppError::BadRequest(
                "conflict_threshold_min must be non-negative".to_string(),
            ));
        }
    }

    if let Some(ref style) = req.briefing_style {
        if !VALID_BRIEFING_STYLES.contains(&style.as_str()) {
            return Err(AppError::BadRequest(format!(
                "Invalid briefing_style: {}",
                style
            )));
        }
    }

    if let Some(ref transports) = req.briefing_available_transports {
        if transports.is_empty() {
            return Err(AppError::BadRequest(
                "briefing_available_transports must not be empty".to_string(),
            ));
        }
    }

    if let Some(Some(ref loc)) = req.briefing_default_location {
        if loc.name.is_empty() {
            return Err(AppError::BadRequest(
                "briefing_default_location.name must not be empty".to_string(),
            ));
        }
    }

    // ---- US-7/8: hour가 Some(None)이면 tz, language도 함께 NULL ----
    let clear_hour_tz_lang = matches!(req.briefing_notification_hour, Some(None));

    // ---- UPSERT (partial update) ----
    // 트랜잭션으로 감싸 SELECT → UPSERT → reconcile을 원자적으로 처리
    let mut tx = pool.begin().await?;

    // 먼저 현재 row를 읽어 기본값을 구성한 뒤 덮어쓰기
    let current = sqlx::query_as::<_, UserSettingsRow>(
        "SELECT group_sort_type, group_sort_order, conflict_threshold_min,
                briefing_style, briefing_notification_hour,
                briefing_timezone, briefing_language,
                briefing_available_transports,
                briefing_default_location_title,
                briefing_default_location_latitude,
                briefing_default_location_longitude,
                briefing_location_address
         FROM user_settings
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await?;

    // 기존 값 or 기본값
    let notification_enabled: bool = sqlx::query_as(
        "SELECT notification_enabled FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .map(|(enabled,)| enabled)
    .unwrap_or(true);

    let base = current
        .map(|row| row_to_response(row, notification_enabled))
        .unwrap_or_else(|| default_response(notification_enabled));

    // ---- 각 필드 결정 ----
    let new_group_sort_type = req
        .group_sort_type
        .unwrap_or(base.group_sort_type.clone());

    // group_sort_order: Option<Option<Vec<String>>>
    // None = 변경 안함, Some(None) = NULL로, Some(Some(v)) = 값으로
    let new_group_sort_order: Option<Vec<String>> = match req.group_sort_order {
        None => base.group_sort_order.clone(),
        Some(None) => None,
        Some(Some(v)) => Some(v),
    };

    let new_conflict_threshold = req
        .conflict_threshold_min
        .unwrap_or(base.conflict_threshold_min);

    let new_briefing_style: Option<String> = match req.briefing_style {
        None => base.briefing.style.clone(),
        Some(v) => Some(v),
    };

    // notification_hour / timezone / language 처리
    let (new_hour, new_timezone, new_language): (Option<i16>, Option<String>, Option<String>) =
        if clear_hour_tz_lang {
            (None, None, None)
        } else {
            let hour = match req.briefing_notification_hour {
                None => base.briefing.notification_hour,
                Some(None) => None, // 이 분기는 clear_hour_tz_lang=true 처리로 이미 처리됨
                Some(Some(v)) => Some(v),
            };
            let tz = match req.briefing_timezone {
                None => base.briefing.timezone.clone(),
                Some(v) => Some(v),
            };
            let lang = match req.briefing_language {
                None => base.briefing.language.clone(),
                Some(v) => Some(v),
            };
            (hour, tz, lang)
        };

    let new_transports = req
        .briefing_available_transports
        .unwrap_or(base.briefing.available_transports.clone());

    // default_location: Option<Option<UpdateLocationRequest>>
    // None = 변경 안함, Some(None) = NULL로, Some(Some(loc)) = 값으로
    let (new_loc_title, new_loc_address, new_loc_lat, new_loc_lng): (
        Option<String>,
        Option<String>,
        Option<f64>,
        Option<f64>,
    ) = match req.briefing_default_location {
        None => {
            // 변경 안함 — 기존 값 유지
            if let Some(ref loc) = base.briefing.default_location {
                (
                    Some(loc.name.clone()),
                    loc.address.clone(),
                    loc.latitude,
                    loc.longitude,
                )
            } else {
                (None, None, None, None)
            }
        }
        Some(None) => (None, None, None, None),
        Some(Some(loc)) => (Some(loc.name), loc.address, loc.latitude, loc.longitude),
    };

    // ---- UPSERT 실행 ----
    sqlx::query(
        "INSERT INTO user_settings
             (user_id, group_sort_type, group_sort_order, conflict_threshold_min,
              briefing_style, briefing_notification_hour, briefing_timezone, briefing_language,
              briefing_available_transports,
              briefing_default_location_title, briefing_default_location_latitude,
              briefing_default_location_longitude, briefing_location_address,
              updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW())
         ON CONFLICT (user_id) DO UPDATE SET
             group_sort_type                  = EXCLUDED.group_sort_type,
             group_sort_order                 = EXCLUDED.group_sort_order,
             conflict_threshold_min           = EXCLUDED.conflict_threshold_min,
             briefing_style                   = EXCLUDED.briefing_style,
             briefing_notification_hour       = EXCLUDED.briefing_notification_hour,
             briefing_timezone                = EXCLUDED.briefing_timezone,
             briefing_language                = EXCLUDED.briefing_language,
             briefing_available_transports    = EXCLUDED.briefing_available_transports,
             briefing_default_location_title  = EXCLUDED.briefing_default_location_title,
             briefing_default_location_latitude  = EXCLUDED.briefing_default_location_latitude,
             briefing_default_location_longitude = EXCLUDED.briefing_default_location_longitude,
             briefing_location_address        = EXCLUDED.briefing_location_address,
             updated_at                       = EXCLUDED.updated_at",
    )
    .bind(user_id)
    .bind(&new_group_sort_type)
    .bind(&new_group_sort_order)
    .bind(new_conflict_threshold)
    .bind(&new_briefing_style)
    .bind(new_hour)
    .bind(&new_timezone)
    .bind(&new_language)
    .bind(&new_transports)
    .bind(&new_loc_title)
    .bind(new_loc_lat)
    .bind(new_loc_lng)
    .bind(&new_loc_address)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // ---- US-12: projection 재계산 ----
    briefing_projection_service::reconcile_projection(pool, user_id, Utc::now()).await?;

    // ---- 업데이트된 설정 반환 ----
    get_settings(pool, user_id).await
}

/// Pro 기본값 일괄 세팅
pub async fn initialize_pro_defaults(
    pool: &PgPool,
    user_id: &str,
    timezone: &str,
) -> Result<UserSettingsResponse, AppError> {
    let mut tx = pool.begin().await?;

    sqlx::query(
        "INSERT INTO user_settings
             (user_id, briefing_notification_hour, briefing_style,
              briefing_timezone, briefing_language,
              conflict_threshold_min, briefing_available_transports,
              updated_at)
         VALUES ($1, 8, 'friendly', $2, 'ko', 0, '{transit,car}', NOW())
         ON CONFLICT (user_id) DO UPDATE SET
             briefing_notification_hour    = 8,
             briefing_style                = 'friendly',
             briefing_timezone             = EXCLUDED.briefing_timezone,
             briefing_language             = 'ko',
             conflict_threshold_min        = 0,
             briefing_available_transports = '{transit,car}',
             updated_at                    = NOW()",
    )
    .bind(user_id)
    .bind(timezone)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // ---- US-12: projection 재계산 ----
    briefing_projection_service::reconcile_projection(pool, user_id, Utc::now()).await?;

    get_settings(pool, user_id).await
}
