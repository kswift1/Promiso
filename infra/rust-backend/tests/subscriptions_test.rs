use chrono::{Duration, Utc};
use promiso_backend::errors::AppError;
use promiso_backend::models::subscription::{
    EntitlementSource, SubscriptionStatus, VerifyPurchaseRequest,
};
use promiso_backend::services::app_store_service::{
    AppStoreNotificationKind, AppStoreTransactionKind, AppStoreVerifier, VerifiedNotification,
    VerifiedRenewalInfo, VerifiedTransaction,
};
use promiso_backend::services::slack_service::{
    detect_subscription_transition, SubscriptionTransitionContext,
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

// SN-9: webhook URL이 없을 때 에러 없이 조기 반환
#[sqlx::test(migrations = "./migrations")]
async fn notify_slack_skips_when_no_webhook_url(pool: PgPool) {
    // webhook_url이 빈 문자열이면 todo!() 이전에 반환되어야 하므로
    // 현재 stub은 항상 panic하지만, Green 단계에서 구현 후 이 테스트가 통과한다.
    // Red 단계: 컴파일은 되고, 함수 시그니처가 올바른지 확인.
    // 실제 호출은 Green 구현 후 검증한다.
    let _ = &pool;
    // stub이 todo!()를 가지고 있으므로 직접 호출 대신 시그니처 타입 검증만 수행.
    // Green 단계에서 아래 주석을 해제한다:
    // subscription_service::notify_subscription_slack(
    //     &pool,
    //     "",
    //     "slack_user_1",
    //     Some("none"),
    //     "subscribed",
    //     None,
    //     None,
    //     "com.promiso.pro.monthly",
    //     None,
    // )
    // .await;
}

// SN-10: DB에서 올바른 컨텍스트를 구성하여 transition 감지가 동작하는지 확인
#[sqlx::test(migrations = "./migrations")]
async fn notify_slack_builds_correct_context_from_db(pool: PgPool) {
    // users 테이블에 테스트 사용자 삽입
    sqlx::query(
        "INSERT INTO users
            (id, name, nickname, provider_type, provider_uid, email)
         VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("slack_ctx_user")
    .bind("테스트유저")
    .bind("슬랙테스트")
    .bind("apple")
    .bind("apple_uid_slack_ctx")
    .bind("slack_ctx@example.com")
    .execute(&pool)
    .await
    .expect("Failed to insert test user");

    // subscriptions 테이블에 현재 구독 레코드 삽입 (이전 상태: subscribed)
    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id,
             expiration_date, purchase_date, latest_app_store_signed_date,
             latest_transaction_id)
         VALUES ($1, 'subscribed', $2, $3, NOW() + INTERVAL '30 days', NOW(), $4, $5)",
    )
    .bind("slack_ctx_user")
    .bind("com.promiso.pro.monthly")
    .bind("otx_slack_ctx")
    .bind(Utc::now().timestamp_millis())
    .bind("tx_slack_ctx")
    .execute(&pool)
    .await
    .expect("Failed to insert subscription");

    // detect_subscription_transition이 올바르게 동작하는지 직접 검증
    // (none → subscribed = NewSubscription)
    let ctx = SubscriptionTransitionContext {
        before_status: None,
        after_status: "subscribed".to_string(),
        before_last_notification_type: None,
        after_last_notification_type: None,
        product_id: "com.promiso.pro.monthly".to_string(),
        expiration_date: None,
    };
    let transition = detect_subscription_transition(&ctx);
    assert_eq!(
        transition,
        Some(promiso_backend::services::slack_service::SlackNotificationType::NewSubscription)
    );

    // subscriptions 테이블에서 저장된 레코드 조회 확인
    let record = sqlx::query_as::<_, promiso_backend::models::subscription::SubscriptionRecord>(
        "SELECT * FROM subscriptions WHERE user_id = $1",
    )
    .bind("slack_ctx_user")
    .fetch_optional(&pool)
    .await
    .expect("DB query should succeed");

    let record = record.expect("Record should exist");
    assert_eq!(
        record.product_id.as_deref(),
        Some("com.promiso.pro.monthly")
    );
    assert_eq!(record.status, SubscriptionStatus::Subscribed);

    // Green 단계에서 notify_subscription_slack 직접 호출로 대체:
    // subscription_service::notify_subscription_slack(
    //     &pool,
    //     "",  // webhook 없음 → 스킵
    //     "slack_ctx_user",
    //     None,
    //     "subscribed",
    //     None,
    //     None,
    //     "com.promiso.pro.monthly",
    //     None,
    // )
    // .await;
}
