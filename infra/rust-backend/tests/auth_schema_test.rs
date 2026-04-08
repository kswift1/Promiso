use sqlx::PgPool;

#[sqlx::test(migrations = "./migrations")]
async fn auth_accounts_enforces_unique_provider_identity(pool: PgPool) {
    sqlx::query(
        "INSERT INTO auth_accounts (user_id, provider_type, provider_uid, email) \
         VALUES ($1, 'google', 'provider-123', 'first@example.com')",
    )
    .bind("user_auth_1")
    .execute(&pool)
    .await
    .unwrap();

    let duplicate = sqlx::query(
        "INSERT INTO auth_accounts (user_id, provider_type, provider_uid, email) \
         VALUES ($1, 'google', 'provider-123', 'second@example.com')",
    )
    .bind("user_auth_2")
    .execute(&pool)
    .await;

    assert!(duplicate.is_err());
}

#[sqlx::test(migrations = "./migrations")]
async fn auth_sessions_requires_existing_auth_account(pool: PgPool) {
    let result = sqlx::query(
        "INSERT INTO auth_sessions (user_id, refresh_token_hash, device_id, expires_at) \
         VALUES ($1, $2, $3, NOW() + INTERVAL '30 days')",
    )
    .bind("missing-user")
    .bind("hash")
    .bind("device-id")
    .execute(&pool)
    .await;

    assert!(result.is_err());
}

#[sqlx::test(migrations = "./migrations")]
async fn app_config_seed_row_exists(pool: PgPool) {
    let row: (String, String,) = sqlx::query_as(
        "SELECT force_update_version, recommended_version FROM app_config WHERE singleton = TRUE",
    )
    .fetch_one(&pool)
    .await
    .unwrap();

    assert_eq!(row.0, "0.0.0");
    assert_eq!(row.1, "0.0.0");
}
