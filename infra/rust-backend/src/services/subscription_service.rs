use chrono::{DateTime, Utc};
use sqlx::{PgPool, Postgres, Transaction};

use crate::errors::AppError;
use crate::models::subscription::{
    AppleNotificationRequest, EntitlementOverrideRecord, EntitlementRecord, EntitlementResponse,
    EntitlementSource, SubscriptionOwnerRecord, SubscriptionRecord, SubscriptionStatus,
    SubscriptionStatusResponse, VerifyPurchaseRequest, VerifyPurchaseResponse,
};
use crate::services::app_store_service::{
    AppStoreNotificationKind, AppStoreTransactionKind, AppStoreVerifier, VerifiedNotification,
    VerifiedRenewalInfo, VerifiedTransaction,
};

#[derive(Debug, Clone)]
struct DerivedSubscriptionState {
    status: SubscriptionStatus,
    expiration_date: Option<DateTime<Utc>>,
    purchase_date: Option<DateTime<Utc>>,
}

pub async fn get_status(
    pool: &PgPool,
    user_id: &str,
) -> Result<SubscriptionStatusResponse, AppError> {
    let record = fetch_subscription_record(pool, user_id).await?;
    Ok(build_status_response(record.as_ref()))
}

pub async fn get_entitlement(
    pool: &PgPool,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    let record = fetch_entitlement_record(pool, user_id).await?;
    match record {
        Some(record) => Ok(build_entitlement_response(&record)),
        None => reconcile_entitlement(pool, user_id).await,
    }
}

pub async fn verify_purchase(
    pool: &PgPool,
    user_id: &str,
    req: VerifyPurchaseRequest,
    verifier: &dyn AppStoreVerifier,
) -> Result<VerifyPurchaseResponse, AppError> {
    if req.transaction_jws.trim().is_empty() || req.product_id.trim().is_empty() {
        return Err(AppError::BadRequest(
            "transactionJWS와 productId는 필수입니다".to_string(),
        ));
    }

    let payload = verifier.verify_transaction(&req.transaction_jws)?;

    if payload.original_transaction_id.is_empty() || payload.product_id.is_empty() {
        return Err(AppError::PreconditionFailed(
            "유효한 App Store 트랜잭션 정보가 없습니다".to_string(),
        ));
    }

    if payload.product_id != req.product_id {
        return Err(AppError::BadRequest(
            "상품 ID가 일치하지 않습니다".to_string(),
        ));
    }

    let derived_state = derive_status_from_transaction(&payload);
    let signed_date = to_millis(payload.signed_date);
    let mut tx = pool.begin().await?;
    let owner_record = fetch_owner_record_in_tx(&mut tx, &payload.original_transaction_id).await?;
    let current_record = fetch_subscription_record_in_tx(&mut tx, user_id).await?;
    let force_transfer = req.force_transfer.unwrap_or(false);
    let mut previous_owner = None;

    if let Some(owner_record) = owner_record.as_ref() {
        if owner_record.user_id != user_id {
            if !force_transfer {
                return Err(AppError::Conflict(
                    "이 구독은 다른 계정에 연결되어 있습니다".to_string(),
                ));
            }

            previous_owner = Some(owner_record.user_id.clone());
            sqlx::query(
                "UPDATE subscriptions
                 SET status = 'expired', updated_at = NOW()
                 WHERE user_id = $1",
            )
            .bind(&owner_record.user_id)
            .execute(&mut *tx)
            .await?;
        }
    }

    upsert_owner_in_tx(
        &mut tx,
        &payload.original_transaction_id,
        user_id,
        &payload.product_id,
    )
    .await?;

    let current_latest_signed_date = current_record
        .as_ref()
        .and_then(|record| record.latest_app_store_signed_date);

    let subscription_response = if is_stale(signed_date, current_latest_signed_date) {
        build_status_response(current_record.as_ref())
    } else {
        let subscription = upsert_subscription_in_tx(
            &mut tx,
            user_id,
            SubscriptionUpsert {
                status: derived_state.status,
                product_id: Some(payload.product_id.clone()),
                original_transaction_id: Some(payload.original_transaction_id.clone()),
                expiration_date: derived_state.expiration_date,
                purchase_date: derived_state.purchase_date,
                latest_app_store_signed_date: signed_date,
                latest_transaction_id: payload.transaction_id.clone(),
                last_notification_type: None,
                last_offer_type: payload.offer_type,
                last_offer_identifier: payload.offer_identifier.clone(),
            },
        )
        .await?;
        build_status_response(Some(&subscription))
    };

    reconcile_entitlement_in_tx(&mut tx, user_id).await?;
    if let Some(previous_owner) = previous_owner.as_deref() {
        reconcile_entitlement_in_tx(&mut tx, previous_owner).await?;
    }

    tx.commit().await?;

    Ok(VerifyPurchaseResponse {
        success: true,
        subscription_status: subscription_response,
    })
}

