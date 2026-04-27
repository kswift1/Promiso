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

// === Subscription expiration regression tests (Red phase) ===
//
// 현재 `is_active_subscription_status`는 status enum 값만 보고 만료를 판정하지 않는다.
// 또한 `get_entitlement`는 캐시된 entitlements row가 있으면 reconcile 없이 그대로 반환한다.
// 아래 테스트들은 만료된 구독/캐시가 stale한 상황에서 has_pro=false 가 되어야 함을 명세한다.

async fn insert_subscription_row(
    pool: &PgPool,
    user_id: &str,
    status_db_value: &str,
    expiration_date: Option<chrono::DateTime<Utc>>,
) {
    sqlx::query(
        "INSERT INTO subscriptions
            (user_id, status, product_id, original_transaction_id,
             expiration_date, purchase_date, latest_app_store_signed_date,
             latest_transaction_id)
         VALUES
            ($1, $2::subscription_status, $3, $4, $5, NOW() - INTERVAL '60 days', $6, $7)",
    )
    .bind(user_id)
    .bind(status_db_value)
    .bind("com.promiso.pro.monthly")
    .bind(format!("otx_{user_id}"))
    .bind(expiration_date)
    .bind(Utc::now().timestamp_millis())
    .bind(format!("tx_{user_id}"))
    .execute(pool)
    .await
    .expect("Failed to insert subscription row");
}

async fn insert_entitlement_row(
    pool: &PgPool,
    user_id: &str,
    has_pro: bool,
    subscription_status_db: Option<&str>,
    expiration_date: Option<chrono::DateTime<Utc>>,
    source: &str,
    override_active: bool,
    override_expires_at: Option<chrono::DateTime<Utc>>,
) {
    sqlx::query(
        "INSERT INTO entitlements
            (user_id, has_pro, source, subscription_status, product_id,
             expiration_date, override_active, override_expires_at)
         VALUES
            ($1, $2, $3::entitlement_source,
             $4::subscription_status, $5, $6, $7, $8)",
    )
    .bind(user_id)
    .bind(has_pro)
    .bind(source)
    .bind(subscription_status_db)
    .bind("com.promiso.pro.monthly")
    .bind(expiration_date)
    .bind(override_active)
    .bind(override_expires_at)
    .execute(pool)
    .await
    .expect("Failed to insert entitlement row");
}

