use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{PgPool, Postgres, QueryBuilder};
use std::str::FromStr;

use crate::errors::AppError;

const DEFAULT_PROPLAN_MONTHLY_PRICE: i64 = 3900;
const DEFAULT_PROPLAN_YEARLY_PRICE: i64 = 39000;
const DEFAULT_PROPLAN_LIFETIME_PRICE: i64 = 59000;

#[derive(Debug, Clone, Copy, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "admin_role", rename_all = "lowercase")]
enum AdminRole {
    Owner,
    Support,
    Marketer,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct AdminUserRecord {
    role: AdminRole,
    enabled: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DashboardSummary {
    pub total_users: i64,
    pub pro_users: i64,
    pub free_users: i64,
    pub active_overrides: i64,
    pub total_admins: i64,
    pub push_job_count: i64,
    pub audit_log_count: i64,
    pub remote_config_version: Option<String>,
    pub remote_config_updated_at: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSummary {
    pub user_id: String,
    pub name: Option<String>,
    pub nickname: Option<String>,
    pub email: Option<String>,
    pub group_count: i64,
    pub device_count: i64,
    pub personal_event_count: i64,
    pub subscription_status: Option<String>,
    pub override_active: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSummaryResult {
    pub results: Vec<UserSummary>,
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubscriptionSnapshot {
    pub status: Option<String>,
    pub product_id: Option<String>,
    pub expiration_date: Option<DateTime<Utc>>,
    pub purchase_date: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OverrideSnapshot {
    pub is_active: bool,
    #[serde(rename = "type")]
    pub override_type: Option<String>,
    pub reason: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
    pub created_by: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
    pub revoked_by: Option<String>,
    pub revoked_reason: Option<String>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditLog {
    pub id: String,
    pub actor_id: Option<String>,
    pub action: Option<String>,
    pub target_type: Option<String>,
    pub target_id: Option<String>,
    pub before: Option<serde_json::Value>,
    pub after: Option<serde_json::Value>,
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserTimeline {
    pub summary: UserSummary,
    pub subscription: SubscriptionSnapshot,
    pub r#override: Option<OverrideSnapshot>,
    pub audit_logs: Vec<AuditLog>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GrantEntitlementOverrideRequest {
    pub user_id: String,
    pub reason: String,
    pub expires_at: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevokeEntitlementOverrideRequest {
    pub user_id: String,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanBreakdownItem {
    pub count: i64,
    pub revenue: i64,
    pub total_revenue: i64,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanBreakdown {
    pub monthly: ProPlanBreakdownItem,
    pub yearly: ProPlanBreakdownItem,
    pub lifetime: ProPlanBreakdownItem,
    #[serde(rename = "override")]
    pub r#override: ProPlanBreakdownItem,
    pub grace_period: ProPlanBreakdownItem,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanOverview {
    pub total_users: i64,
    pub pro_users: i64,
    pub pro_subscription_users: i64,
    pub pro_override_users: i64,
    pub free_users: i64,
    pub pro_rate: f64,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanRevenue {
    #[serde(rename = "estimatedMRR")]
    pub estimated_mrr: i64,
    pub total_lifetime_revenue: i64,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanPrices {
    pub monthly: i64,
    pub yearly: i64,
    pub lifetime: i64,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanCouponSummary {
    pub total: i64,
    pub available: i64,
    pub redeemed: i64,
    pub expired: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanActivity {
    pub user_id: String,
    pub r#type: String,
    pub product_id: Option<String>,
    pub timestamp: String,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OfferCodeRedemption {
    pub user_id: String,
    pub offer_identifier: String,
    pub redeemed_at: DateTime<Utc>,
    pub product_id: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OfferCodesSummary {
    pub total_redemptions: i64,
    pub recent_redemptions: Vec<OfferCodeRedemption>,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProPlanDashboard {
    pub overview: ProPlanOverview,
    pub breakdown: ProPlanBreakdown,
    pub revenue: ProPlanRevenue,
    pub prices: ProPlanPrices,
    pub coupons: ProPlanCouponSummary,
    pub recent_activities: Vec<ProPlanActivity>,
    pub offer_codes: OfferCodesSummary,
}

pub async fn build_dashboard_summary(
    pool: &PgPool,
    actor_id: &str,
) -> Result<DashboardSummary, AppError> {
    require_admin(
        pool,
        actor_id,
        &[AdminRole::Owner, AdminRole::Support, AdminRole::Marketer],
    )
    .await?;

    let total_users: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    let pro_users: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM entitlements WHERE has_pro = TRUE")
            .fetch_one(pool)
            .await?;
    let active_overrides: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM entitlement_overrides
         WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at >= NOW())",
    )
    .fetch_one(pool)
    .await?;
    let total_admins: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM admin_users WHERE enabled = TRUE")
            .fetch_one(pool)
            .await?;
    let audit_log_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM admin_audit_logs")
        .fetch_one(pool)
        .await?;

    Ok(DashboardSummary {
        total_users: total_users.0,
        pro_users: pro_users.0,
        free_users: total_users.0 - pro_users.0,
        active_overrides: active_overrides.0,
        total_admins: total_admins.0,
        push_job_count: 0,
        audit_log_count: audit_log_count.0,
        remote_config_version: None,
        remote_config_updated_at: None,
    })
}

pub async fn get_user_summary(
    pool: &PgPool,
    actor_id: &str,
    query: &str,
    field: &str,
) -> Result<UserSummaryResult, AppError> {
    get_user_summary_with_filters(
        pool,
        actor_id,
        Some(query),
        field,
        "all",
        "all",
        25,
        None,
    )
    .await
}

pub async fn get_user_summary_with_filters(
    pool: &PgPool,
    actor_id: &str,
    query: Option<&str>,
    field: &str,
    subscription_filter: &str,
    override_filter: &str,
    limit: i64,
    start_after: Option<&str>,
) -> Result<UserSummaryResult, AppError> {
    require_admin(pool, actor_id, &[AdminRole::Owner, AdminRole::Support]).await?;

    let requested_limit = limit.clamp(1, 50);
    let normalized_query = query.map(str::trim).filter(|value| !value.is_empty());
    let normalized_field = normalize_user_search_field(field);
    let normalized_subscription_filter = normalize_subscription_filter(subscription_filter);
    let normalized_override_filter = normalize_override_filter(override_filter);
    let cursor = if normalized_query.is_some() {
        None
    } else {
        start_after.map(str::trim).filter(|value| !value.is_empty())
    };

    let mut builder = QueryBuilder::<Postgres>::new(
        "SELECT u.id, u.name, u.nickname, u.email
         FROM users u
         LEFT JOIN subscriptions s ON s.user_id = u.id
         LEFT JOIN entitlement_overrides eo ON eo.user_id = u.id
         WHERE 1 = 1",
    );

    if let Some(query_value) = normalized_query {
        match normalized_field {
            "userId" => {
                builder.push(" AND u.id = ");
                builder.push_bind(query_value);
            }
            "email" => {
                builder.push(" AND u.email = ");
                builder.push_bind(query_value);
            }
            "nickname" => {
                builder.push(" AND u.nickname = ");
                builder.push_bind(query_value);
            }
            _ => {
                builder.push(" AND (u.id = ");
                builder.push_bind(query_value);
                builder.push(" OR u.email = ");
                builder.push_bind(query_value);
                builder.push(" OR u.nickname = ");
                builder.push_bind(query_value);
                builder.push(")");
            }
        }
    }

    match normalized_subscription_filter {
        "subscribed" => {
            builder.push(" AND s.status IS NOT NULL AND s.status::text <> 'none'");
        }
        "not_subscribed" => {
            builder.push(" AND (s.status IS NULL OR s.status::text = 'none')");
        }
        _ => {}
    }

    match normalized_override_filter {
        "active" => {
            builder.push(
                " AND eo.is_active = TRUE AND (eo.expires_at IS NULL OR eo.expires_at >= NOW())",
            );
        }
        "inactive" => {
            builder.push(
                " AND (eo.user_id IS NULL OR NOT (eo.is_active = TRUE AND (eo.expires_at IS NULL OR eo.expires_at >= NOW())))",
            );
        }
        _ => {}
    }

    if let Some(cursor) = cursor {
        builder.push(" AND u.id > ");
        builder.push_bind(cursor);
    }

    builder.push(" ORDER BY u.id ASC LIMIT ");
    builder.push_bind(if normalized_query.is_some() {
        requested_limit
    } else {
        requested_limit + 1
    });

    let users = builder
        .build_query_as::<BasicUserRecord>()
        .fetch_all(pool)
        .await?;

    let has_more = normalized_query.is_none() && users.len() as i64 > requested_limit;
    let mut results = Vec::with_capacity(users.len().min(requested_limit as usize));
    for user in users.into_iter().take(requested_limit as usize) {
        results.push(build_user_summary(pool, &user).await?);
    }

    Ok(UserSummaryResult { results, has_more })
}

pub async fn get_user_timeline(
    pool: &PgPool,
    actor_id: &str,
    user_id: &str,
    limit: i64,
) -> Result<UserTimeline, AppError> {
    require_admin(pool, actor_id, &[AdminRole::Owner, AdminRole::Support]).await?;

    let user = sqlx::query_as::<_, BasicUserRecord>(
        "SELECT id, name, nickname, email FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("대상 사용자를 찾을 수 없습니다".to_string()))?;

    let summary = build_user_summary(pool, &user).await?;
    let subscription = fetch_subscription_snapshot(pool, user_id).await?;
    let override_snapshot = fetch_override_snapshot(pool, user_id).await?;
    let audit_logs = sqlx::query_as::<_, AuditLogRecord>(
        "SELECT id::text AS id, actor_id, action, target_type, target_id,
                before_data, after_data, created_at
         FROM admin_audit_logs
         WHERE target_id = $1
         ORDER BY created_at DESC
         LIMIT $2",
    )
    .bind(user_id)
    .bind(limit)
    .fetch_all(pool)
    .await?
    .into_iter()
    .map(|row| AuditLog {
        id: row.id,
        actor_id: row.actor_id,
        action: row.action,
        target_type: row.target_type,
        target_id: row.target_id,
        before: row.before_data,
        after: row.after_data,
        created_at: Some(row.created_at.to_rfc3339()),
    })
    .collect();

    Ok(UserTimeline {
        summary,
        subscription,
        r#override: override_snapshot,
        audit_logs,
    })
}

pub async fn grant_entitlement_override(
    pool: &PgPool,
    actor_id: &str,
    request: GrantEntitlementOverrideRequest,
) -> Result<(), AppError> {
    require_admin(pool, actor_id, &[AdminRole::Owner, AdminRole::Support]).await?;

    let user_id = request.user_id.trim();
    if user_id.is_empty() {
        return Err(AppError::BadRequest("userId는 필수입니다".to_string()));
    }

    let reason = request.reason.trim();
    if reason.is_empty() {
        return Err(AppError::BadRequest("reason은 필수입니다".to_string()));
    }

    ensure_user_exists(pool, user_id).await?;

    let expires_at = match request.expires_at.as_deref() {
        Some(value) => Some(
            DateTime::parse_from_rfc3339(value)
                .map_err(|_| {
                    AppError::BadRequest("expiresAt 형식이 올바르지 않습니다".to_string())
                })?
                .with_timezone(&Utc),
        ),
        None => None,
    };

    let before = fetch_override_snapshot(pool, user_id).await?;

    sqlx::query(
        "INSERT INTO entitlement_overrides
            (user_id, is_active, override_type, reason, expires_at, created_by, created_at,
             updated_at, revoked_at, revoked_by, revoked_reason)
         VALUES
            ($1, TRUE, 'manual_pro_grant', $2, $3, $4, NOW(), NOW(), NULL, NULL, NULL)
         ON CONFLICT (user_id) DO UPDATE
         SET is_active = TRUE,
             override_type = 'manual_pro_grant',
             reason = EXCLUDED.reason,
             expires_at = EXCLUDED.expires_at,
             created_by = EXCLUDED.created_by,
             updated_at = NOW(),
             revoked_at = NULL,
             revoked_by = NULL,
             revoked_reason = NULL",
    )
    .bind(user_id)
    .bind(reason)
    .bind(expires_at)
    .bind(actor_id)
    .execute(pool)
    .await?;

    write_audit_log(
        pool,
        actor_id,
        "grant_entitlement_override",
        user_id,
        before.as_ref().map(override_snapshot_json),
        Some(json!({
            "isActive": true,
            "reason": reason,
            "expiresAt": expires_at,
        })),
    )
    .await?;

    crate::services::subscription_service::reconcile_entitlement(pool, user_id).await?;

    Ok(())
}

pub async fn revoke_entitlement_override(
    pool: &PgPool,
    actor_id: &str,
    request: RevokeEntitlementOverrideRequest,
) -> Result<(), AppError> {
    require_admin(pool, actor_id, &[AdminRole::Owner, AdminRole::Support]).await?;

    let user_id = request.user_id.trim();
    if user_id.is_empty() {
        return Err(AppError::BadRequest("userId는 필수입니다".to_string()));
    }

    let before = fetch_override_snapshot(pool, user_id).await?;
    let before =
        before.ok_or_else(|| AppError::NotFound("활성 override를 찾을 수 없습니다".to_string()))?;

    sqlx::query(
        "UPDATE entitlement_overrides
         SET is_active = FALSE,
             updated_at = NOW(),
             revoked_at = NOW(),
             revoked_by = $2,
             revoked_reason = $3
         WHERE user_id = $1",
    )
    .bind(user_id)
    .bind(actor_id)
    .bind(request.reason.as_deref())
    .execute(pool)
    .await?;

    write_audit_log(
        pool,
        actor_id,
        "revoke_entitlement_override",
        user_id,
        Some(override_snapshot_json(&before)),
        Some(json!({
            "isActive": false,
            "reason": request.reason,
        })),
    )
    .await?;

    crate::services::subscription_service::reconcile_entitlement(pool, user_id).await?;

    Ok(())
}

pub async fn build_pro_plan_dashboard(
    pool: &PgPool,
    actor_id: &str,
) -> Result<ProPlanDashboard, AppError> {
    require_admin(pool, actor_id, &[AdminRole::Owner, AdminRole::Marketer]).await?;

    let subscriptions = sqlx::query_as::<_, ProPlanSubscriptionRow>(
        "SELECT user_id, status::text AS status, product_id, last_offer_type,
                last_offer_identifier, updated_at
         FROM subscriptions",
    )
    .fetch_all(pool)
    .await?;

    let mut dashboard = ProPlanDashboard::default();
    dashboard.prices = ProPlanPrices {
        monthly: DEFAULT_PROPLAN_MONTHLY_PRICE,
        yearly: DEFAULT_PROPLAN_YEARLY_PRICE,
        lifetime: DEFAULT_PROPLAN_LIFETIME_PRICE,
    };

    for row in subscriptions {
        match row.status.as_str() {
            "subscribed" if row.product_id.as_deref().unwrap_or("").contains("monthly") => {
                dashboard.breakdown.monthly.count += 1;
            }
            "subscribed" if row.product_id.as_deref().unwrap_or("").contains("yearly") => {
                dashboard.breakdown.yearly.count += 1;
            }
            "lifetime" => {
                dashboard.breakdown.lifetime.count += 1;
            }
            "grace_period" => {
                dashboard.breakdown.grace_period.count += 1;
            }
            _ => {}
        }

        dashboard.recent_activities.push(ProPlanActivity {
            user_id: row.user_id.clone(),
            r#type: row.status.clone(),
            product_id: row.product_id.clone(),
            timestamp: row.updated_at.to_rfc3339(),
        });

        if row.last_offer_type == Some(3) {
            dashboard.offer_codes.total_redemptions += 1;
            if let Some(offer_identifier) = row.last_offer_identifier.clone() {
                dashboard.offer_codes.recent_redemptions.push(OfferCodeRedemption {
                    user_id: row.user_id,
                    offer_identifier,
                    redeemed_at: row.updated_at,
                    product_id: row.product_id.clone(),
                });
            }
        }
    }

    let override_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM entitlement_overrides
         WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at >= NOW())",
    )
    .fetch_one(pool)
    .await?;
    dashboard.breakdown.r#override.count = override_count.0;
    dashboard.breakdown.monthly.revenue =
        dashboard.breakdown.monthly.count * dashboard.prices.monthly;
    dashboard.breakdown.yearly.revenue =
        dashboard.breakdown.yearly.count * dashboard.prices.yearly;
    dashboard.breakdown.lifetime.total_revenue =
        dashboard.breakdown.lifetime.count * dashboard.prices.lifetime;

    let total_users: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    let pro_users: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM entitlements WHERE has_pro = TRUE")
            .fetch_one(pool)
            .await?;
    let pro_subscription_users: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM entitlements
         WHERE has_pro = TRUE AND source = 'subscription'",
    )
    .fetch_one(pool)
    .await?;
    let pro_override_users: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM entitlements
         WHERE has_pro = TRUE AND source = 'override'",
    )
    .fetch_one(pool)
    .await?;

    dashboard.overview = ProPlanOverview {
        total_users: total_users.0,
        pro_users: pro_users.0,
        pro_subscription_users: pro_subscription_users.0,
        pro_override_users: pro_override_users.0,
        free_users: total_users.0 - pro_users.0,
        pro_rate: if total_users.0 > 0 {
            (((pro_users.0 as f64 / total_users.0 as f64) * 10000.0).round()) / 100.0
        } else {
            0.0
        },
    };
    dashboard.revenue = ProPlanRevenue {
        estimated_mrr: dashboard.breakdown.monthly.revenue
            + (dashboard.breakdown.yearly.revenue / 12),
        total_lifetime_revenue: dashboard.breakdown.lifetime.total_revenue,
    };
    dashboard
        .offer_codes
        .recent_redemptions
        .sort_by(|left, right| right.redeemed_at.cmp(&left.redeemed_at));
    dashboard.offer_codes.recent_redemptions.truncate(50);
    dashboard
        .recent_activities
        .sort_by(|left, right| right.timestamp.cmp(&left.timestamp));
    dashboard.recent_activities.truncate(20);

    Ok(dashboard)
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct BasicUserRecord {
    id: String,
    name: String,
    nickname: String,
    email: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct AuditLogRecord {
    id: String,
    actor_id: Option<String>,
    action: Option<String>,
    target_type: Option<String>,
    target_id: Option<String>,
    before_data: Option<serde_json::Value>,
    after_data: Option<serde_json::Value>,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct SubscriptionSnapshotRow {
    status: Option<String>,
    product_id: Option<String>,
    expiration_date: Option<DateTime<Utc>>,
    purchase_date: Option<DateTime<Utc>>,
    updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct OverrideSnapshotRow {
    is_active: bool,
    override_type: String,
    reason: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    created_by: Option<String>,
    created_at: DateTime<Utc>,
    revoked_by: Option<String>,
    revoked_reason: Option<String>,
    revoked_at: Option<DateTime<Utc>>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct ProPlanSubscriptionRow {
    user_id: String,
    status: String,
    product_id: Option<String>,
    last_offer_type: Option<i32>,
    last_offer_identifier: Option<String>,
    updated_at: DateTime<Utc>,
}

async fn build_user_summary(
    pool: &PgPool,
    user: &BasicUserRecord,
) -> Result<UserSummary, AppError> {
    let group_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE user_id = $1")
            .bind(&user.id)
            .fetch_one(pool)
            .await?;
    let device_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM devices WHERE user_id = $1")
        .bind(&user.id)
        .fetch_one(pool)
        .await
        .unwrap_or((0,));
    let personal_event_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedules WHERE user_id = $1 AND schedule_type = 'personal'",
    )
    .bind(&user.id)
    .fetch_one(pool)
    .await
    .unwrap_or((0,));
    let subscription = fetch_subscription_snapshot(pool, &user.id).await?;
    let override_snapshot = fetch_override_snapshot(pool, &user.id).await?;

    Ok(UserSummary {
        user_id: user.id.clone(),
        name: Some(user.name.clone()),
        nickname: Some(user.nickname.clone()),
        email: Some(user.email.clone()),
        group_count: group_count.0,
        device_count: device_count.0,
        personal_event_count: personal_event_count.0,
        subscription_status: subscription.status,
        override_active: override_snapshot
            .as_ref()
            .map(|snapshot| snapshot.is_active)
            .unwrap_or(false),
    })
}

async fn fetch_subscription_snapshot(
    pool: &PgPool,
    user_id: &str,
) -> Result<SubscriptionSnapshot, AppError> {
    let row = sqlx::query_as::<_, SubscriptionSnapshotRow>(
        "SELECT status::text AS status, product_id, expiration_date, purchase_date, updated_at
         FROM subscriptions
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    Ok(match row {
        Some(row) => SubscriptionSnapshot {
            status: row.status,
            product_id: row.product_id,
            expiration_date: row.expiration_date,
            purchase_date: row.purchase_date,
            updated_at: row.updated_at,
        },
        None => SubscriptionSnapshot {
            status: None,
            product_id: None,
            expiration_date: None,
            purchase_date: None,
            updated_at: None,
        },
    })
}

async fn fetch_override_snapshot(
    pool: &PgPool,
    user_id: &str,
) -> Result<Option<OverrideSnapshot>, AppError> {
    let row = sqlx::query_as::<_, OverrideSnapshotRow>(
        "SELECT is_active, override_type, reason, expires_at, created_by, created_at,
                revoked_by, revoked_reason, revoked_at, updated_at
         FROM entitlement_overrides
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|row| OverrideSnapshot {
        is_active: row.is_active,
        override_type: Some(row.override_type),
        reason: row.reason,
        expires_at: row.expires_at,
        created_by: row.created_by,
        created_at: Some(row.created_at),
        revoked_by: row.revoked_by,
        revoked_reason: row.revoked_reason,
        revoked_at: row.revoked_at,
        updated_at: Some(row.updated_at),
    }))
}

fn normalize_user_search_field(field: &str) -> &str {
    match field {
        "userId" | "email" | "nickname" => field,
        _ => "all",
    }
}

fn normalize_subscription_filter(filter: &str) -> &str {
    match filter {
        "subscribed" | "not_subscribed" => filter,
        _ => "all",
    }
}

fn normalize_override_filter(filter: &str) -> &str {
    match filter {
        "active" | "inactive" => filter,
        _ => "all",
    }
}

async fn require_admin(
    pool: &PgPool,
    actor_id: &str,
    allowed_roles: &[AdminRole],
) -> Result<AdminUserRecord, AppError> {
    let admin = sqlx::query_as::<_, AdminUserRecord>(
        "SELECT role, enabled FROM admin_users WHERE user_id = $1",
    )
    .bind(actor_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::Unauthorized("로그인이 필요합니다".to_string()))?;

    if !admin.enabled {
        return Err(AppError::Forbidden("비활성화된 관리자입니다".to_string()));
    }

    if !allowed_roles.contains(&admin.role) {
        return Err(AppError::Forbidden("권한이 없습니다".to_string()));
    }

    Ok(admin)
}

async fn ensure_user_exists(pool: &PgPool, user_id: &str) -> Result<(), AppError> {
    let exists: Option<(String,)> = sqlx::query_as("SELECT id FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await?;

    if exists.is_none() {
        return Err(AppError::NotFound(
            "대상 사용자를 찾을 수 없습니다".to_string(),
        ));
    }

    Ok(())
}

async fn write_audit_log(
    pool: &PgPool,
    actor_id: &str,
    action: &str,
    target_id: &str,
    before_data: Option<serde_json::Value>,
    after_data: Option<serde_json::Value>,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO admin_audit_logs
            (actor_id, action, target_id, target_type, before_data, after_data)
         VALUES ($1, $2, $3, 'user', $4, $5)",
    )
    .bind(actor_id)
    .bind(action)
    .bind(target_id)
    .bind(before_data)
    .bind(after_data)
    .execute(pool)
    .await?;
    Ok(())
}

fn override_snapshot_json(snapshot: &OverrideSnapshot) -> serde_json::Value {
    json!({
        "isActive": snapshot.is_active,
        "type": snapshot.override_type,
        "reason": snapshot.reason,
        "expiresAt": snapshot.expires_at,
        "createdBy": snapshot.created_by,
        "createdAt": snapshot.created_at,
        "revokedBy": snapshot.revoked_by,
        "revokedReason": snapshot.revoked_reason,
        "revokedAt": snapshot.revoked_at,
        "updatedAt": snapshot.updated_at,
    })
}

impl FromStr for AdminRole {
    type Err = AppError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "owner" => Ok(Self::Owner),
            "support" => Ok(Self::Support),
            "marketer" => Ok(Self::Marketer),
            _ => Err(AppError::Internal("invalid admin role".to_string())),
        }
    }
}