pub async fn handle_apple_notification(
    pool: &PgPool,
    req: AppleNotificationRequest,
    verifier: &dyn AppStoreVerifier,
) -> Result<(), AppError> {
    if req.signed_payload.trim().is_empty() {
        return Err(AppError::BadRequest(
            "signedPayload는 필수입니다".to_string(),
        ));
    }

    let notification = verifier.verify_notification(&req.signed_payload)?;

    if is_no_op_notification(&notification.notification_type) {
        return Ok(());
    }

    let original_transaction_id = &notification.transaction.original_transaction_id;
    if original_transaction_id.is_empty() {
        return Err(AppError::Internal(
            "Missing originalTransactionId".to_string(),
        ));
    }

    let derived_state = derive_status_from_notification(
        &notification.notification_type,
        &notification.transaction,
        notification.renewal_info.as_ref(),
    );

    let Some(derived_state) = derived_state else {
        return Ok(());
    };

    let mut tx = pool.begin().await?;
    let owner_record = fetch_owner_record_in_tx(&mut tx, original_transaction_id).await?;
    let owner_record = owner_record.ok_or_else(|| {
        AppError::Internal(format!(
            "Owner not found for originalTransactionId: {original_transaction_id}"
        ))
    })?;

    let current_record = fetch_subscription_record_in_tx(&mut tx, &owner_record.user_id).await?;
    let signed_date = latest_signed_date(&notification);
    let current_latest_signed_date = current_record
        .as_ref()
        .and_then(|record| record.latest_app_store_signed_date);

    if !is_stale(signed_date, current_latest_signed_date) {
        let current_offer_type = current_record
            .as_ref()
            .and_then(|record| record.last_offer_type);
        let current_offer_identifier = current_record
            .as_ref()
            .and_then(|record| record.last_offer_identifier.clone());
        let offer_type =
            if notification.notification_type == AppStoreNotificationKind::OfferRedeemed {
                notification.transaction.offer_type
            } else {
                current_offer_type
            };
        let offer_identifier =
            if notification.notification_type == AppStoreNotificationKind::OfferRedeemed {
                notification.transaction.offer_identifier.clone()
            } else {
                current_offer_identifier
            };

        upsert_subscription_in_tx(
            &mut tx,
            &owner_record.user_id,
            SubscriptionUpsert {
                status: derived_state.status,
                product_id: Some(notification.transaction.product_id.clone()),
                original_transaction_id: Some(original_transaction_id.clone()),
                expiration_date: derived_state.expiration_date,
                purchase_date: derived_state.purchase_date,
                latest_app_store_signed_date: signed_date,
                latest_transaction_id: notification.transaction.transaction_id.clone(),
                last_notification_type: Some(notification.notification_type.as_str().to_string()),
                last_offer_type: offer_type,
                last_offer_identifier: offer_identifier,
            },
        )
        .await?;
    }

    reconcile_entitlement_in_tx(&mut tx, &owner_record.user_id).await?;
    tx.commit().await?;
    Ok(())
}

pub async fn reconcile_entitlement(
    pool: &PgPool,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    let mut tx = pool.begin().await?;
    let entitlement = reconcile_entitlement_in_tx(&mut tx, user_id).await?;
    tx.commit().await?;
    Ok(entitlement)
}

