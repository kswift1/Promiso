use chrono::{Duration, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::models::subscription::{
    EntitlementSource, SubscriptionStatus, VerifyPurchaseRequest,
};
use promiso_backend::services::app_store_service::{
    AppStoreNotificationKind, AppStoreTransactionKind, AppStoreVerifier, VerifiedNotification,
    VerifiedRenewalInfo, VerifiedTransaction,
};
use promiso_backend::services::subscription_service;
use sqlx::PgPool;

struct MockAppStoreVerifier {
    transaction: VerifiedTransaction,
    notification: Option<VerifiedNotification>,
}

impl AppStoreVerifier for MockAppStoreVerifier {
    fn verify_transaction(
        &self,
        _signed_transaction: &str,
    ) -> Result<VerifiedTransaction, AppError> {
        Ok(self.transaction.clone())
    }

    fn verify_notification(&self, _signed_payload: &str) -> Result<VerifiedNotification, AppError> {
        self.notification
            .clone()
            .ok_or_else(|| AppError::Internal("notification payload missing".to_string()))
    }
}

async fn insert_override(
    pool: &PgPool,
    user_id: &str,
    is_active: bool,
    override_type: &str,
    expires_at: Option<chrono::DateTime<Utc>>,
) {
    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, expires_at, created_by)
         VALUES ($1, $2, $3, $4, 'admin_test')",
    )
    .bind(user_id)
    .bind(is_active)
    .bind(override_type)
    .bind(expires_at)
    .execute(pool)
    .await
    .expect("Failed to insert override");
}

fn make_transaction(
    original_transaction_id: &str,
    product_id: &str,
    signed_date: chrono::DateTime<Utc>,
    expires_date: Option<chrono::DateTime<Utc>>,
) -> VerifiedTransaction {
    VerifiedTransaction {
        original_transaction_id: original_transaction_id.to_string(),
        transaction_id: Some(format!("tx_{original_transaction_id}")),
        product_id: product_id.to_string(),
        purchase_date: Some(signed_date - Duration::minutes(5)),
        expires_date,
        signed_date: Some(signed_date),
        revocation_date: None,
        transaction_kind: Some(AppStoreTransactionKind::AutoRenewableSubscription),
        offer_type: None,
        offer_identifier: None,
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn verify_purchase_creates_subscription_and_entitlement(pool: PgPool) {
    let now = Utc::now();
    let verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_1",
            "com.promiso.pro.monthly",
            now,
            Some(now + Duration::days(30)),
        ),
        notification: None,
    };

    let response = subscription_service::verify_purchase(
        &pool,
        "user_sub_1",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &verifier,
    )
    .await
    .expect("verify_purchase should succeed");

    assert!(response.success);
    assert_eq!(
        response.subscription_status.status,
        SubscriptionStatus::Subscribed
    );

    let entitlement = subscription_service::get_entitlement(&pool, "user_sub_1")
        .await
        .expect("entitlement should exist");
    assert!(entitlement.has_pro);
    assert_eq!(entitlement.source, EntitlementSource::Subscription);
    assert_eq!(
        entitlement.subscription_status,
        Some(SubscriptionStatus::Subscribed)
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn verify_purchase_product_mismatch_rejected(pool: PgPool) {
    let now = Utc::now();
    let verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_2",
            "com.promiso.pro.yearly",
            now,
            Some(now + Duration::days(365)),
        ),
        notification: None,
    };

    let result = subscription_service::verify_purchase(
        &pool,
        "user_sub_2",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &verifier,
    )
    .await;

    assert!(matches!(result, Err(AppError::BadRequest(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn verify_purchase_stale_signed_date_ignored(pool: PgPool) {
    let now = Utc::now();
    let fresh_verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_3",
            "com.promiso.pro.monthly",
            now,
            Some(now + Duration::days(30)),
        ),
        notification: None,
    };

    subscription_service::verify_purchase(
        &pool,
        "user_sub_3",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction.fresh".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &fresh_verifier,
    )
    .await
    .expect("fresh verify should succeed");

    let stale_verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_3",
            "com.promiso.pro.monthly",
            now - Duration::days(1),
            Some(now - Duration::hours(1)),
        ),
        notification: None,
    };

    let response = subscription_service::verify_purchase(
        &pool,
        "user_sub_3",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction.stale".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &stale_verifier,
    )
    .await
    .expect("stale verify should return current state");

    assert_eq!(
        response.subscription_status.status,
        SubscriptionStatus::Subscribed
    );
    assert!(
        response
            .subscription_status
            .expiration_date
            .expect("expiration should exist")
            > now
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn verify_purchase_force_transfer_expires_previous_owner(pool: PgPool) {
    let now = Utc::now();
    let verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_transfer",
            "com.promiso.pro.monthly",
            now,
            Some(now + Duration::days(30)),
        ),
        notification: None,
    };

    subscription_service::verify_purchase(
        &pool,
        "owner_a",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction.owner_a".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &verifier,
    )
    .await
    .expect("initial verify should succeed");

    let result = subscription_service::verify_purchase(
        &pool,
        "owner_b",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction.owner_b".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: Some(true),
        },
        &verifier,
    )
    .await
    .expect("force transfer should succeed");

    assert_eq!(
        result.subscription_status.status,
        SubscriptionStatus::Subscribed
    );

    let previous_owner = subscription_service::get_status(&pool, "owner_a")
        .await
        .expect("previous owner should still have a row");
    assert_eq!(previous_owner.status, SubscriptionStatus::Expired);

    let previous_entitlement = subscription_service::get_entitlement(&pool, "owner_a")
        .await
        .expect("previous owner entitlement should exist");
    assert!(!previous_entitlement.has_pro);
}

