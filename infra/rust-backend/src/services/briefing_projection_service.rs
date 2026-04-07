use chrono::{DateTime, Duration, Timelike, Utc};
use chrono_tz::Tz;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::subscription::EntitlementResponse;

const NEXT_DISPATCH_SEARCH_HOURS: i64 = 72;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct BriefingProjection {
    pub user_id: String,
    pub notification_hour: i16,
    pub timezone: String,
    pub language: String,
    pub style: String,
    pub next_dispatch_at: DateTime<Utc>,
    pub default_location_title: Option<String>,
    pub default_location_latitude: Option<f64>,
    pub default_location_longitude: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct BriefingSettingsInput {
    pub notification_hour: i16,
    pub timezone: String,
    pub language: String,
    pub style: String,
    pub default_location_title: Option<String>,
    pub default_location_latitude: Option<f64>,
    pub default_location_longitude: Option<f64>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct BriefingSettingsRecord {
    user_id: String,
    briefing_notification_hour: Option<i16>,
    briefing_timezone: Option<String>,
    briefing_language: Option<String>,
    briefing_style: Option<String>,
    briefing_default_location_title: Option<String>,
    briefing_default_location_latitude: Option<f64>,
    briefing_default_location_longitude: Option<f64>,
}

pub fn build_projection(
    settings: &BriefingSettingsInput,
    entitlement: &EntitlementResponse,
    now: DateTime<Utc>,
) -> Option<BriefingProjection> {
    if !(entitlement.has_pro || entitlement.override_active) {
        return None;
    }

    if !(0..=23).contains(&settings.notification_hour) {
        return None;
    }

    let next_dispatch_at =
        compute_next_dispatch_at(now, &settings.timezone, settings.notification_hour)?;

    Some(BriefingProjection {
        user_id: String::new(),
        notification_hour: settings.notification_hour,
        timezone: settings.timezone.clone(),
        language: normalize_language(&settings.language),
        style: if settings.style.trim().is_empty() {
            "friendly".to_string()
        } else {
            settings.style.trim().to_string()
        },
        next_dispatch_at,
        default_location_title: settings.default_location_title.clone(),
        default_location_latitude: settings.default_location_latitude,
        default_location_longitude: settings.default_location_longitude,
    })
}

pub fn compute_next_dispatch_at(
    now: DateTime<Utc>,
    timezone: &str,
    notification_hour: i16,
) -> Option<DateTime<Utc>> {
    let tz: Tz = timezone.parse().ok()?;
    let start = ceil_to_next_hour(now);

    for offset in 0..NEXT_DISPATCH_SEARCH_HOURS {
        let candidate = start + Duration::hours(offset);
        let local_candidate = candidate.with_timezone(&tz);
        if local_candidate.hour() as i16 == notification_hour {
            return Some(candidate);
        }
    }

    None
}

pub async fn reconcile_projection(
    pool: &PgPool,
    user_id: &str,
    now: DateTime<Utc>,
) -> Result<Option<BriefingProjection>, AppError> {
    let settings = sqlx::query_as::<_, BriefingSettingsRecord>(
        "SELECT * FROM user_settings WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let entitlement = sqlx::query_as::<_, crate::models::subscription::EntitlementRecord>(
        "SELECT * FROM entitlements WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let Some(settings) = settings else {
        sqlx::query("DELETE FROM briefing_subscriptions WHERE user_id = $1")
            .bind(user_id)
            .execute(pool)
            .await?;
        return Ok(None);
    };

    let Some(entitlement) = entitlement else {
        sqlx::query("DELETE FROM briefing_subscriptions WHERE user_id = $1")
            .bind(user_id)
            .execute(pool)
            .await?;
        return Ok(None);
    };

    let settings_input = BriefingSettingsInput {
        notification_hour: settings.briefing_notification_hour.unwrap_or(-1),
        timezone: settings
            .briefing_timezone
            .unwrap_or_else(|| "Asia/Seoul".to_string()),
        language: settings
            .briefing_language
            .unwrap_or_else(|| "ko".to_string()),
        style: settings
            .briefing_style
            .unwrap_or_else(|| "friendly".to_string()),
        default_location_title: settings.briefing_default_location_title,
        default_location_latitude: settings.briefing_default_location_latitude,
        default_location_longitude: settings.briefing_default_location_longitude,
    };

    let entitlement_input = EntitlementResponse {
        has_pro: entitlement.has_pro,
        source: entitlement.source,
        subscription_status: entitlement.subscription_status,
        product_id: entitlement.product_id,
        expiration_date: entitlement.expiration_date,
        override_active: entitlement.override_active,
        override_expires_at: entitlement.override_expires_at,
        override_type: entitlement.override_type,
        last_offer_type: entitlement.last_offer_type,
        last_offer_identifier: entitlement.last_offer_identifier,
        updated_at: entitlement.updated_at,
    };

    let Some(mut projection) = build_projection(&settings_input, &entitlement_input, now) else {
        sqlx::query("DELETE FROM briefing_subscriptions WHERE user_id = $1")
            .bind(user_id)
            .execute(pool)
            .await?;
        return Ok(None);
    };

    projection.user_id = settings.user_id;

    let saved = sqlx::query_as::<_, BriefingProjection>(
        "INSERT INTO briefing_subscriptions
            (user_id, notification_hour, timezone, language, style, next_dispatch_at,
             default_location_title, default_location_latitude, default_location_longitude)
         VALUES
            ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (user_id) DO UPDATE
         SET notification_hour = EXCLUDED.notification_hour,
             timezone = EXCLUDED.timezone,
             language = EXCLUDED.language,
             style = EXCLUDED.style,
             next_dispatch_at = EXCLUDED.next_dispatch_at,
             default_location_title = EXCLUDED.default_location_title,
             default_location_latitude = EXCLUDED.default_location_latitude,
             default_location_longitude = EXCLUDED.default_location_longitude,
             updated_at = NOW()
         RETURNING user_id, notification_hour, timezone, language, style,
                   next_dispatch_at, default_location_title,
                   default_location_latitude, default_location_longitude",
    )
    .bind(&projection.user_id)
    .bind(projection.notification_hour)
    .bind(&projection.timezone)
    .bind(&projection.language)
    .bind(&projection.style)
    .bind(projection.next_dispatch_at)
    .bind(&projection.default_location_title)
    .bind(projection.default_location_latitude)
    .bind(projection.default_location_longitude)
    .fetch_one(pool)
    .await?;

    Ok(Some(saved))
}

fn ceil_to_next_hour(now: DateTime<Utc>) -> DateTime<Utc> {
    let truncated = now
        .with_minute(0)
        .and_then(|value| value.with_second(0))
        .and_then(|value| value.with_nanosecond(0))
        .expect("valid datetime");

    if now == truncated {
        now
    } else {
        truncated + Duration::hours(1)
    }
}

fn normalize_language(language: &str) -> String {
    match language {
        "ko" | "en" => language.to_string(),
        _ => "ko".to_string(),
    }
}