fn derive_status_from_transaction(transaction: &VerifiedTransaction) -> DerivedSubscriptionState {
    if transaction.revocation_date.is_some() {
        return DerivedSubscriptionState {
            status: SubscriptionStatus::Revoked,
            expiration_date: transaction.expires_date,
            purchase_date: transaction.purchase_date,
        };
    }

    if matches!(
        transaction.transaction_kind,
        Some(AppStoreTransactionKind::NonConsumable)
    ) || transaction.expires_date.is_none()
    {
        return DerivedSubscriptionState {
            status: SubscriptionStatus::Lifetime,
            expiration_date: None,
            purchase_date: transaction.purchase_date,
        };
    }

    let status = match transaction.expires_date {
        Some(expires_date) if expires_date > Utc::now() => SubscriptionStatus::Subscribed,
        _ => SubscriptionStatus::Expired,
    };

    DerivedSubscriptionState {
        status,
        expiration_date: transaction.expires_date,
        purchase_date: transaction.purchase_date,
    }
}

fn derive_status_from_notification(
    notification_type: &AppStoreNotificationKind,
    transaction: &VerifiedTransaction,
    renewal_info: Option<&VerifiedRenewalInfo>,
) -> Option<DerivedSubscriptionState> {
    let transaction_state = derive_status_from_transaction(transaction);
    let grace_expiration =
        renewal_info.and_then(|info| info.grace_period_expires_date.or(info.renewal_date));

    match notification_type {
        AppStoreNotificationKind::Subscribed
        | AppStoreNotificationKind::DidRenew
        | AppStoreNotificationKind::DidChangeRenewalPref
        | AppStoreNotificationKind::DidChangeRenewalStatus
        | AppStoreNotificationKind::OfferRedeemed
        | AppStoreNotificationKind::PriceIncrease
        | AppStoreNotificationKind::RenewalExtended
        | AppStoreNotificationKind::RenewalExtension
        | AppStoreNotificationKind::RefundReversed => Some(transaction_state),
        AppStoreNotificationKind::DidFailToRenew => Some(DerivedSubscriptionState {
            status: if renewal_info
                .map(|info| info.is_in_billing_retry_period)
                .unwrap_or(false)
                || grace_expiration.is_some()
            {
                SubscriptionStatus::GracePeriod
            } else {
                SubscriptionStatus::Expired
            },
            expiration_date: grace_expiration.or(transaction_state.expiration_date),
            purchase_date: transaction_state.purchase_date,
        }),
        AppStoreNotificationKind::Expired => Some(DerivedSubscriptionState {
            status: SubscriptionStatus::Expired,
            ..transaction_state
        }),
        AppStoreNotificationKind::GracePeriodExpired => Some(DerivedSubscriptionState {
            status: SubscriptionStatus::Expired,
            expiration_date: grace_expiration.or(transaction_state.expiration_date),
            purchase_date: transaction_state.purchase_date,
        }),
        AppStoreNotificationKind::Refund | AppStoreNotificationKind::Revoke => {
            Some(DerivedSubscriptionState {
                status: SubscriptionStatus::Revoked,
                ..transaction_state
            })
        }
        _ => None,
    }
}

async fn fetch_subscription_record(
    pool: &PgPool,
    user_id: &str,
) -> Result<Option<SubscriptionRecord>, AppError> {
    sqlx::query_as::<_, SubscriptionRecord>("SELECT * FROM subscriptions WHERE user_id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::from)
}

async fn fetch_subscription_record_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    user_id: &str,
) -> Result<Option<SubscriptionRecord>, AppError> {
    sqlx::query_as::<_, SubscriptionRecord>("SELECT * FROM subscriptions WHERE user_id = $1")
        .bind(user_id)
        .fetch_optional(&mut **tx)
        .await
        .map_err(AppError::from)
}

async fn fetch_owner_record_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    original_transaction_id: &str,
) -> Result<Option<SubscriptionOwnerRecord>, AppError> {
    sqlx::query_as::<_, SubscriptionOwnerRecord>(
        "SELECT * FROM subscription_owners WHERE original_transaction_id = $1",
    )
    .bind(original_transaction_id)
    .fetch_optional(&mut **tx)
    .await
    .map_err(AppError::from)
}

