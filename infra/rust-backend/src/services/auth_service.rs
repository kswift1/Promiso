use chrono::{Duration, Utc};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::ServerAuth;
use crate::models::auth::{
    AuthLoginResponse, AuthSubjectResponse, AuthUserResponse, CreateSessionInput,
    RefreshSessionInput, SessionTokensResponse,
};
use crate::services::provider_verifier::VerifiedProviderProfile;

const DEFAULT_REFRESH_TTL_DAYS: i64 = 30;

struct AuthAccountRow {
    email: Option<String>,
}

#[derive(sqlx::FromRow)]
struct SessionLookupRow {
    id: Uuid,
    user_id: String,
    email: Option<String>,
    device_id: String,
}

#[derive(sqlx::FromRow)]
struct AuthSubjectRow {
    user_id: String,
    email: Option<String>,
    provider_type: String,
    display_name: Option<String>,
    profile_image_url: Option<String>,
    has_profile: bool,
}

fn hash_refresh_token(refresh_token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(refresh_token.as_bytes());
    hex::encode(hasher.finalize())
}

fn generate_refresh_token() -> String {
    format!("rt_{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple())
}

async fn load_auth_account(
    tx: &mut Transaction<'_, Postgres>,
    user_id: &str,
) -> Result<AuthAccountRow, AppError> {
    sqlx::query_as::<_, (Option<String>,)>("SELECT email FROM auth_accounts WHERE user_id = $1")
        .bind(user_id)
        .fetch_optional(tx.as_mut())
        .await?
        .map(|row| AuthAccountRow { email: row.0 })
        .ok_or_else(|| AppError::NotFound("Auth account not found".to_string()))
}

fn issue_tokens(
    server_auth: &ServerAuth,
    user_id: &str,
    email: Option<&str>,
    session_id: Uuid,
    refresh_token: String,
) -> Result<SessionTokensResponse, AppError> {
    let access_token = server_auth.issue_access_token(user_id, email, Some(session_id))?;
    Ok(SessionTokensResponse {
        access_token,
        refresh_token,
        expires_at: server_auth.access_token_expires_at(),
    })
}

pub async fn create_session(
    pool: &PgPool,
    server_auth: &ServerAuth,
    input: CreateSessionInput,
) -> Result<SessionTokensResponse, AppError> {
    let mut tx = pool.begin().await?;
    let auth_account = load_auth_account(&mut tx, &input.user_id).await?;

    let refresh_token = generate_refresh_token();
    let refresh_token_hash = hash_refresh_token(&refresh_token);
    let expires_at = Utc::now() + Duration::days(DEFAULT_REFRESH_TTL_DAYS);

    let session_id: (Uuid,) = sqlx::query_as(
        "INSERT INTO auth_sessions \
         (user_id, refresh_token_hash, device_id, platform, app_version, user_agent, expires_at) \
         VALUES ($1, $2, $3, $4, $5, $6, $7) \
         RETURNING id",
    )
    .bind(&input.user_id)
    .bind(&refresh_token_hash)
    .bind(&input.device_id)
    .bind(&input.platform)
    .bind(&input.app_version)
    .bind(&input.user_agent)
    .bind(expires_at)
    .fetch_one(tx.as_mut())
    .await?;

    tx.commit().await?;

    issue_tokens(
        server_auth,
        &input.user_id,
        auth_account.email.as_deref(),
        session_id.0,
        refresh_token,
    )
}

pub async fn refresh_session(
    pool: &PgPool,
    server_auth: &ServerAuth,
    input: RefreshSessionInput,
) -> Result<SessionTokensResponse, AppError> {
    let mut tx = pool.begin().await?;
    let refresh_token_hash = hash_refresh_token(&input.refresh_token);

    let session = sqlx::query_as::<_, SessionLookupRow>(
        "SELECT s.id, s.user_id, a.email, s.device_id \
         FROM auth_sessions s \
         JOIN auth_accounts a ON a.user_id = s.user_id \
         WHERE s.refresh_token_hash = $1 \
           AND s.revoked_at IS NULL \
           AND s.expires_at > NOW() \
         FOR UPDATE",
    )
    .bind(&refresh_token_hash)
    .fetch_optional(tx.as_mut())
    .await?
    .ok_or_else(|| AppError::Unauthorized("Invalid refresh token".to_string()))?;

    if session.device_id != input.device_id {
        return Err(AppError::Unauthorized(
            "Refresh token device mismatch".to_string(),
        ));
    }

    let rotated_refresh_token = generate_refresh_token();
    let rotated_hash = hash_refresh_token(&rotated_refresh_token);
    let next_expires_at = Utc::now() + Duration::days(DEFAULT_REFRESH_TTL_DAYS);

    sqlx::query(
        "UPDATE auth_sessions \
         SET refresh_token_hash = $1, \
             last_used_at = NOW(), \
             expires_at = $2, \
             updated_at = NOW() \
         WHERE id = $3",
    )
    .bind(&rotated_hash)
    .bind(next_expires_at)
    .bind(session.id)
    .execute(tx.as_mut())
    .await?;

    tx.commit().await?;

    issue_tokens(
        server_auth,
        &session.user_id,
        session.email.as_deref(),
        session.id,
        rotated_refresh_token,
    )
}

pub async fn revoke_session(pool: &PgPool, refresh_token: &str) -> Result<(), AppError> {
    let refresh_token_hash = hash_refresh_token(refresh_token);
    sqlx::query(
        "UPDATE auth_sessions \
         SET revoked_at = NOW(), updated_at = NOW() \
         WHERE refresh_token_hash = $1 AND revoked_at IS NULL",
    )
    .bind(refresh_token_hash)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn revoke_all_sessions(pool: &PgPool, user_id: &str) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE auth_sessions \
         SET revoked_at = NOW(), updated_at = NOW() \
         WHERE user_id = $1 AND revoked_at IS NULL",
    )
    .bind(user_id)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn revoke_session_by_id(pool: &PgPool, session_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE auth_sessions \
         SET revoked_at = NOW(), updated_at = NOW() \
         WHERE id = $1 AND revoked_at IS NULL",
    )
    .bind(session_id)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn get_auth_subject(pool: &PgPool, user_id: &str) -> Result<AuthSubjectResponse, AppError> {
    let row = sqlx::query_as::<_, AuthSubjectRow>(
        "SELECT \
            a.user_id, \
            a.email, \
            a.provider_type, \
            COALESCE(u.name, a.display_name) AS display_name, \
            COALESCE(u.profile_url, a.profile_image_url) AS profile_image_url, \
            (u.id IS NOT NULL) AS has_profile \
         FROM auth_accounts a \
         LEFT JOIN users u ON u.id = a.user_id \
         WHERE a.user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Auth account not found".to_string()))?;

    Ok(AuthSubjectResponse {
        user_id: row.user_id,
        email: row.email,
        provider: row.provider_type,
        display_name: row.display_name,
        profile_image_url: row.profile_image_url,
        has_profile: row.has_profile,
    })
}

