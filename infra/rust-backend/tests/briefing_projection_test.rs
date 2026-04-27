//! Briefing projection cutover tests
//!
//! 목표:
//! - subscription/override 기반 Pro 판정이 Rust authority에서 briefing projection으로 이어져야 한다.
//! - settings + entitlement 조건이 맞지 않으면 projection이 생성되면 안 된다.
//! - 다음 dispatch 시각 계산은 timezone 기준으로 안정적으로 동작해야 한다.

use chrono::{TimeZone, Utc};
use promiso_backend::models::subscription::EntitlementResponse;
use promiso_backend::services::briefing_projection_service::{
    build_projection, compute_next_dispatch_at, reconcile_projection, BriefingProjection,
    BriefingSettingsInput,
};
use sqlx::PgPool;

fn make_settings(notification_hour: i16, timezone: &str) -> BriefingSettingsInput {
    BriefingSettingsInput {
        notification_hour,
        timezone: timezone.to_string(),
        language: "ko".to_string(),
        style: "friendly".to_string(),
        default_location_title: None,
        default_location_latitude: None,
        default_location_longitude: None,
    }
}

fn make_entitlement(has_pro: bool, override_active: bool) -> EntitlementResponse {
    EntitlementResponse {
        has_pro,
        source: if has_pro {
            promiso_backend::models::subscription::EntitlementSource::Subscription
        } else {
            promiso_backend::models::subscription::EntitlementSource::None
        },
        subscription_status: None,
        product_id: None,
        expiration_date: None,
        override_active,
        override_expires_at: None,
        override_type: None,
        last_offer_type: None,
        last_offer_identifier: None,
        updated_at: Utc::now(),
    }
}

#[test]
fn projection_created_for_active_subscription() {
    let now = Utc.with_ymd_and_hms(2026, 4, 7, 0, 15, 0).unwrap();
    let settings = make_settings(9, "Asia/Seoul");
    let entitlement = make_entitlement(true, false);

    let projection = build_projection(&settings, &entitlement, now)
        .expect("projection should be created for active Pro user");

    assert_eq!(projection.notification_hour, 9);
    assert_eq!(projection.timezone, "Asia/Seoul");
}

#[test]
fn projection_created_for_active_override_without_subscription() {
    let now = Utc.with_ymd_and_hms(2026, 4, 7, 0, 15, 0).unwrap();
    let settings = make_settings(9, "Asia/Seoul");
    let mut entitlement = make_entitlement(false, true);
    entitlement.source = promiso_backend::models::subscription::EntitlementSource::Override;

    let projection = build_projection(&settings, &entitlement, now)
        .expect("projection should be created for override-backed Pro user");

    assert_eq!(projection.language, "ko");
}

#[test]
fn projection_not_created_for_free_user() {
    let now = Utc.with_ymd_and_hms(2026, 4, 7, 0, 15, 0).unwrap();
    let settings = make_settings(9, "Asia/Seoul");
    let entitlement = make_entitlement(false, false);

    let projection = build_projection(&settings, &entitlement, now);

    assert!(projection.is_none());
}

#[test]
fn projection_not_created_for_invalid_notification_hour() {
    let now = Utc.with_ymd_and_hms(2026, 4, 7, 0, 15, 0).unwrap();
    let settings = make_settings(99, "Asia/Seoul");
    let entitlement = make_entitlement(true, false);

    let projection = build_projection(&settings, &entitlement, now);

    assert!(projection.is_none());
}

#[test]
fn next_dispatch_at_uses_first_future_matching_hour_in_timezone() {
    let now = Utc.with_ymd_and_hms(2026, 4, 7, 0, 15, 0).unwrap();

    let next_dispatch =
        compute_next_dispatch_at(now, "Asia/Seoul", 9).expect("next dispatch should be computed");

    assert_eq!(
        next_dispatch,
        Utc.with_ymd_and_hms(2026, 4, 8, 0, 0, 0).unwrap()
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn reconcile_projection_persists_projection_row(pool: PgPool) {
    sqlx::query(
        "INSERT INTO user_settings
            (user_id, briefing_notification_hour, briefing_timezone, briefing_language, briefing_style)
         VALUES ($1, $2, $3, $4, $5)",
    )
    .bind("briefing_user_1")
    .bind(9_i16)
    .bind("Asia/Seoul")
    .bind("ko")
    .bind("friendly")
    .execute(&pool)
    .await
    .expect("test settings insert should succeed");

    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, override_active)
         VALUES ($1, true, 'subscription', 'subscribed', false)",
    )
    .bind("briefing_user_1")
    .execute(&pool)
    .await
    .expect("test entitlement insert should succeed");

    let projection = reconcile_projection(&pool, "briefing_user_1", Utc::now())
        .await
        .expect("reconcile should succeed")
        .expect("projection should exist");

    let saved: BriefingProjection = sqlx::query_as(
        "SELECT user_id, notification_hour, timezone, language, style, next_dispatch_at,
                default_location_title, default_location_latitude, default_location_longitude
         FROM briefing_subscriptions
         WHERE user_id = $1",
    )
    .bind("briefing_user_1")
    .fetch_one(&pool)
    .await
    .expect("projection row should exist");

    assert_eq!(projection.user_id, saved.user_id);
}