async fn fetch_entitlement_record(
    pool: &PgPool,
    user_id: &str,
) -> Result<Option<EntitlementRecord>, AppError> {
    sqlx::query_as::<_, EntitlementRecord>("SELECT * FROM entitlements WHERE user_id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::from)
}

async fn fetch_override_record_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    user_id: &str,
) -> Result<Option<EntitlementOverrideRecord>, AppError> {
    sqlx::query_as::<_, EntitlementOverrideRecord>(
        "SELECT * FROM entitlement_overrides WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&mut **tx)
    .await
    .map_err(AppError::from)
}

async fn upsert_owner_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    original_transaction_id: &str,
    user_id: &str,
    product_id: &str,
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
    .bind(original_transaction_id)
    .bind(user_id)
    .bind(product_id)
    .execute(&mut **tx)
    .await?;

    Ok(())
}

struct SubscriptionUpsert {
    status: SubscriptionStatus,
    product_id: Option<String>,
    original_transaction_id: Option<String>,
    expiration_date: Option<DateTime<Utc>>,
    purchase_date: Option<DateTime<Utc>>,
    latest_app_store_signed_date: Option<i64>,
    latest_transaction_id: Option<String>,
    last_notification_type: Option<String>,
    last_offer_type: Option<i32>,
    last_offer_identifier: Option<String>,
}

async fn upsert_subscription_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    user_id: &str,
    upsert: SubscriptionUpsert,
) -> Result<SubscriptionRecord, AppError> {
    sqlx::query_as::<_, SubscriptionRecord>(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id,
             expiration_date, purchase_date, latest_app_store_signed_date,
             latest_transaction_id, last_notification_type, last_offer_type,
             last_offer_identifier)
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
             updated_at = NOW()
         RETURNING *",
    )
    .bind(user_id)
    .bind(upsert.status)
    .bind(upsert.product_id)
    .bind(upsert.original_transaction_id)
    .bind(upsert.expiration_date)
    .bind(upsert.purchase_date)
    .bind(upsert.latest_app_store_signed_date)
    .bind(upsert.latest_transaction_id)
    .bind(upsert.last_notification_type)
    .bind(upsert.last_offer_type)
    .bind(upsert.last_offer_identifier)
    .fetch_one(&mut **tx)
    .await
    .map_err(AppError::from)
}

async fn reconcile_entitlement_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    let subscription = fetch_subscription_record_in_tx(tx, user_id).await?;
    let entitlement_override = fetch_override_record_in_tx(tx, user_id).await?;
    let subscription_status = subscription.as_ref().map(|record| record.status.clone());
    let subscription_active = subscription_status
        .as_ref()
        .map(is_active_subscription_status)
        .unwrap_or(false);
    let override_active = entitlement_override
        .as_ref()
        .map(is_override_active)
        .unwrap_or(false);
    let has_pro = subscription_active || override_active;
    let source = if subscription_active {
        EntitlementSource::Subscription
    } else if override_active {
        EntitlementSource::Override
    } else {
        EntitlementSource::None
    };

    let record = sqlx::query_as::<_, EntitlementRecord>(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, product_id,
             expiration_date, override_active, override_expires_at,
             override_type, last_offer_type, last_offer_identifier)
         VALUES
            ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (user_id) DO UPDATE
         SET has_pro = EXCLUDED.has_pro,
             source = EXCLUDED.source,
             subscription_status = EXCLUDED.subscription_status,
             product_id = EXCLUDED.product_id,
             expiration_date = EXCLUDED.expiration_date,
             override_active = EXCLUDED.override_active,
             override_expires_at = EXCLUDED.override_expires_at,
             override_type = EXCLUDED.override_type,
             last_offer_type = EXCLUDED.last_offer_type,
             last_offer_identifier = EXCLUDED.last_offer_identifier,
             updated_at = NOW()
         RETURNING *",
    )
    .bind(user_id)
    .bind(has_pro)
    .bind(source)
    .bind(subscription_status)
    .bind(
        subscription
            .as_ref()
            .and_then(|record| record.product_id.clone()),
    )
    .bind(
        subscription
            .as_ref()
            .and_then(|record| record.expiration_date),
    )
    .bind(override_active)
    .bind(
        entitlement_override
            .as_ref()
            .and_then(|record| record.expires_at),
    )
    .bind(entitlement_override.as_ref().and_then(|record| {
        if override_active {
            Some(record.override_type.clone())
        } else {
            None
        }
    }))
    .bind(
        subscription
            .as_ref()
            .and_then(|record| record.last_offer_type),
    )
    .bind(
        subscription
            .as_ref()
            .and_then(|record| record.last_offer_identifier.clone()),
    )
    .fetch_one(&mut **tx)
    .await?;

    Ok(build_entitlement_response(&record))
}