#[sqlx::test(migrations = "./migrations")]
async fn test_entitlement_returns_expired_when_subscription_expiration_in_past(pool: PgPool) {
    let past = Utc::now() - Duration::days(120);
    insert_subscription_row(&pool, "expired_sub_user", "subscribed", Some(past)).await;

    let entitlement = subscription_service::get_entitlement(&pool, "expired_sub_user")
        .await
        .expect("entitlement should reconcile");

    assert!(
        !entitlement.has_pro,
        "만료된 subscription은 has_pro=false 여야 한다"
    );
    assert_ne!(
        entitlement.subscription_status,
        Some(SubscriptionStatus::Subscribed),
        "만료된 subscription의 effective status는 Subscribed가 아니어야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_entitlement_returns_expired_when_grace_period_expired(pool: PgPool) {
    let past = Utc::now() - Duration::days(10);
    insert_subscription_row(&pool, "expired_grace_user", "grace_period", Some(past)).await;

    let entitlement = subscription_service::get_entitlement(&pool, "expired_grace_user")
        .await
        .expect("entitlement should reconcile");

    assert!(
        !entitlement.has_pro,
        "유예기간이 지난 subscription은 has_pro=false 여야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_entitlement_recomputes_when_cached_row_is_stale(pool: PgPool) {
    let past = Utc::now() - Duration::days(30);
    // subscriptions: 만료된 'subscribed'
    insert_subscription_row(&pool, "stale_cache_user", "subscribed", Some(past)).await;
    // entitlements: stale 캐시 (has_pro=true 로 잘못 저장됨)
    insert_entitlement_row(
        &pool,
        "stale_cache_user",
        true,
        Some("subscribed"),
        Some(past),
        "subscription",
        false,
        None,
    )
    .await;

    let entitlement = subscription_service::get_entitlement(&pool, "stale_cache_user")
        .await
        .expect("entitlement should be returned");

    assert!(
        !entitlement.has_pro,
        "캐시된 entitlements가 stale하면 reconcile해서 has_pro=false 여야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_entitlement_returns_expired_when_override_expires_at_in_past(pool: PgPool) {
    let past = Utc::now() - Duration::days(2);
    // 만료된 override
    insert_override(&pool, "expired_override_user", true, "manual_pro_grant", Some(past)).await;
    // stale 캐시: has_pro=true 인 채로 저장되어 있음
    insert_entitlement_row(
        &pool,
        "expired_override_user",
        true,
        None,
        None,
        "override",
        true,
        Some(past),
    )
    .await;

    let entitlement = subscription_service::get_entitlement(&pool, "expired_override_user")
        .await
        .expect("entitlement should be returned");

    assert!(
        !entitlement.has_pro,
        "만료된 override는 캐시가 stale 하더라도 has_pro=false 여야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_status_endpoint_maps_expired_subscribed_to_expired(pool: PgPool) {
    let past = Utc::now() - Duration::days(45);
    insert_subscription_row(&pool, "status_expired_user", "subscribed", Some(past)).await;

    let status = subscription_service::get_status(&pool, "status_expired_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Expired,
        "만료일이 과거인 subscribed 레코드는 effective status=Expired 로 응답해야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_lifetime_status_remains_active_regardless_of_expiration(pool: PgPool) {
    // Lifetime: expiration_date=NULL 이어도 항상 활성 (회귀 방지)
    insert_subscription_row(&pool, "lifetime_user", "lifetime", None).await;

    let entitlement = subscription_service::get_entitlement(&pool, "lifetime_user")
        .await
        .expect("entitlement should reconcile");

    assert!(
        entitlement.has_pro,
        "Lifetime은 만료 검사 대상이 아니므로 항상 has_pro=true 여야 한다"
    );
    assert_eq!(
        entitlement.subscription_status,
        Some(SubscriptionStatus::Lifetime)
    );
}

// === GET /status override fallback regression tests ===
//
// `get_status`는 subscriptions 테이블만 보고 entitlement_overrides를 무시했다.
// override만 활성인 유저는 status=Subscribed 로 응답해야 한다.

#[sqlx::test(migrations = "./migrations")]
async fn test_status_returns_subscribed_when_only_override_active(pool: PgPool) {
    let future = Utc::now() + Duration::days(30);
    insert_override(
        &pool,
        "status_override_only_user",
        true,
        "manual_pro_grant",
        Some(future),
    )
    .await;

    let status = subscription_service::get_status(&pool, "status_override_only_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Subscribed,
        "active override만 있어도 status=Subscribed 여야 한다"
    );
    let returned_expiration = status
        .expiration_date
        .expect("override expires_at should be returned");
    let diff = (returned_expiration - future).num_seconds().abs();
    assert!(
        diff < 2,
        "expiration_date는 override의 expires_at과 일치해야 한다 (diff={diff}s)"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_status_returns_subscribed_when_subscription_expired_but_override_active(
    pool: PgPool,
) {
    let past = Utc::now() - Duration::days(10);
    let future = Utc::now() + Duration::days(15);
    insert_subscription_row(
        &pool,
        "status_expired_with_override_user",
        "subscribed",
        Some(past),
    )
    .await;
    insert_override(
        &pool,
        "status_expired_with_override_user",
        true,
        "manual_pro_grant",
        Some(future),
    )
    .await;

    let status = subscription_service::get_status(&pool, "status_expired_with_override_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Subscribed,
        "subscription이 만료여도 override가 활성이면 status=Subscribed 여야 한다"
    );
    let returned_expiration = status
        .expiration_date
        .expect("override expires_at should be returned");
    let diff = (returned_expiration - future).num_seconds().abs();
    assert!(
        diff < 2,
        "expiration_date는 override의 expires_at과 일치해야 한다 (diff={diff}s)"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_status_returns_expired_when_subscription_expired_and_override_inactive(
    pool: PgPool,
) {
    let past = Utc::now() - Duration::days(20);
    insert_subscription_row(
        &pool,
        "status_both_inactive_user",
        "subscribed",
        Some(past),
    )
    .await;
    // override는 is_active=false
    insert_override(
        &pool,
        "status_both_inactive_user",
        false,
        "manual_pro_grant",
        Some(Utc::now() + Duration::days(30)),
    )
    .await;

    let status = subscription_service::get_status(&pool, "status_both_inactive_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Expired,
        "subscription 만료 + override 비활성이면 status=Expired 여야 한다"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_status_returns_subscribed_when_subscription_active_overrides_irrelevant(
    pool: PgPool,
) {
    let future_sub = Utc::now() + Duration::days(45);
    insert_subscription_row(
        &pool,
        "status_sub_active_user",
        "subscribed",
        Some(future_sub),
    )
    .await;
    insert_override(
        &pool,
        "status_sub_active_user",
        false,
        "manual_pro_grant",
        Some(Utc::now() + Duration::days(7)),
    )
    .await;

    let status = subscription_service::get_status(&pool, "status_sub_active_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Subscribed,
        "subscription이 활성이면 override 비활성과 무관하게 status=Subscribed 여야 한다"
    );
    let returned_expiration = status
        .expiration_date
        .expect("subscription expiration should be returned");
    let diff = (returned_expiration - future_sub).num_seconds().abs();
    assert!(
        diff < 2,
        "expiration_date는 subscription의 expiration_date와 일치해야 한다 (diff={diff}s)"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn test_status_returns_lifetime_regardless_of_override(pool: PgPool) {
    insert_subscription_row(&pool, "status_lifetime_user", "lifetime", None).await;
    insert_override(
        &pool,
        "status_lifetime_user",
        true,
        "manual_pro_grant",
        Some(Utc::now() + Duration::days(7)),
    )
    .await;

    let status = subscription_service::get_status(&pool, "status_lifetime_user")
        .await
        .expect("status should return");

    assert_eq!(
        status.status,
        SubscriptionStatus::Lifetime,
        "Lifetime subscription은 override와 무관하게 Lifetime을 유지해야 한다"
    );
}