pub async fn sign_in_with_verified_provider(
    pool: &PgPool,
    server_auth: &ServerAuth,
    profile: VerifiedProviderProfile,
    device_id: String,
    app_version: Option<String>,
    user_agent: Option<String>,
) -> Result<AuthLoginResponse, AppError> {
    let generated_user_id = format!("user_{}", Uuid::new_v4().simple());

    let auth_account: (String,) = sqlx::query_as(
        "INSERT INTO auth_accounts \
         (user_id, provider_type, provider_uid, email, display_name, profile_image_url, last_login_at) \
         VALUES ($1, $2, $3, $4, $5, $6, NOW()) \
         ON CONFLICT (provider_type, provider_uid) DO UPDATE SET \
            email = COALESCE(EXCLUDED.email, auth_accounts.email), \
            display_name = COALESCE(EXCLUDED.display_name, auth_accounts.display_name), \
            profile_image_url = COALESCE(EXCLUDED.profile_image_url, auth_accounts.profile_image_url), \
            last_login_at = NOW(), \
            updated_at = NOW() \
         RETURNING user_id",
    )
    .bind(&generated_user_id)
    .bind(&profile.provider_type)
    .bind(&profile.provider_uid)
    .bind(&profile.email)
    .bind(&profile.display_name)
    .bind(&profile.profile_image_url)
    .fetch_one(pool)
    .await?;

    let subject = get_auth_subject(pool, &auth_account.0).await?;
    let tokens = create_session(
        pool,
        server_auth,
        CreateSessionInput {
            user_id: subject.user_id.clone(),
            device_id,
            platform: "ios".to_string(),
            app_version,
            user_agent,
        },
    )
    .await?;

    Ok(AuthLoginResponse {
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expires_at: tokens.expires_at,
        user: AuthUserResponse {
            user_id: subject.user_id,
            email: subject.email,
            provider: subject.provider,
            display_name: subject.display_name,
            profile_image_url: subject.profile_image_url,
        },
        has_profile: subject.has_profile,
    })
}
