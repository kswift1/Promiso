//! Subscription backfill Red tests
//!
//! 목표:
//! - Firebase production 데이터를 PostgreSQL authority로 1회 백필할 수 있어야 한다.
//! - subscriptions / subscription_owners / entitlement_overrides는 보존하고,
//!   entitlements는 복사하지 않고 재계산해야 한다.
//!
//! 현재는 Rust backfill 서비스가 아직 없으므로 Red 상태가 정상이다.

use chrono::{Duration, Utc};
use promiso_backend::models::subscription::{EntitlementSource, SubscriptionStatus};
use promiso_backend::services::subscription_backfill_service::{
    backfill_entitlement_override, backfill_subscription, backfill_subscription_owner,
    recompute_entitlement, FirestoreEntitlementOverrideRow, FirestoreSubscriptionOwnerRow,
    FirestoreSubscriptionRow,
};
use sqlx::PgPool;

#[sqlx::test(migrations = "./migrations")]
async fn backfill_subscription_preserves_status_core_fields_and_signed_date(pool: PgPool) {
    backfill_subscription(
        &pool,
        FirestoreSubscriptionRow {
            user_id: "backfill_sub_1".to_string(),
            status: "subscribed".to_string(),
            product_id: Some("com.promiso.pro.monthly".to_string()),
            original_transaction_id: Some("otx_backfill_1".to_string()),
            expiration_date: Some((Utc::now() + Duration::days(30)).to_rfc3339()),
            purchase_date: Some((Utc::now() - Duration::days(1)).to_rfc3339()),
            latest_app_store_signed_date: Some(1773218124000),
            latest_transaction_id: Some("tx_backfill_1".to_string()),
            last_notification_type: Some("DID_RENEW".to_string()),
            last_offer_type: Some(3),
            last_offer_identifier: Some("SPRING2026".to_string()),
        },
    )
    .await
    .expect("subscription backfill should succeed");

    let row: (SubscriptionStatus, Option<i64>, Option<String>) = sqlx::query_as(
        "SELECT status, latest_app_store_signed_date, last_offer_identifier
         FROM subscriptions
         WHERE user_id = $1",
    )
    .bind("backfill_sub_1")
    .fetch_one(&pool)
    .await
    .expect("subscription row should exist");

    assert_eq!(row.0, SubscriptionStatus::Subscribed);
    assert_eq!(row.1, Some(1773218124000));
    assert_eq!(row.2.as_deref(), Some("SPRING2026"));
}

#[sqlx::test(migrations = "./migrations")]
async fn backfill_subscription_owner_preserves_ownership_mapping(pool: PgPool) {
    backfill_subscription_owner(
        &pool,
        FirestoreSubscriptionOwnerRow {
            original_transaction_id: "otx_owner_1".to_string(),
            user_id: "owner_user_1".to_string(),
            product_id: "com.promiso.pro.yearly".to_string(),
        },
    )
    .await
    .expect("owner backfill should succeed");

    let row: (String, String) = sqlx::query_as(
        "SELECT user_id, product_id
         FROM subscription_owners
         WHERE original_transaction_id = $1",
    )
    .bind("otx_owner_1")
    .fetch_one(&pool)
    .await
    .expect("owner row should exist");

    assert_eq!(row.0, "owner_user_1");
    assert_eq!(row.1, "com.promiso.pro.yearly");
}

#[sqlx::test(migrations = "./migrations")]
async fn backfill_override_preserves_legacy_override_type(pool: PgPool) {
    backfill_entitlement_override(
        &pool,
        FirestoreEntitlementOverrideRow {
            user_id: "override_legacy_1".to_string(),
            is_active: true,
            override_type: "coupon_redeem".to_string(),
            reason: Some("legacy coupon".to_string()),
            expires_at: Some((Utc::now() + Duration::days(30)).to_rfc3339()),
            created_by: Some("admin_legacy".to_string()),
            revoked_at: None,
            revoked_by: None,
            revoked_reason: None,
        },
    )
    .await
    .expect("override backfill should succeed");

    let row: (String,) =
        sqlx::query_as("SELECT override_type FROM entitlement_overrides WHERE user_id = $1")
            .bind("override_legacy_1")
            .fetch_one(&pool)
            .await
            .expect("override row should exist");

    assert_eq!(row.0, "coupon_redeem");
}

#[sqlx::test(migrations = "./migrations")]
async fn recompute_entitlement_uses_subscription_over_override(pool: PgPool) {
    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id)
         VALUES ('backfill_user_1', 'subscribed', 'com.promiso.pro.monthly', 'otx_priority_1')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, created_by)
         VALUES ('backfill_user_1', true, 'manual_pro_grant', 'support', 'admin_1')",
    )
    .execute(&pool)
    .await
    .expect("Failed to insert override");

    let entitlement = recompute_entitlement(&pool, "backfill_user_1")
        .await
        .expect("entitlement recompute should succeed");

    assert!(entitlement.has_pro);
    assert_eq!(entitlement.source, EntitlementSource::Subscription);
}

#[sqlx::test(migrations = "./migrations")]
async fn recompute_entitlement_does_not_copy_firestore_entitlement_row(pool: PgPool) {
    backfill_subscription(
        &pool,
        FirestoreSubscriptionRow {
            user_id: "backfill_user_2".to_string(),
            status: "expired".to_string(),
            product_id: Some("com.promiso.pro.monthly".to_string()),
            original_transaction_id: Some("otx_backfill_2".to_string()),
            expiration_date: Some((Utc::now() - Duration::days(1)).to_rfc3339()),
            purchase_date: Some((Utc::now() - Duration::days(31)).to_rfc3339()),
            latest_app_store_signed_date: Some(1773218124001),
            latest_transaction_id: Some("tx_backfill_2".to_string()),
            last_notification_type: Some("EXPIRED".to_string()),
            last_offer_type: None,
            last_offer_identifier: None,
        },
    )
    .await
    .expect("subscription backfill should succeed");

    let entitlement = recompute_entitlement(&pool, "backfill_user_2")
        .await
        .expect("entitlement recompute should succeed");

    assert!(!entitlement.has_pro);
    assert_eq!(entitlement.subscription_status, Some(SubscriptionStatus::Expired));
}