#[sqlx::test(migrations = "./migrations")]
async fn entitlement_reconcile_uses_override_when_subscription_missing(pool: PgPool) {
    insert_override(
        &pool,
        "override_user",
        true,
        "manual_pro_grant",
        Some(Utc::now() + Duration::days(7)),
    )
    .await;

    let entitlement = subscription_service::reconcile_entitlement(&pool, "override_user")
        .await
        .expect("override entitlement should reconcile");

    assert!(entitlement.has_pro);
    assert_eq!(entitlement.source, EntitlementSource::Override);
    assert!(entitlement.override_active);
    assert_eq!(
        entitlement.override_type.as_deref(),
        Some("manual_pro_grant")
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn apple_notification_moves_to_grace_period(pool: PgPool) {
    let now = Utc::now();
    let base_verifier = MockAppStoreVerifier {
        transaction: make_transaction(
            "otx_notify",
            "com.promiso.pro.monthly",
            now,
            Some(now + Duration::days(30)),
        ),
        notification: None,
    };

    subscription_service::verify_purchase(
        &pool,
        "notify_user",
        VerifyPurchaseRequest {
            transaction_jws: "signed.transaction.notify".to_string(),
            product_id: "com.promiso.pro.monthly".to_string(),
            force_transfer: None,
        },
        &base_verifier,
    )
    .await
    .expect("initial verify should succeed");

    let notification_verifier = MockAppStoreVerifier {
        transaction: base_verifier.transaction.clone(),
        notification: Some(VerifiedNotification {
            notification_type: AppStoreNotificationKind::DidFailToRenew,
            signed_date: Some(now + Duration::days(1)),
            transaction: VerifiedTransaction {
                expires_date: Some(now),
                ..base_verifier.transaction.clone()
            },
            renewal_info: Some(VerifiedRenewalInfo {
                signed_date: Some(now + Duration::days(1)),
                grace_period_expires_date: Some(now + Duration::days(3)),
                renewal_date: None,
                is_in_billing_retry_period: true,
            }),
        }),
    };

    subscription_service::handle_apple_notification(
        &pool,
        promiso_backend::models::subscription::AppleNotificationRequest {
            signed_payload: "signed.notification".to_string(),
        },
        &notification_verifier,
    )
    .await
    .expect("notification should succeed");

    let status = subscription_service::get_status(&pool, "notify_user")
        .await
        .expect("status should exist");
    assert_eq!(status.status, SubscriptionStatus::GracePeriod);
}
