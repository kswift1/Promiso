//! Subscription backfill runner tests
//!
//! 목표:
//! - Firestore export를 JSONL로 준비하면 Rust authority로 한 번에 적재할 수 있어야 한다.
//! - 입력은 Firestore 필드명 camelCase를 그대로 받아야 한다.
//! - backfill 이후 entitlements는 원본 복사가 아니라 재계산되어야 한다.

use promiso_backend::errors::AppError;
use promiso_backend::models::subscription::EntitlementSource;
use promiso_backend::services::subscription_backfill_service::run_jsonl_backfill;
use sqlx::PgPool;

#[sqlx::test(migrations = "./migrations")]
async fn run_jsonl_backfill_imports_firestore_rows_and_recomputes_entitlements(pool: PgPool) {
    let subscriptions_jsonl = r#"{"userId":"backfill_cli_sub","status":"subscribed","productId":"com.promiso.pro.monthly","originalTransactionId":"otx_cli_sub","latestAppStoreSignedDate":1773218124999}
"#;
    let owners_jsonl = r#"{"originalTransactionId":"otx_cli_sub","userId":"backfill_cli_sub","productId":"com.promiso.pro.monthly"}
"#;
    let overrides_jsonl = r#"{"userId":"backfill_cli_override","isActive":true,"overrideType":"manual_pro_grant","reason":"support grant","createdBy":"admin_cli"}
"#;

    let summary = run_jsonl_backfill(
        &pool,
        subscriptions_jsonl,
        owners_jsonl,
        overrides_jsonl,
    )
    .await
    .expect("jsonl backfill should succeed");

    assert_eq!(summary.subscriptions, 1);
    assert_eq!(summary.subscription_owners, 1);
    assert_eq!(summary.entitlement_overrides, 1);
    assert_eq!(summary.entitlements_recomputed, 2);

    let subscription_entitlement: (bool, EntitlementSource) = sqlx::query_as(
        "SELECT has_pro, source
         FROM entitlements
         WHERE user_id = $1",
    )
    .bind("backfill_cli_sub")
    .fetch_one(&pool)
    .await
    .expect("subscription-backed entitlement should exist");

    let override_entitlement: (bool, EntitlementSource) = sqlx::query_as(
        "SELECT has_pro, source
         FROM entitlements
         WHERE user_id = $1",
    )
    .bind("backfill_cli_override")
    .fetch_one(&pool)
    .await
    .expect("override-backed entitlement should exist");

    assert_eq!(subscription_entitlement, (true, EntitlementSource::Subscription));
    assert_eq!(override_entitlement, (true, EntitlementSource::Override));
}

#[sqlx::test(migrations = "./migrations")]
async fn run_jsonl_backfill_rejects_invalid_json(pool: PgPool) {
    let error = run_jsonl_backfill(
        &pool,
        "{\"userId\":\"broken\"",
        "",
        "",
    )
    .await
    .expect_err("invalid json should fail");

    assert!(matches!(error, AppError::BadRequest(_)));
}
