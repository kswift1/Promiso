use chrono::{DateTime, Duration, TimeZone, Utc};
use chrono_tz::Asia::Seoul;
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetTokenResponse {
    pub widget_token: String,
    pub expires_at: i64, // epoch seconds
}

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetSnapshotResponse {
    pub next: Option<WidgetScheduleItem>,
    pub today: Vec<WidgetScheduleItem>,
    pub upcoming: Vec<WidgetScheduleItem>,
}

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetScheduleItem {
    pub id: String,
    pub schedule_type: String,
    pub title: String,
    pub emoji: Option<String>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub location_name: Option<String>,
    pub group_name: Option<String>,
    pub is_confirmed: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct WidgetJwtClaims {
    sub: String,
    scope: String,
    device_id: String,
    version: i32,
    exp: usize,
    iat: usize,
}

/// Widget JWT 발급
///
/// DB에서 현재 widget_token_version을 조회하고,
/// HS256 JWT를 생성하여 반환한다.
/// exp = now + 30일
pub async fn generate_widget_token(
    pool: &PgPool,
    user_id: &str,
    device_id: &str,
    secret: &str,
) -> Result<WidgetTokenResponse, AppError> {
    let row: (i32,) = sqlx::query_as("SELECT widget_token_version FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to fetch widget_token_version: {e}")))?;

    let version = row.0;
    let now = Utc::now();
    let now_secs = now.timestamp() as usize;
    let thirty_days_secs = 30 * 24 * 60 * 60_usize;
    let exp = now_secs + thirty_days_secs;

    let claims = WidgetJwtClaims {
        sub: user_id.to_string(),
        scope: "widget:read".to_string(),
        device_id: device_id.to_string(),
        version,
        exp,
        iat: now_secs,
    };

    let token = encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(format!("Failed to encode widget JWT: {e}")))?;

    Ok(WidgetTokenResponse {
        widget_token: token,
        expires_at: exp as i64,
    })
}

/// Widget token 무효화 (version increment)
///
/// widget_token_version을 +1 증가시켜 기존 토큰을 모두 무효화한다.
pub async fn revoke_widget_tokens(pool: &PgPool, user_id: &str) -> Result<(), AppError> {
    sqlx::query("UPDATE users SET widget_token_version = widget_token_version + 1 WHERE id = $1")
        .bind(user_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to revoke widget tokens: {e}")))?;

    Ok(())
}

/// DB에서 조회한 원시 일정 행
#[derive(sqlx::FromRow)]
struct RawScheduleRow {
    id: Uuid,
    schedule_type: String,
    title: String,
    emoji: Option<String>,
    start_at: DateTime<Utc>,
    end_at: Option<DateTime<Utc>>,
    location_name: Option<String>,
    group_name: Option<String>,
    is_confirmed: Option<bool>,
}

/// Widget 스냅샷 조회
///
/// - 그룹일정: user가 member인 그룹의 확정(is_confirmed=true) 일정
/// - 개인일정: user_id 소유 일정
/// - 진행 중이거나 종료 후 1시간 이내 일정은 KST 기준 today로 유지
/// - 그 외 일정은 KST 기준으로 today/upcoming 분류
/// - today 최대 6개, upcoming 최대 9개 (start_at 오름차순)
/// - next = today[0] ?? upcoming[0]
pub async fn get_widget_snapshot(
    pool: &PgPool,
    user_id: &str,
) -> Result<WidgetSnapshotResponse, AppError> {
    let now = Utc::now();
    let recent_threshold = now - Duration::hours(1);

    // 개인일정 조회
    let personal_rows: Vec<RawScheduleRow> = sqlx::query_as(
        "SELECT \
           id, \
           schedule_type::TEXT AS schedule_type, \
           title, \
           emoji, \
           start_at, \
           end_at, \
           location_name, \
           NULL::TEXT AS group_name, \
           NULL::BOOLEAN AS is_confirmed \
         FROM schedules \
         WHERE schedule_type = 'personal' \
           AND user_id = $1 \
           AND COALESCE(end_at, start_at) >= $2 \
         ORDER BY start_at ASC",
    )
    .bind(user_id)
    .bind(recent_threshold)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(format!("Failed to fetch personal schedules: {e}")))?;

    // 그룹일정 조회: user가 member인 그룹의 confirmed 일정
    let group_rows: Vec<RawScheduleRow> = sqlx::query_as(
        "SELECT \
           s.id, \
           s.schedule_type::TEXT AS schedule_type, \
           s.title, \
           s.emoji, \
           s.start_at, \
           s.end_at, \
           s.location_name, \
           g.name AS group_name, \
           s.is_confirmed \
         FROM schedules s \
         JOIN groups g ON g.id = s.group_id \
         JOIN group_members gm ON gm.group_id = s.group_id AND gm.user_id = $1 \
         WHERE s.schedule_type = 'group' \
           AND s.is_confirmed = TRUE \
           AND COALESCE(s.end_at, s.start_at) >= $2 \
         ORDER BY s.start_at ASC",
    )
    .bind(user_id)
    .bind(recent_threshold)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(format!("Failed to fetch group schedules: {e}")))?;

    // KST 기준 오늘 날짜 계산
    let now_kst = Seoul.from_utc_datetime(&now.naive_utc());
    let today_kst = now_kst.date_naive();

    // 모든 일정 합산 후 start_at 오름차순 정렬
    let mut all_items: Vec<WidgetScheduleItem> = personal_rows
        .into_iter()
        .chain(group_rows.into_iter())
        .map(|row| WidgetScheduleItem {
            id: row.id.to_string(),
            schedule_type: row.schedule_type,
            title: row.title,
            emoji: row.emoji,
            start_at: row.start_at,
            end_at: row.end_at,
            location_name: row.location_name,
            group_name: row.group_name,
            is_confirmed: row.is_confirmed.unwrap_or(false),
        })
        .collect();

    all_items.sort_by_key(|item| item.start_at);

    // KST 기준 today vs upcoming 분류
    let mut today: Vec<WidgetScheduleItem> = Vec::new();
    let mut upcoming: Vec<WidgetScheduleItem> = Vec::new();

    for item in all_items {
        let effective_end = item.end_at.unwrap_or(item.start_at);
        let classification_at = if item.start_at <= now && effective_end >= recent_threshold {
            now
        } else {
            item.start_at
        };
        let item_kst = Seoul.from_utc_datetime(&classification_at.naive_utc());
        let item_date_kst = item_kst.date_naive();

        if item_date_kst == today_kst {
            today.push(item);
        } else {
            upcoming.push(item);
        }
    }

    // 제한 적용
    today.truncate(6);
    upcoming.truncate(9);

    // next = today[0] ?? upcoming[0]
    let next = today.first().or_else(|| upcoming.first()).cloned();

    Ok(WidgetSnapshotResponse {
        next,
        today,
        upcoming,
    })
}
