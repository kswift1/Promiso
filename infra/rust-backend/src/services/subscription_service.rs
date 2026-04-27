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
use crate::services::slack_service::{
    build_slack_message, detect_subscription_transition, send_slack_notification,
    SlackMessageContext, SubscriptionTransitionContext,
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
    let subscription = fetch_subscription_record(pool, user_id).await?;
    let entitlement_override = fetch_override_record(pool, user_id).await?;

    let subscription_active = subscription
        .as_ref()
        .map(|record| is_active_subscription_status(&record.status, record.expiration_date))
        .unwrap_or(false);
    let override_active = entitlement_override
        .as_ref()
        .map(is_override_active)
        .unwrap_or(false);

    let base_response = build_status_response(subscription.as_ref());

    // subscription이 활성이거나 override도 비활성이면 subscriptions 기반 응답을 그대로 반환
    if subscription_active || !override_active {
        return Ok(base_response);
    }

    // subscription 비활성 + override 활성 → override 기준으로 Subscribed 응답
    let override_expires_at = entitlement_override
        .as_ref()
        .and_then(|record| record.expires_at);
    Ok(SubscriptionStatusResponse {
        status: SubscriptionStatus::Subscribed,
        expiration_date: override_expires_at,
        ..base_response
    })
}

pub async fn get_entitlement(
    pool: &PgPool,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    let record = fetch_entitlement_record(pool, user_id).await?;
    match record {
        Some(record) if !is_entitlement_record_stale(&record) => {
            Ok(build_entitlement_response(&record))
        }
        _ => reconcile_entitlement(pool, user_id).await,
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

    // 트랜잭션 커밋 후 Slack 알림 (메인 흐름 비차단)
    let before_status = current_record
        .as_ref()
        .map(|r| effective_status(&r.status, r.expiration_date).as_str().to_string());
    let after_status = subscription_response.status.as_str().to_string();
    let after_last_notification_type = subscription_response.last_notification_type.clone();
    let before_last_notification_type = current_record
        .as_ref()
        .and_then(|r| r.last_notification_type.clone());
    let slack_expiration = subscription_response
        .expiration_date
        .map(|d| d.to_rfc3339());
    let webhook_url = std::env::var("SLACK_WEBHOOK_URL").unwrap_or_default();
    let (nickname, total_pro_users, price) =
        fetch_slack_context(pool, user_id, &payload.product_id).await;
    notify_subscription_slack(
        &webhook_url,
        user_id,
        before_status.as_deref(),
        &after_status,
        after_last_notification_type.as_deref(),
        before_last_notification_type.as_deref(),
        &payload.product_id,
        slack_expiration.as_deref(),
        nickname,
        total_pro_users,
        price,
    )
    .await;

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

    // Slack 알림에 사용할 값을 미리 캡처 (derived_state가 이동되기 전에)
    let slack_after_status = derived_state.status.as_str().to_string();
    let slack_expiration_date = derived_state.expiration_date.map(|d| d.to_rfc3339());

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

    // 트랜잭션 커밋 후 Slack 알림 (메인 흐름 비차단, stale 시에도 현재 상태 기준으로 호출)
    let webhook_url = std::env::var("SLACK_WEBHOOK_URL").unwrap_or_default();
    let before_status = current_record
        .as_ref()
        .map(|r| effective_status(&r.status, r.expiration_date).as_str().to_string());
    let after_last_notification_type = Some(notification.notification_type.as_str().to_string());
    let before_last_notification_type = current_record
        .as_ref()
        .and_then(|r| r.last_notification_type.clone());
    let (nickname, total_pro_users, price) = fetch_slack_context(
        pool,
        &owner_record.user_id,
        &notification.transaction.product_id,
    )
    .await;
    notify_subscription_slack(
        &webhook_url,
        &owner_record.user_id,
        before_status.as_deref(),
        &slack_after_status,
        after_last_notification_type.as_deref(),
        before_last_notification_type.as_deref(),
        &notification.transaction.product_id,
        slack_expiration_date.as_deref(),
        nickname,
        total_pro_users,
        price,
    )
    .await;

    Ok(())
}

pub async fn reconcile_entitlement(
    pool: &PgPool,
    user_id: &str,
) -> Result<EntitlementResponse, AppError> {
    let mut tx = pool.begin().await?;
    sqlx::query("SELECT pg_advisory_xact_lock(hashtext($1))")
        .bind(user_id)
        .execute(&mut *tx)
        .await?;
    let entitlement = reconcile_entitlement_in_tx(&mut tx, user_id).await?;
    tx.commit().await?;
    Ok(entitlement)
}

/// 구독 상태 변경 후 Slack 알림을 발송한다.
/// webhook_url이 비어있으면 스킵. 발송 실패 시 로그만 남기고 에러를 전파하지 않는다.
///
/// nickname, total_pro_users, price는 호출자가 미리 조회하여 전달한다 (레이어 경계 준수).
pub async fn notify_subscription_slack(
    webhook_url: &str,
    user_id: &str,
    before_status: Option<&str>,
    after_status: &str,
    after_last_notification_type: Option<&str>,
    before_last_notification_type: Option<&str>,
    product_id: &str,
    expiration_date: Option<&str>,
    nickname: Option<String>,
    total_pro_users: Option<u32>,
    price: Option<String>,
) {
    // SN-10: webhook URL 비어있으면 스킵
    if webhook_url.is_empty() {
        return;
    }

    let ctx = SubscriptionTransitionContext {
        before_status: before_status.map(str::to_owned),
        after_status: after_status.to_owned(),
        before_last_notification_type: before_last_notification_type.map(str::to_owned),
        after_last_notification_type: after_last_notification_type.map(str::to_owned),
        product_id: product_id.to_owned(),
        expiration_date: expiration_date.map(str::to_owned),
    };

    let Some(notification_type) = detect_subscription_transition(&ctx) else {
        return;
    };

    let message_ctx = SlackMessageContext {
        nickname,
        product_id: product_id.to_string(),
        price,
        pro_user_count: total_pro_users,
        expiration_date: expiration_date.map(str::to_string),
        promo_code: None,
    };
    let message = build_slack_message(&notification_type, &message_ctx);

    // SN-9: 발송 실패 시 로그만
    if let Err(()) = send_slack_notification(webhook_url, &message).await {
        tracing::warn!(
            "Slack notification failed for user {user_id}, type {:?}",
            notification_type
        );
    }
}

/// Slack 알림에 필요한 사용자 정보를 DB에서 조회한다.
async fn fetch_slack_context(
    pool: &PgPool,
    user_id: &str,
    product_id: &str,
) -> (Option<String>, Option<u32>, Option<String>) {
    let nickname = sqlx::query_scalar::<_, String>("SELECT nickname FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .ok()
        .flatten();

    let total_pro_users =
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM entitlements WHERE has_pro = true")
            .fetch_one(pool)
            .await
            .ok()
            .and_then(|n| u32::try_from(n).ok());

    // 가격 (하드코딩 — Firebase의 admin/proPlanPrices 대응)
    let price = if product_id.contains("monthly") {
        Some("3,900원".to_string())
    } else if product_id.contains("yearly") {
        Some("29,000원".to_string())
    } else if product_id.contains("lifetime") {
        Some("39,000원".to_string())
    } else {
        tracing::warn!("Unknown product_id pattern: {product_id}");
        None
    };

    (nickname, total_pro_users, price)
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

async fn fetch_override_record(
    pool: &PgPool,
    user_id: &str,
) -> Result<Option<EntitlementOverrideRecord>, AppError> {
    sqlx::query_as::<_, EntitlementOverrideRecord>(
        "SELECT * FROM entitlement_overrides WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
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
    let subscription_status = subscription
        .as_ref()
        .map(|record| effective_status(&record.status, record.expiration_date));
    let subscription_active = subscription
        .as_ref()
        .map(|record| is_active_subscription_status(&record.status, record.expiration_date))
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
            status: effective_status(&record.status, record.expiration_date),
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

fn is_active_subscription_status(
    status: &SubscriptionStatus,
    expiration_date: Option<DateTime<Utc>>,
) -> bool {
    match status {
        SubscriptionStatus::Lifetime => true,
        SubscriptionStatus::Subscribed | SubscriptionStatus::GracePeriod => match expiration_date {
            Some(date) => date > Utc::now(),
            None => false,
        },
        _ => false,
    }
}

fn effective_status(
    status: &SubscriptionStatus,
    expiration_date: Option<DateTime<Utc>>,
) -> SubscriptionStatus {
    match status {
        SubscriptionStatus::Subscribed | SubscriptionStatus::GracePeriod => match expiration_date {
            Some(date) if date <= Utc::now() => SubscriptionStatus::Expired,
            _ => status.clone(),
        },
        _ => status.clone(),
    }
}

fn is_entitlement_record_stale(record: &EntitlementRecord) -> bool {
    if !record.has_pro {
        return false;
    }
    let now = Utc::now();
    match record.source {
        EntitlementSource::Subscription => {
            if matches!(
                record.subscription_status,
                Some(SubscriptionStatus::Lifetime)
            ) {
                return false;
            }
            match record.expiration_date {
                Some(date) if date <= now => true,
                None => true,
                _ => false,
            }
        }
        EntitlementSource::Override => {
            if let Some(date) = record.override_expires_at {
                if date <= now {
                    return true;
                }
            }
            false
        }
        EntitlementSource::None => false,
    }
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
