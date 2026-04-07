use chrono::{DateTime, Utc};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::subscription::{EntitlementResponse, SubscriptionStatus};

#[derive(Debug, Clone)]
pub struct FirestoreSubscriptionRow {
    pub user_id: String,
    pub status: String,
    pub product_id: Option<String>,
    pub original_transaction_id: Option<String>,
    pub expiration_date: Option<String>,
    pub purchase_date: Option<String>,
    pub latest_app_store_signed_date: Option<i64>,
    pub latest_transaction_id: Option<String>,
    pub last_notification_type: Option<String>,
    pub last_offer_type: Option<i32>,
    pub last_offer_identifier: Option<String>,
}

#[derive(Debug, Clone)]
pub struct FirestoreSubscriptionOwnerRow {
    pub original_transaction_id: String,
    pub user_id: String,
    pub product_id: String,
}

#[derive(Debug, Clone)]
pub struct FirestoreEntitlementOverrideRow {
    pub user_id: String,
    pub is_active: bool,
    pub override_type: String,
    pub reason: Option<String>,
    pub expires_at: Option<String>,
    pub created_by: Option<String>,
    pub revoked_at: Option<String>,
    pub revoked_by: Option<String>,
    pub revoked_reason: Option<String>,
}

pub async fn backfill_subscription(
    pool: &PgPool,
    row: FirestoreSubscriptionRow,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id, expiration_date, purchase_date,
             latest_app_store_signed_date, latest_transaction_id, last_notification_type,
             last_offer_type, last_offer_identifier)
         VALUES
            ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (user_id) DO UPDATE
         SET status = EXCLUDED.status,
             product_id = EXCLUDED.product_id,
             original_transaction_id = EXCLUDED.original_transaction_id,
             expiration_date = EXCLUDED.expiration_date,
             purchase_date = EXCLUDED.purchase_date,
             latest_app_store_signed_date = EXCLUDED.latest_app_store_signed_date,
             latest_transaction_id = EXCLUDED.latest_transaction_id,
             last_notification_type = EXCLUDED.last_notification_type,
             last_offer_type = EXCLUDED.last_offer_type,
             last_offer_identifier = EXCLUDED.last_offer_identifier,
             updated_at = NOW()",
    )
    .bind(&row.user_id)
    .bind(parse_status(&row.status)?)
    .bind(&row.product_id)
    .bind(&row.original_transaction_id)
    .bind(parse_optional_rfc3339(&row.expiration_date)?)
    .bind(parse_optional_rfc3339(&row.purchase_date)?)
    .bind(row.latest_app_store_signed_date)
    .bind(&row.latest_transaction_id)
    .bind(&row.last_notification_type)
    .bind(row.last_offer_type)
    .bind(&row.last_offer_identifier)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn backfill_subscription_owner(
    pool: &PgPool,
    row: FirestoreSubscriptionOwnerRow,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO subscription_owners
            (original_transaction_id, user_id, product_id)
         VALUES ($1, $2, $3)
         ON CONFLICT (original_transaction_id) DO UPDATE
         SET user_id = EXCLUDED.user_id,
             product_id = EXCLUDED.product_id,
             updated_at = NOW()",
    )
    .bind(&row.original_transaction_id)
    .bind(&row.user_id)
    .bind(&row.product_id)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn backfill_entitlement_override(
    pool: &PgPool,
    row: FirestoreEntitlementOverrideRow,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, expires_at, created_by,
             revoked_at, revoked_by, revoked_reason)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (user_id) DO UPDATE
         SET is_active = EXCLUDED.is_active,
             override_type = EXCLUDED.override_type,
             reason = EXCLUDED.reason,
             expires_at = EXCLUDED.expires_at,
             created_by = EXCLUDED.created_by,
             revoked_at = EXCLUDED.revoked_at,
             revoked_by = EXCLUDED.revoked_by,
             revoked_reason = EXCLUDED.revoked_reason,
             updated_at = NOW()",
    )
    .bind(&row.user_id)
    .bind(row.is_active)
    .bind(&row.override_type)
    .bind(&row.reason)
    .bind(parse_optional_rfc3339(&row.expires_at)?)
    .bind(&row.created_by)
    .bind(parse_optional_rfc3339(&row.revoked_at)?)
    .bind(&row.revoked_by)
    .bind(&row.revoked_reason)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn recompute_entitlement(
    pool: &PgPool,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    crate::services::subscription_service::reconcile_entitlement(pool, user_id).await
}

fn parse_status(value: &str) -> Result<SubscriptionStatus, AppError> {
    match value {
        "none" => Ok(SubscriptionStatus::None),
        "subscribed" => Ok(SubscriptionStatus::Subscribed),
        "lifetime" => Ok(SubscriptionStatus::Lifetime),
        "expired" => Ok(SubscriptionStatus::Expired),
        "gracePeriod" | "grace_period" => Ok(SubscriptionStatus::GracePeriod),
        "revoked" => Ok(SubscriptionStatus::Revoked),
        _ => Err(AppError::BadRequest(
            "invalid subscription status".to_string(),
        )),
    }
}

fn parse_optional_rfc3339(value: &Option<String>) -> Result<Option<DateTime<Utc>>, AppError> {
    match value.as_deref() {
        Some(value) => DateTime::parse_from_rfc3339(value)
            .map(|value| Some(value.with_timezone(&Utc)))
            .map_err(|_| AppError::BadRequest("invalid timestamp".to_string())),
        None => Ok(None),
    }
}