fn build_status_response(record: Option<&SubscriptionRecord>) -> SubscriptionStatusResponse {
    match record {
        Some(record) => SubscriptionStatusResponse {
            status: record.status.clone(),
            product_id: record.product_id.clone(),
            original_transaction_id: record.original_transaction_id.clone(),
            expiration_date: record.expiration_date,
            purchase_date: record.purchase_date,
            latest_app_store_signed_date: record.latest_app_store_signed_date,
            latest_transaction_id: record.latest_transaction_id.clone(),
            last_notification_type: record.last_notification_type.clone(),
            last_offer_type: record.last_offer_type,
            last_offer_identifier: record.last_offer_identifier.clone(),
            updated_at: record.updated_at,
        },
        None => SubscriptionStatusResponse {
            status: SubscriptionStatus::None,
            product_id: None,
            original_transaction_id: None,
            expiration_date: None,
            purchase_date: None,
            latest_app_store_signed_date: None,
            latest_transaction_id: None,
            last_notification_type: None,
            last_offer_type: None,
            last_offer_identifier: None,
            updated_at: Utc::now(),
        },
    }
}

fn build_entitlement_response(record: &EntitlementRecord) -> EntitlementResponse {
    EntitlementResponse {
        has_pro: record.has_pro,
        source: record.source.clone(),
        subscription_status: record.subscription_status.clone(),
        product_id: record.product_id.clone(),
        expiration_date: record.expiration_date,
        override_active: record.override_active,
        override_expires_at: record.override_expires_at,
        override_type: record.override_type.clone(),
        last_offer_type: record.last_offer_type,
        last_offer_identifier: record.last_offer_identifier.clone(),
        updated_at: record.updated_at,
    }
}

fn is_override_active(record: &EntitlementOverrideRecord) -> bool {
    if !record.is_active {
        return false;
    }

    match record.expires_at {
        Some(expires_at) => expires_at >= Utc::now(),
        None => true,
    }
}

fn is_active_subscription_status(status: &SubscriptionStatus) -> bool {
    matches!(
        status,
        SubscriptionStatus::Subscribed
            | SubscriptionStatus::Lifetime
            | SubscriptionStatus::GracePeriod
    )
}

fn is_no_op_notification(notification_type: &AppStoreNotificationKind) -> bool {
    matches!(
        notification_type,
        AppStoreNotificationKind::Test
            | AppStoreNotificationKind::ConsumptionRequest
            | AppStoreNotificationKind::ExternalPurchaseToken
            | AppStoreNotificationKind::OneTimeCharge
            | AppStoreNotificationKind::RescindConsent
            | AppStoreNotificationKind::RefundDeclined
    )
}

fn latest_signed_date(notification: &VerifiedNotification) -> Option<i64> {
    [
        to_millis(notification.signed_date),
        to_millis(notification.transaction.signed_date),
        notification
            .renewal_info
            .as_ref()
            .and_then(|info| to_millis(info.signed_date)),
    ]
    .into_iter()
    .flatten()
    .max()
}

fn to_millis(date: Option<DateTime<Utc>>) -> Option<i64> {
    date.map(|date| date.timestamp_millis())
}

fn is_stale(incoming_signed_date: Option<i64>, current_signed_date: Option<i64>) -> bool {
    match (incoming_signed_date, current_signed_date) {
        (Some(incoming), Some(current)) => incoming < current,
        _ => false,
    }
}
