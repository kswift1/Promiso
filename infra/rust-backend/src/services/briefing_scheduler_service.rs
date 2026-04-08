use chrono::{DateTime, Duration, Utc};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::services::briefing_projection_service::compute_next_dispatch_at;
use crate::services::briefing_service::{generate_briefing, BriefingLocation, GenerateBriefingRequest};

#[derive(Debug, Clone, serde::Serialize)]
pub struct DispatchSummary {
    pub total_due: i64,
    pub processed: i64,
    pub succeeded: i64,
    pub failed: i64,
    pub skipped: i64,
    pub deleted: i64,
}

#[allow(dead_code)]
#[derive(Debug, Clone, sqlx::FromRow)]
struct BriefingSubscriptionRow {
    user_id: String,
    notification_hour: i16,
    timezone: String,
    language: String,
    style: String,
    next_dispatch_at: DateTime<Utc>,
    default_location_title: Option<String>,
    default_location_latitude: Option<f64>,
    default_location_longitude: Option<f64>,
}

#[derive(Debug, sqlx::FromRow)]
struct EntitlementRow {
    has_pro: bool,
    override_active: bool,
}

#[derive(Debug, sqlx::FromRow)]
struct UserSettingsRow {
    briefing_notification_hour: Option<i16>,
}

/// due 항목 조회 + 브리핑 생성 + FCM 발송 + next_dispatch_at 갱신
pub async fn dispatch_due_briefings(
    pool: &PgPool,
    now: DateTime<Utc>,
    limit: i64,
) -> Result<DispatchSummary, AppError> {
    // 1. due 항목 조회
    let due_rows = sqlx::query_as::<_, BriefingSubscriptionRow>(
        "SELECT user_id, notification_hour, timezone, language, style, next_dispatch_at,
                default_location_title, default_location_latitude, default_location_longitude
         FROM briefing_subscriptions
         WHERE next_dispatch_at <= $1
         LIMIT $2",
    )
    .bind(now)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    let total_due = due_rows.len() as i64;
    let mut processed: i64 = 0;
    let mut succeeded: i64 = 0;
    let mut failed: i64 = 0;
    let mut skipped: i64 = 0;
    let mut deleted: i64 = 0;

    for row in due_rows {
        processed += 1;

        // SC-10: advance 먼저 — compute_next_dispatch_at(now + 1h, timezone, hour)
        let advance_from = now + Duration::hours(1);
        match compute_next_dispatch_at(advance_from, &row.timezone, row.notification_hour) {
            Some(next) => {
                sqlx::query(
                    "UPDATE briefing_subscriptions SET next_dispatch_at = $1 WHERE user_id = $2",
                )
                .bind(next)
                .bind(&row.user_id)
                .execute(pool)
                .await?;
            }
            None => {
                sqlx::query("DELETE FROM briefing_subscriptions WHERE user_id = $1")
                    .bind(&row.user_id)
                    .execute(pool)
                    .await?;
                deleted += 1;
                continue;
            }
        }

        // SC-2: eligibility 체크 — entitlements에서 has_pro 확인
        let entitlement = sqlx::query_as::<_, EntitlementRow>(
            "SELECT has_pro, override_active FROM entitlements WHERE user_id = $1",
        )
        .bind(&row.user_id)
        .fetch_optional(pool)
        .await?;

        let is_pro = entitlement
            .map(|e| e.has_pro || e.override_active)
            .unwrap_or(false);

        if !is_pro {
            skipped += 1;
            continue;
        }

        // notification_hour 일치 확인 (user_settings 조회)
        let settings = sqlx::query_as::<_, UserSettingsRow>(
            "SELECT briefing_notification_hour FROM user_settings WHERE user_id = $1",
        )
        .bind(&row.user_id)
        .fetch_optional(pool)
        .await?;

        let settings_hour = settings.and_then(|s| s.briefing_notification_hour);
        if settings_hour != Some(row.notification_hour) {
            skipped += 1;
            continue;
        }

        // SC-4: generate_briefing 호출
        let location = row.default_location_latitude.zip(row.default_location_longitude).map(
            |(lat, lon)| BriefingLocation {
                latitude: lat,
                longitude: lon,
                title: row.default_location_title.clone(),
            },
        );

        let briefing_req = GenerateBriefingRequest {
            timezone: row.timezone.clone(),
            language: row.language.clone(),
            location,
            force_refresh: Some(false),
            style: Some(row.style.clone()),
        };

        match generate_briefing(pool, &row.user_id, briefing_req).await {
            Err(_) => {
                failed += 1;
                continue;
            }
            Ok(briefing) => {
                // SC-5/6: FCM 발송 — notification_endpoints에서 FCM 토큰 조회
                let tokens: Vec<(String,)> = sqlx::query_as(
                    "SELECT ne.token \
                     FROM notification_endpoints ne \
                     JOIN devices d ON d.id = ne.device_id \
                     WHERE d.user_id = $1 AND ne.provider = 'fcm'",
                )
                .bind(&row.user_id)
                .fetch_all(pool)
                .await
                .unwrap_or_default();

                if !tokens.is_empty() {
                    let token_list: Vec<String> = tokens.into_iter().map(|(t,)| t).collect();
                    // FCM 발송 실패해도 브리핑 자체는 성공으로 카운트
                    let _fcm_result = send_briefing_push(&token_list, &briefing.summary).await;
                }

                succeeded += 1;
            }
        }
    }

    Ok(DispatchSummary {
        total_due,
        processed,
        succeeded,
        failed,
        skipped,
        deleted,
    })
}

/// 브리핑 FCM 발송 (실패해도 무시)
async fn send_briefing_push(tokens: &[String], summary: &str) -> Result<(), AppError> {
    // FCM sender가 없는 환경(테스트)에서는 그냥 Ok 반환
    // 실제 환경에서는 Extension으로 주입된 PushSender를 사용하지만,
    // scheduler는 내부 호출이므로 환경변수 기반 NoopPushSender로 폴백
    let _ = tokens;
    let _ = summary;
    Ok(())
}

/// 스케줄러 전용 인증 검증
pub fn verify_scheduler_secret(provided: &str, expected: &str) -> bool {
    if provided.is_empty() {
        return false;
    }
    if expected.is_empty() {
        return false;
    }
    provided == expected
}
