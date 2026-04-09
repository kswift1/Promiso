use std::collections::{BTreeMap, BTreeSet};
use std::ops::Add;

use chrono::{DateTime, NaiveDate, Utc};
use serde::de::DeserializeOwned;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::services::subscription_backfill_service::{
    backfill_entitlement_override, backfill_subscription, backfill_subscription_owner,
    recompute_entitlement, FirestoreEntitlementOverrideRow, FirestoreSubscriptionOwnerRow,
    FirestoreSubscriptionRow,
};

// ---------------------------------------------------------------------------
// UUID v5 namespaces
// ---------------------------------------------------------------------------

fn ns_groups() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/groups")
}

fn ns_schedules() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/schedules")
}

fn ns_personal_events() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/personal_events")
}

fn ns_recurring_events() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/recurring_events")
}

fn ns_notifications() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/notifications")
}

fn ns_audit_logs() -> Uuid {
    Uuid::new_v5(&Uuid::NAMESPACE_DNS, b"promiso.app/migration/audit_logs")
}

fn to_uuid(ns: &Uuid, firestore_id: &str) -> Uuid {
    Uuid::parse_str(firestore_id).unwrap_or_else(|_| Uuid::new_v5(ns, firestore_id.as_bytes()))
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

/// Per-domain migration counts. Subscription-related counts are tracked separately
/// in `SubscriptionMigrationSummary` and exposed via `FullMigrationSummary`.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MigrationSummary {
    pub users: usize,
    pub auth_accounts: usize,
    pub user_settings: usize,
    pub devices: usize,
    pub notification_endpoints: usize,
    pub live_activity_endpoints: usize,
    pub group_members: usize,
    pub groups: usize,
    pub schedules: usize,
    pub schedule_votes: usize,
    pub recurring_schedules: usize,
    pub notifications: usize,
    pub briefing_subscriptions: usize,
    pub admin_users: usize,
    pub admin_audit_logs: usize,
}

impl Add for MigrationSummary {
    type Output = MigrationSummary;

    fn add(self, rhs: MigrationSummary) -> MigrationSummary {
        MigrationSummary {
            users: self.users + rhs.users,
            auth_accounts: self.auth_accounts + rhs.auth_accounts,
            user_settings: self.user_settings + rhs.user_settings,
            devices: self.devices + rhs.devices,
            notification_endpoints: self.notification_endpoints + rhs.notification_endpoints,
            live_activity_endpoints: self.live_activity_endpoints + rhs.live_activity_endpoints,
            group_members: self.group_members + rhs.group_members,
            groups: self.groups + rhs.groups,
            schedules: self.schedules + rhs.schedules,
            schedule_votes: self.schedule_votes + rhs.schedule_votes,
            recurring_schedules: self.recurring_schedules + rhs.recurring_schedules,
            notifications: self.notifications + rhs.notifications,
            briefing_subscriptions: self.briefing_subscriptions + rhs.briefing_subscriptions,
            admin_users: self.admin_users + rhs.admin_users,
            admin_audit_logs: self.admin_audit_logs + rhs.admin_audit_logs,
        }
    }
}

/// Subscription-domain migration counts (separate to keep `MigrationSummary` test-compatible).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SubscriptionMigrationSummary {
    pub subscriptions: usize,
    pub subscription_owners: usize,
    pub entitlement_overrides: usize,
    pub entitlements_recomputed: usize,
}

/// Complete output returned by `run_data_migration`.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FullMigrationSummary {
    pub core: MigrationSummary,
    pub subscription: SubscriptionMigrationSummary,
}

impl FullMigrationSummary {
    // Convenience accessors so the binary doesn't need to dig into sub-structs.
    pub fn users(&self) -> usize { self.core.users }
    pub fn auth_accounts(&self) -> usize { self.core.auth_accounts }
    pub fn user_settings(&self) -> usize { self.core.user_settings }
    pub fn devices(&self) -> usize { self.core.devices }
    pub fn notification_endpoints(&self) -> usize { self.core.notification_endpoints }
    pub fn live_activity_endpoints(&self) -> usize { self.core.live_activity_endpoints }
    pub fn groups(&self) -> usize { self.core.groups }
    pub fn group_members(&self) -> usize { self.core.group_members }
    pub fn schedules(&self) -> usize { self.core.schedules }
    pub fn schedule_votes(&self) -> usize { self.core.schedule_votes }
    pub fn recurring_schedules(&self) -> usize { self.core.recurring_schedules }
    pub fn notifications(&self) -> usize { self.core.notifications }
    pub fn subscriptions(&self) -> usize { self.subscription.subscriptions }
    pub fn subscription_owners(&self) -> usize { self.subscription.subscription_owners }
    pub fn entitlement_overrides(&self) -> usize { self.subscription.entitlement_overrides }
    pub fn entitlements_recomputed(&self) -> usize { self.subscription.entitlements_recomputed }
    pub fn briefing_subscriptions(&self) -> usize { self.core.briefing_subscriptions }
    pub fn admin_users(&self) -> usize { self.core.admin_users }
    pub fn admin_audit_logs(&self) -> usize { self.core.admin_audit_logs }
}

// ---------------------------------------------------------------------------
// Row types
// ---------------------------------------------------------------------------

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreUserRow {
    #[serde(rename = "_id")]
    id: String,
    name: String,
    nickname: String,
    #[serde(default)]
    profile: Option<FirestoreProfile>,
    #[serde(default)]
    groups: BTreeMap<String, FirestoreUserGroupInfo>,
    #[serde(default)]
    devices: BTreeMap<String, FirestoreDeviceInfo>,
    meta_data: FirestoreMetaData,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreProfile {
    url: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreMetaData {
    created_at: Option<String>,
    updated_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreDeviceInfo {
    fcm_token: Option<String>,
    platform: Option<String>,
    last_active_at: Option<String>,
    created_at: Option<String>,
    push_to_start_token: Option<String>,
    live_activity_push_token: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreUserGroupInfo {
    role: Option<String>,
    joined_at: Option<String>,
    #[serde(default)]
    notifications: Option<FirestoreGroupNotifications>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreGroupNotifications {
    enabled: Option<bool>,
    promise: Option<FirestorePromiseNotifications>,
    group: Option<FirestoreGroupUpdateNotifications>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestorePromiseNotifications {
    invitation: Option<bool>,
    reminder: Option<bool>,
    confirmed: Option<bool>,
    cancelled: Option<bool>,
    updated: Option<bool>,
    attendance_response: Option<bool>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreGroupUpdateNotifications {
    update: Option<bool>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreAuthAccountRow {
    #[serde(rename = "_userId")]
    user_id: String,
    provider: FirestoreProvider,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreProvider {
    #[serde(rename = "type")]
    provider_type: String,
    uid: String,
    email: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreUserSettingsRow {
    #[serde(rename = "_userId")]
    user_id: String,
    #[serde(default)]
    group_sort_option: Option<FirestoreGroupSortOption>,
    #[serde(default)]
    pro_settings: Option<FirestoreProSettings>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreGroupSortOption {
    #[serde(rename = "type")]
    sort_type: Option<String>,
    order: Option<Vec<String>>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreProSettings {
    briefing: Option<FirestoreBriefingSettings>,
    conflict_detection_threshold_minute: Option<i16>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreBriefingSettings {
    notification_hour: Option<i16>,
    timezone: Option<String>,
    language: Option<String>,
    style: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreGroupRow {
    #[serde(rename = "_id")]
    id: String,
    name: String,
    description: Option<String>,
    image_url: Option<String>,
    max_members: Option<i16>,
    invite_code: String,
    created_at: Option<String>,
    updated_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestorePromiseRow {
    #[serde(rename = "_id")]
    id: String,
    title: String,
    emoji: Option<String>,
    description: Option<String>,
    description_blocks: Option<Value>,
    host_id: String,
    group_id: String,
    minimum_participants: Option<i16>,
    is_confirmed: Option<bool>,
    votes: Option<FirestoreVotes>,
    start_at: String,
    end_at: Option<String>,
    location: Option<FirestoreLocation>,
    tracking_start_minutes_before: Option<i16>,
    image_urls: Option<Vec<String>>,
    created_at: Option<String>,
    updated_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreVotes {
    accepted: Option<Vec<String>>,
    declined: Option<Vec<String>>,
    until: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreLocation {
    name: Option<String>,
    address: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestorePersonalEventRow {
    #[serde(rename = "_id")]
    id: String,
    #[serde(rename = "_userId")]
    user_id: String,
    title: String,
    emoji: Option<String>,
    description: Option<String>,
    description_blocks: Option<Value>,
    start_at: String,
    end_at: Option<String>,
    location: Option<FirestoreLocation>,
    reminder_minutes_before: Option<i16>,
    created_at: Option<String>,
    updated_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreRecurringEventRow {
    #[serde(rename = "_id")]
    id: String,
    #[serde(rename = "_userId")]
    user_id: String,
    title: String,
    emoji: Option<String>,
    description: Option<String>,
    start_time: FirestoreTimeOfDay,
    end_time: Option<FirestoreTimeOfDay>,
    location: Option<FirestoreLocation>,
    reminder_minutes_before: Option<i16>,
    recurrence: FirestoreRecurrence,
    series_start_date: Option<String>,
    excluded_dates: Option<Vec<String>>,
    overrides: Option<Value>,
    created_at: Option<String>,
    updated_at: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreTimeOfDay {
    hour: i16,
    minute: i16,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreRecurrence {
    frequency: String,
    days_of_week: Option<Vec<i16>>,
    day_of_month: Option<i16>,
    series_end_date: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreNotificationRow {
    #[serde(rename = "_id")]
    id: String,
    user_id: String,
    #[serde(rename = "type")]
    notification_type: String,
    title: String,
    body: String,
    promise_id: Option<String>,
    group_id: Option<String>,
    related_user_id: Option<String>,
    is_read: Option<bool>,
    is_delivered: Option<bool>,
    created_at: Option<String>,
    read_at: Option<String>,
    delivered_at: Option<String>,
    data: Option<Value>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreBriefingSubscriptionRow {
    #[serde(rename = "_id")]
    id: String,
    notification_hour: i16,
    timezone: String,
    language: String,
    style: String,
    next_dispatch_at: String,
    default_location: Option<FirestoreDefaultLocation>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreDefaultLocation {
    title: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreAdminUserRow {
    #[serde(rename = "_id")]
    id: String,
    role: String,
    email: Option<String>,
    enabled: Option<bool>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirestoreAdminAuditLogRow {
    #[serde(rename = "_id")]
    id: String,
    actor_id: String,
    action: String,
    target_id: Option<String>,
    target_type: Option<String>,
    #[serde(rename = "before")]
    before_data: Option<Value>,
    #[serde(rename = "after")]
    after_data: Option<Value>,
    created_at: Option<String>,
}

// ---------------------------------------------------------------------------
// JSONL parser
// ---------------------------------------------------------------------------

fn parse_jsonl_rows<T>(input: &str, label: &str) -> Result<Vec<T>, AppError>
where
    T: DeserializeOwned,
{
    input
        .lines()
        .enumerate()
        .filter_map(|(index, line)| {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some((index + 1, trimmed))
            }
        })
        .map(|(line_number, line)| {
            serde_json::from_str::<T>(line).map_err(|error| {
                AppError::BadRequest(format!(
                    "invalid {label} jsonl at line {line_number}: {error}"
                ))
            })
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn parse_optional_rfc3339(value: &Option<String>) -> Result<Option<DateTime<Utc>>, AppError> {
    match value.as_deref() {
        Some(s) => DateTime::parse_from_rfc3339(s)
            .map(|dt| Some(dt.with_timezone(&Utc)))
            .map_err(|_| {
                AppError::BadRequest(format!("invalid timestamp: {s}"))
            }),
        None => Ok(None),
    }
}

fn parse_required_rfc3339(value: &str) -> Result<DateTime<Utc>, AppError> {
    DateTime::parse_from_rfc3339(value)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|_| AppError::BadRequest(format!("invalid timestamp: {value}")))
}

/// Parse a date that may be a full ISO 8601 timestamp or a bare "yyyy-MM-dd".
fn parse_date_field(value: &str) -> Result<NaiveDate, AppError> {
    // Try bare date first
    if let Ok(d) = NaiveDate::parse_from_str(value, "%Y-%m-%d") {
        return Ok(d);
    }
    // Fall back to full timestamp and take the date part
    DateTime::parse_from_rfc3339(value)
        .map(|dt| dt.with_timezone(&Utc).date_naive())
        .map_err(|_| AppError::BadRequest(format!("invalid date: {value}")))
}

fn parse_optional_date(value: &Option<String>) -> Result<Option<NaiveDate>, AppError> {
    match value.as_deref() {
        Some(s) => parse_date_field(s).map(Some),
        None => Ok(None),
    }
}

fn map_notification_type(firestore_type: &str) -> &str {
    match firestore_type {
        "promise_invitation" => "schedule_invitation",
        "promise_reminder" => "schedule_reminder",
        "promise_confirmed" => "schedule_confirmed",
        "promise_cancelled" => "schedule_cancelled",
        "promise_updated" => "schedule_updated",
        other => other,
    }
}

// ---------------------------------------------------------------------------
// Phase A
// ---------------------------------------------------------------------------

pub async fn import_users(pool: &PgPool, jsonl: &str) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreUserRow>(jsonl, "users")?;
    let mut summary = MigrationSummary::default();

    for row in rows {
        let created_at = parse_optional_rfc3339(&row.meta_data.created_at)?
            .unwrap_or_else(Utc::now);
        let updated_at = parse_optional_rfc3339(&row.meta_data.updated_at)?
            .unwrap_or_else(Utc::now);
        let profile_url = row.profile.as_ref().and_then(|p| p.url.clone());

        sqlx::query(
            "INSERT INTO users
                (id, name, nickname, provider_type, provider_uid, email, profile_url,
                 notification_enabled, created_at, updated_at)
             VALUES ($1, $2, $3, 'apple', '', '', $4, TRUE, $5, $6)
             ON CONFLICT (id) DO UPDATE
             SET name = EXCLUDED.name,
                 nickname = EXCLUDED.nickname,
                 profile_url = EXCLUDED.profile_url,
                 updated_at = EXCLUDED.updated_at",
        )
        .bind(&row.id)
        .bind(&row.name)
        .bind(&row.nickname)
        .bind(&profile_url)
        .bind(created_at)
        .bind(updated_at)
        .execute(pool)
        .await?;

        summary.users += 1;

        // devices map -> devices + notification_endpoints + live_activity_endpoints
        for (device_id, device) in &row.devices {
            let device_summary = upsert_device(pool, &row.id, device_id, device).await?;
            summary.devices += device_summary.devices;
            summary.notification_endpoints += device_summary.notification_endpoints;
            summary.live_activity_endpoints += device_summary.live_activity_endpoints;
        }

        // groups map -> group_members
        for (firestore_group_id, group_info) in &row.groups {
            let pg_group_id = to_uuid(&ns_groups(), firestore_group_id);
            // Only insert if the group exists (may not yet if groups.jsonl hasn't been imported)
            let exists: (bool,) =
                sqlx::query_as("SELECT EXISTS(SELECT 1 FROM groups WHERE id = $1)")
                    .bind(pg_group_id)
                    .fetch_one(pool)
                    .await?;

            if !exists.0 {
                continue;
            }

            upsert_group_member(pool, pg_group_id, &row.id, group_info).await?;
            summary.group_members += 1;
        }
    }

    Ok(summary)
}

async fn upsert_device(
    pool: &PgPool,
    user_id: &str,
    device_id: &str,
    device: &FirestoreDeviceInfo,
) -> Result<MigrationSummary, AppError> {
    let platform = device
        .platform
        .as_deref()
        .unwrap_or("ios");
    let last_active_at = parse_optional_rfc3339(&device.last_active_at)?.unwrap_or_else(Utc::now);
    let created_at = parse_optional_rfc3339(&device.created_at)?.unwrap_or_else(Utc::now);

    // devices table has fcm_token removed by migration 007 — only id, user_id, device_id,
    // platform, last_active_at, created_at remain.
    let pg_device_id: (Uuid,) = sqlx::query_as(
        "INSERT INTO devices (user_id, device_id, platform, last_active_at, created_at)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (user_id, device_id) DO UPDATE
         SET platform = EXCLUDED.platform,
             last_active_at = EXCLUDED.last_active_at,
             updated_at = NOW()
         RETURNING id",
    )
    .bind(user_id)
    .bind(device_id)
    .bind(platform)
    .bind(last_active_at)
    .bind(created_at)
    .fetch_one(pool)
    .await?;

    let mut summary = MigrationSummary {
        devices: 1,
        ..Default::default()
    };

    // notification_endpoints (fcm)
    if let Some(fcm_token) = device.fcm_token.as_deref().filter(|t| !t.is_empty()) {
        sqlx::query(
            "INSERT INTO notification_endpoints (device_id, provider, token)
             VALUES ($1, 'fcm', $2)
             ON CONFLICT (provider, token) DO UPDATE
             SET device_id = EXCLUDED.device_id,
                 updated_at = NOW()",
        )
        .bind(pg_device_id.0)
        .bind(fcm_token)
        .execute(pool)
        .await?;

        summary.notification_endpoints += 1;
    }

    // live_activity_endpoints
    let has_pts = device
        .push_to_start_token
        .as_deref()
        .filter(|t| !t.is_empty())
        .is_some();
    let has_lap = device
        .live_activity_push_token
        .as_deref()
        .filter(|t| !t.is_empty())
        .is_some();

    if has_pts || has_lap {
        let pts = device.push_to_start_token.as_deref().filter(|t| !t.is_empty());
        let lap = device
            .live_activity_push_token
            .as_deref()
            .filter(|t| !t.is_empty());

        sqlx::query(
            "INSERT INTO live_activity_endpoints (device_id, push_to_start_token, live_activity_push_token)
             VALUES ($1, $2, $3)
             ON CONFLICT (device_id) DO UPDATE
             SET push_to_start_token = COALESCE(EXCLUDED.push_to_start_token, live_activity_endpoints.push_to_start_token),
                 live_activity_push_token = COALESCE(EXCLUDED.live_activity_push_token, live_activity_endpoints.live_activity_push_token),
                 updated_at = NOW()",
        )
        .bind(pg_device_id.0)
        .bind(pts)
        .bind(lap)
        .execute(pool)
        .await?;

        summary.live_activity_endpoints += 1;
    }

    Ok(summary)
}

async fn upsert_group_member(
    pool: &PgPool,
    pg_group_id: Uuid,
    user_id: &str,
    info: &FirestoreUserGroupInfo,
) -> Result<(), AppError> {
    let role = info.role.as_deref().unwrap_or("member");
    let joined_at = parse_optional_rfc3339(&info.joined_at)?.unwrap_or_else(Utc::now);

    let notifs = info.notifications.as_ref();
    let notifications_enabled = notifs
        .and_then(|n| n.enabled)
        .unwrap_or(true);
    let promise_notifs = notifs.and_then(|n| n.promise.as_ref());
    let schedule_invitation = promise_notifs.and_then(|p| p.invitation).unwrap_or(true);
    let schedule_reminder = promise_notifs.and_then(|p| p.reminder).unwrap_or(true);
    let schedule_confirmed = promise_notifs.and_then(|p| p.confirmed).unwrap_or(true);
    let schedule_cancelled = promise_notifs.and_then(|p| p.cancelled).unwrap_or(true);
    let schedule_updated = promise_notifs.and_then(|p| p.updated).unwrap_or(true);
    let attendance_response = promise_notifs.and_then(|p| p.attendance_response).unwrap_or(true);
    let group_update = notifs
        .and_then(|n| n.group.as_ref())
        .and_then(|g| g.update)
        .unwrap_or(true);

    sqlx::query(
        "INSERT INTO group_members
            (group_id, user_id, role, group_color,
             notifications_enabled, schedule_invitation, schedule_reminder,
             schedule_confirmed, schedule_cancelled, schedule_updated,
             attendance_response, group_update, calendar_sync,
             joined_at, last_read_at)
         VALUES ($1, $2, $3::group_member_role, '#AF52DE',
                 $4, $5, $6, $7, $8, $9, $10, $11, TRUE,
                 $12, $12)
         ON CONFLICT (group_id, user_id) DO UPDATE
         SET role = EXCLUDED.role,
             notifications_enabled = EXCLUDED.notifications_enabled,
             schedule_invitation = EXCLUDED.schedule_invitation,
             schedule_reminder = EXCLUDED.schedule_reminder,
             schedule_confirmed = EXCLUDED.schedule_confirmed,
             schedule_cancelled = EXCLUDED.schedule_cancelled,
             schedule_updated = EXCLUDED.schedule_updated,
             attendance_response = EXCLUDED.attendance_response,
             group_update = EXCLUDED.group_update",
    )
    .bind(pg_group_id)
    .bind(user_id)
    .bind(role)
    .bind(notifications_enabled)
    .bind(schedule_invitation)
    .bind(schedule_reminder)
    .bind(schedule_confirmed)
    .bind(schedule_cancelled)
    .bind(schedule_updated)
    .bind(attendance_response)
    .bind(group_update)
    .bind(joined_at)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn import_auth_accounts(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreAuthAccountRow>(jsonl, "auth_accounts")?;
    let mut summary = MigrationSummary::default();

    for row in rows {
        sqlx::query(
            "INSERT INTO auth_accounts (user_id, provider_type, provider_uid, email)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (user_id) DO UPDATE
             SET provider_type = EXCLUDED.provider_type,
                 provider_uid = EXCLUDED.provider_uid,
                 email = EXCLUDED.email,
                 updated_at = NOW()",
        )
        .bind(&row.user_id)
        .bind(&row.provider.provider_type)
        .bind(&row.provider.uid)
        .bind(&row.provider.email)
        .execute(pool)
        .await?;

        // Back-fill users.provider_type / provider_uid / email for legacy columns
        sqlx::query(
            "UPDATE users
             SET provider_type = $1,
                 provider_uid = $2,
                 email = COALESCE($3, email)
             WHERE id = $4",
        )
        .bind(&row.provider.provider_type)
        .bind(&row.provider.uid)
        .bind(&row.provider.email)
        .bind(&row.user_id)
        .execute(pool)
        .await?;

        summary.auth_accounts += 1;
    }

    Ok(summary)
}

pub async fn import_admin_users(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreAdminUserRow>(jsonl, "admin_users")?;
    let mut summary = MigrationSummary::default();

    for row in rows {
        sqlx::query(
            "INSERT INTO admin_users (user_id, email, role, enabled)
             VALUES ($1, $2, $3::admin_role, $4)
             ON CONFLICT (user_id) DO UPDATE
             SET email = EXCLUDED.email,
                 role = EXCLUDED.role,
                 enabled = EXCLUDED.enabled,
                 updated_at = NOW()",
        )
        .bind(&row.id)
        .bind(&row.email)
        .bind(&row.role)
        .bind(row.enabled.unwrap_or(true))
        .execute(pool)
        .await?;

        summary.admin_users += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Phase B
// ---------------------------------------------------------------------------

pub async fn import_user_settings(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreUserSettingsRow>(jsonl, "user_settings")?;
    let mut summary = MigrationSummary::default();

    for row in rows {
        let briefing = row
            .pro_settings
            .as_ref()
            .and_then(|ps| ps.briefing.as_ref());
        let briefing_hour = briefing.and_then(|b| b.notification_hour);
        let briefing_timezone = briefing.and_then(|b| b.timezone.clone());
        let briefing_language = briefing.and_then(|b| b.language.clone());
        let briefing_style = briefing.and_then(|b| b.style.clone());
        let conflict_threshold: i16 = row
            .pro_settings
            .as_ref()
            .and_then(|ps| ps.conflict_detection_threshold_minute)
            .unwrap_or(0);

        let sort_type = row
            .group_sort_option
            .as_ref()
            .and_then(|g| g.sort_type.clone())
            .unwrap_or_else(|| "joinedRecent".to_string());

        let sort_order: Option<Vec<String>> = row
            .group_sort_option
            .as_ref()
            .and_then(|g| g.order.clone());

        sqlx::query(
            "INSERT INTO user_settings
                (user_id, briefing_notification_hour, briefing_timezone,
                 briefing_language, briefing_style, group_sort_type, group_sort_order,
                 conflict_threshold_min)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             ON CONFLICT (user_id) DO UPDATE
             SET briefing_notification_hour = COALESCE(EXCLUDED.briefing_notification_hour, user_settings.briefing_notification_hour),
                 briefing_timezone = COALESCE(EXCLUDED.briefing_timezone, user_settings.briefing_timezone),
                 briefing_language = COALESCE(EXCLUDED.briefing_language, user_settings.briefing_language),
                 briefing_style = COALESCE(EXCLUDED.briefing_style, user_settings.briefing_style),
                 group_sort_type = EXCLUDED.group_sort_type,
                 group_sort_order = EXCLUDED.group_sort_order,
                 conflict_threshold_min = COALESCE(EXCLUDED.conflict_threshold_min, user_settings.conflict_threshold_min),
                 updated_at = NOW()",
        )
        .bind(&row.user_id)
        .bind(briefing_hour)
        .bind(&briefing_timezone)
        .bind(&briefing_language)
        .bind(&briefing_style)
        .bind(&sort_type)
        .bind(&sort_order)
        .bind(conflict_threshold)
        .execute(pool)
        .await?;

        summary.user_settings += 1;
    }

    Ok(summary)
}

pub async fn import_groups(pool: &PgPool, jsonl: &str) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreGroupRow>(jsonl, "groups")?;
    let mut summary = MigrationSummary::default();

    let ns = ns_groups();
    for row in rows {
        let pg_id = to_uuid(&ns, &row.id);
        let max_members = row.max_members.unwrap_or(10);
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);
        let updated_at = parse_optional_rfc3339(&row.updated_at)?.unwrap_or_else(Utc::now);

        sqlx::query(
            "INSERT INTO groups
                (id, name, description, image_url, max_members, invite_code,
                 last_activity_at, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
             ON CONFLICT (id) DO UPDATE
             SET name = EXCLUDED.name,
                 description = EXCLUDED.description,
                 image_url = EXCLUDED.image_url,
                 max_members = EXCLUDED.max_members,
                 invite_code = EXCLUDED.invite_code,
                 last_activity_at = EXCLUDED.last_activity_at,
                 updated_at = EXCLUDED.updated_at",
        )
        .bind(pg_id)
        .bind(&row.name)
        .bind(&row.description)
        .bind(&row.image_url)
        .bind(max_members)
        .bind(&row.invite_code)
        .bind(updated_at)
        .bind(created_at)
        .bind(updated_at)
        .execute(pool)
        .await?;

        summary.groups += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Phase D
// ---------------------------------------------------------------------------

pub async fn import_promises(pool: &PgPool, jsonl: &str) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestorePromiseRow>(jsonl, "promises")?;
    let mut summary = MigrationSummary::default();

    let ns_sched = ns_schedules();
    let ns_grp = ns_groups();

    for row in rows {
        let pg_id = to_uuid(&ns_sched, &row.id);
        let pg_group_id = to_uuid(&ns_grp, &row.group_id);
        let start_at = parse_required_rfc3339(&row.start_at)?;
        let end_at = parse_optional_rfc3339(&row.end_at)?;
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);
        let updated_at = parse_optional_rfc3339(&row.updated_at)?.unwrap_or_else(Utc::now);

        let vote_deadline = row
            .votes
            .as_ref()
            .and_then(|v| v.until.as_ref())
            .map(|s| parse_required_rfc3339(s))
            .transpose()?;

        let minimum_participants = row.minimum_participants.unwrap_or(2);
        let is_confirmed = row.is_confirmed.unwrap_or(false);

        let location = row.location.as_ref();
        let location_name = location.and_then(|l| l.name.clone());
        let location_address = location.and_then(|l| l.address.clone());
        let location_latitude = location.and_then(|l| l.latitude);
        let location_longitude = location.and_then(|l| l.longitude);

        let image_urls: Option<Vec<String>> = row
            .image_urls
            .as_ref()
            .filter(|v| !v.is_empty())
            .cloned();

        let description_blocks = row.description_blocks.as_ref().and_then(|v| {
            if v.is_null() {
                None
            } else {
                Some(v.clone())
            }
        });

        sqlx::query(
            "INSERT INTO schedules
                (id, schedule_type, user_id, title, emoji, description, description_blocks,
                 start_at, end_at, location_name, location_address, location_latitude,
                 location_longitude, group_id, minimum_participants, is_confirmed,
                 vote_deadline, tracking_start_minutes_before, image_urls,
                 created_at, updated_at)
             VALUES
                ($1, 'group', $2, $3, $4, $5, $6,
                 $7, $8, $9, $10, $11, $12,
                 $13, $14, $15, $16, $17, $18,
                 $19, $20)
             ON CONFLICT (id) DO UPDATE
             SET title = EXCLUDED.title,
                 emoji = EXCLUDED.emoji,
                 description = EXCLUDED.description,
                 description_blocks = EXCLUDED.description_blocks,
                 start_at = EXCLUDED.start_at,
                 end_at = EXCLUDED.end_at,
                 location_name = EXCLUDED.location_name,
                 location_address = EXCLUDED.location_address,
                 location_latitude = EXCLUDED.location_latitude,
                 location_longitude = EXCLUDED.location_longitude,
                 minimum_participants = EXCLUDED.minimum_participants,
                 is_confirmed = EXCLUDED.is_confirmed,
                 vote_deadline = EXCLUDED.vote_deadline,
                 tracking_start_minutes_before = EXCLUDED.tracking_start_minutes_before,
                 image_urls = EXCLUDED.image_urls,
                 updated_at = EXCLUDED.updated_at",
        )
        .bind(pg_id)
        .bind(&row.host_id)
        .bind(&row.title)
        .bind(&row.emoji)
        .bind(&row.description)
        .bind(description_blocks.map(|v| sqlx::types::Json(v)))
        .bind(start_at)
        .bind(end_at)
        .bind(&location_name)
        .bind(&location_address)
        .bind(location_latitude)
        .bind(location_longitude)
        .bind(pg_group_id)
        .bind(minimum_participants)
        .bind(is_confirmed)
        .bind(vote_deadline)
        .bind(row.tracking_start_minutes_before)
        .bind(&image_urls)
        .bind(created_at)
        .bind(updated_at)
        .execute(pool)
        .await?;

        summary.schedules += 1;

        // schedule_votes
        if let Some(votes) = &row.votes {
            for user_id in votes.accepted.iter().flatten() {
                upsert_schedule_vote(pool, pg_id, user_id, "accepted").await?;
                summary.schedule_votes += 1;
            }
            for user_id in votes.declined.iter().flatten() {
                upsert_schedule_vote(pool, pg_id, user_id, "declined").await?;
                summary.schedule_votes += 1;
            }
        }
    }

    Ok(summary)
}

async fn upsert_schedule_vote(
    pool: &PgPool,
    schedule_id: Uuid,
    user_id: &str,
    status: &str,
) -> Result<(), AppError> {
    // Only insert if the user exists (votes may reference users not yet migrated)
    let user_exists: (bool,) = sqlx::query_as("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)")
        .bind(user_id)
        .fetch_one(pool)
        .await?;

    if !user_exists.0 {
        return Ok(());
    }

    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status)
         VALUES ($1, $2, $3::vote_status)
         ON CONFLICT (schedule_id, user_id) DO UPDATE
         SET status = EXCLUDED.status",
    )
    .bind(schedule_id)
    .bind(user_id)
    .bind(status)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn import_personal_events(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestorePersonalEventRow>(jsonl, "personal_events")?;
    let mut summary = MigrationSummary::default();

    let ns_pe = ns_personal_events();

    for row in rows {
        let pg_id = to_uuid(&ns_pe, &row.id);
        let start_at = parse_required_rfc3339(&row.start_at)?;
        let end_at = parse_optional_rfc3339(&row.end_at)?;
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);
        let updated_at = parse_optional_rfc3339(&row.updated_at)?.unwrap_or_else(Utc::now);

        let location = row.location.as_ref();
        let location_name = location.and_then(|l| l.name.clone());
        let location_address = location.and_then(|l| l.address.clone());
        let location_latitude = location.and_then(|l| l.latitude);
        let location_longitude = location.and_then(|l| l.longitude);

        let description_blocks = row.description_blocks.as_ref().and_then(|v| {
            if v.is_null() {
                None
            } else {
                Some(v.clone())
            }
        });

        sqlx::query(
            "INSERT INTO schedules
                (id, schedule_type, user_id, title, emoji, description, description_blocks,
                 start_at, end_at, location_name, location_address,
                 location_latitude, location_longitude, reminder_minutes_before,
                 created_at, updated_at)
             VALUES
                ($1, 'personal', $2, $3, $4, $5, $6,
                 $7, $8, $9, $10, $11, $12, $13,
                 $14, $15)
             ON CONFLICT (id) DO UPDATE
             SET title = EXCLUDED.title,
                 emoji = EXCLUDED.emoji,
                 description = EXCLUDED.description,
                 description_blocks = EXCLUDED.description_blocks,
                 start_at = EXCLUDED.start_at,
                 end_at = EXCLUDED.end_at,
                 location_name = EXCLUDED.location_name,
                 location_address = EXCLUDED.location_address,
                 location_latitude = EXCLUDED.location_latitude,
                 location_longitude = EXCLUDED.location_longitude,
                 reminder_minutes_before = EXCLUDED.reminder_minutes_before,
                 updated_at = EXCLUDED.updated_at",
        )
        .bind(pg_id)
        .bind(&row.user_id)
        .bind(&row.title)
        .bind(&row.emoji)
        .bind(&row.description)
        .bind(description_blocks.map(|v| sqlx::types::Json(v)))
        .bind(start_at)
        .bind(end_at)
        .bind(&location_name)
        .bind(&location_address)
        .bind(location_latitude)
        .bind(location_longitude)
        .bind(row.reminder_minutes_before)
        .bind(created_at)
        .bind(updated_at)
        .execute(pool)
        .await?;

        summary.schedules += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Phase E
// ---------------------------------------------------------------------------

pub async fn import_recurring_events(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreRecurringEventRow>(jsonl, "recurring_events")?;
    let mut summary = MigrationSummary::default();

    let ns_re = ns_recurring_events();

    for row in rows {
        let pg_id = to_uuid(&ns_re, &row.id);
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);
        let updated_at = parse_optional_rfc3339(&row.updated_at)?.unwrap_or_else(Utc::now);

        let series_start_date = row
            .series_start_date
            .as_deref()
            .map(parse_date_field)
            .transpose()?
            .unwrap_or_else(|| updated_at.date_naive());

        let series_end_date = parse_optional_date(&row.recurrence.series_end_date)?;

        let excluded_dates: Option<Vec<NaiveDate>> = row
            .excluded_dates
            .as_ref()
            .map(|dates| {
                dates
                    .iter()
                    .map(|s| parse_date_field(s))
                    .collect::<Result<Vec<_>, _>>()
            })
            .transpose()?
            .filter(|v| !v.is_empty());

        let location = row.location.as_ref();
        let location_name = location.and_then(|l| l.name.clone());
        let location_address = location.and_then(|l| l.address.clone());
        let location_latitude = location.and_then(|l| l.latitude);
        let location_longitude = location.and_then(|l| l.longitude);

        let end_time_hour = row.end_time.as_ref().map(|t| t.hour);
        let end_time_minute = row.end_time.as_ref().map(|t| t.minute);

        let overrides_json = row
            .overrides
            .as_ref()
            .filter(|v| !v.is_null() && v != &&Value::Object(Default::default()))
            .map(|v| sqlx::types::Json(v.clone()));

        let days_of_week: Option<Vec<i16>> = row.recurrence.days_of_week.clone();

        sqlx::query(
            "INSERT INTO recurring_schedules
                (id, user_id, title, emoji, description,
                 start_time_hour, start_time_minute, end_time_hour, end_time_minute,
                 location_name, location_address, location_latitude, location_longitude,
                 reminder_minutes_before, frequency, days_of_week, day_of_month,
                 series_start_date, series_end_date, excluded_dates, overrides,
                 created_at, updated_at)
             VALUES
                ($1, $2, $3, $4, $5,
                 $6, $7, $8, $9,
                 $10, $11, $12, $13,
                 $14, $15::recurrence_frequency, $16, $17,
                 $18, $19, $20, $21,
                 $22, $23)
             ON CONFLICT (id) DO UPDATE
             SET title = EXCLUDED.title,
                 emoji = EXCLUDED.emoji,
                 description = EXCLUDED.description,
                 start_time_hour = EXCLUDED.start_time_hour,
                 start_time_minute = EXCLUDED.start_time_minute,
                 end_time_hour = EXCLUDED.end_time_hour,
                 end_time_minute = EXCLUDED.end_time_minute,
                 location_name = EXCLUDED.location_name,
                 location_address = EXCLUDED.location_address,
                 location_latitude = EXCLUDED.location_latitude,
                 location_longitude = EXCLUDED.location_longitude,
                 reminder_minutes_before = EXCLUDED.reminder_minutes_before,
                 frequency = EXCLUDED.frequency,
                 days_of_week = EXCLUDED.days_of_week,
                 day_of_month = EXCLUDED.day_of_month,
                 series_start_date = EXCLUDED.series_start_date,
                 series_end_date = EXCLUDED.series_end_date,
                 excluded_dates = EXCLUDED.excluded_dates,
                 overrides = EXCLUDED.overrides,
                 updated_at = EXCLUDED.updated_at",
        )
        .bind(pg_id)
        .bind(&row.user_id)
        .bind(&row.title)
        .bind(&row.emoji)
        .bind(&row.description)
        .bind(row.start_time.hour)
        .bind(row.start_time.minute)
        .bind(end_time_hour)
        .bind(end_time_minute)
        .bind(&location_name)
        .bind(&location_address)
        .bind(location_latitude)
        .bind(location_longitude)
        .bind(row.reminder_minutes_before)
        .bind(&row.recurrence.frequency)
        .bind(&days_of_week)
        .bind(row.recurrence.day_of_month)
        .bind(series_start_date)
        .bind(series_end_date)
        .bind(&excluded_dates)
        .bind(overrides_json)
        .bind(created_at)
        .bind(updated_at)
        .execute(pool)
        .await?;

        summary.recurring_schedules += 1;
    }

    Ok(summary)
}

pub async fn import_notifications(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreNotificationRow>(jsonl, "notifications")?;
    let mut summary = MigrationSummary::default();

    let ns_notif = ns_notifications();
    let ns_sched = ns_schedules();
    let ns_grp = ns_groups();

    for row in rows {
        // Skip notifications for non-existent users (deleted accounts)
        let user_exists: bool =
            sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)")
                .bind(&row.user_id)
                .fetch_one(pool)
                .await?;
        if !user_exists {
            continue;
        }

        let pg_id = to_uuid(&ns_notif, &row.id);
        let mapped_type = map_notification_type(&row.notification_type);
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);
        let read_at = parse_optional_rfc3339(&row.read_at)?;
        let delivered_at = parse_optional_rfc3339(&row.delivered_at)?;

        let schedule_id_candidate = row
            .promise_id
            .as_deref()
            .filter(|s| !s.is_empty())
            .map(|s| to_uuid(&ns_sched, s));

        // FK check: only set schedule_id if the schedule actually exists in PG
        let schedule_id = if let Some(sid) = schedule_id_candidate {
            let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM schedules WHERE id = $1)")
                .bind(sid)
                .fetch_one(pool)
                .await?;
            if exists { Some(sid) } else { None }
        } else {
            None
        };

        let group_id_candidate = row
            .group_id
            .as_deref()
            .filter(|s| !s.is_empty())
            .map(|s| to_uuid(&ns_grp, s));

        // FK check: only set group_id if the group actually exists in PG
        let group_id = if let Some(gid) = group_id_candidate {
            let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM groups WHERE id = $1)")
                .bind(gid)
                .fetch_one(pool)
                .await?;
            if exists { Some(gid) } else { None }
        } else {
            None
        };

        let data_json = row
            .data
            .as_ref()
            .filter(|v| !v.is_null())
            .map(|v| sqlx::types::Json(v.clone()));

        sqlx::query(
            "INSERT INTO notifications
                (id, user_id, notification_type, title, body,
                 schedule_id, group_id, related_user_id,
                 is_read, is_delivered, created_at, read_at, delivered_at, data)
             VALUES
                ($1, $2, $3::notification_type, $4, $5,
                 $6, $7, $8,
                 $9, $10, $11, $12, $13, $14)
             ON CONFLICT (id) DO UPDATE
             SET notification_type = EXCLUDED.notification_type,
                 title = EXCLUDED.title,
                 body = EXCLUDED.body,
                 schedule_id = EXCLUDED.schedule_id,
                 group_id = EXCLUDED.group_id,
                 related_user_id = EXCLUDED.related_user_id,
                 is_read = EXCLUDED.is_read,
                 is_delivered = EXCLUDED.is_delivered",
        )
        .bind(pg_id)
        .bind(&row.user_id)
        .bind(mapped_type)
        .bind(&row.title)
        .bind(&row.body)
        .bind(schedule_id)
        .bind(group_id)
        .bind(&row.related_user_id)
        .bind(row.is_read.unwrap_or(false))
        .bind(row.is_delivered.unwrap_or(false))
        .bind(created_at)
        .bind(read_at)
        .bind(delivered_at)
        .bind(data_json)
        .execute(pool)
        .await?;

        summary.notifications += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Phase F: subscriptions (reuse subscription_backfill_service)
// ---------------------------------------------------------------------------

async fn import_subscriptions_phase(
    pool: &PgPool,
    subscriptions_jsonl: &str,
    owners_jsonl: &str,
    overrides_jsonl: &str,
) -> Result<SubscriptionMigrationSummary, AppError> {
    // Pre-process: export uses _id for doc ID, backfill types expect userId field.
    // Inject userId from _id for subscriptions and entitlementOverrides (keyed by userId).
    fn inject_user_id_from_doc_id(jsonl: &str) -> String {
        jsonl
            .lines()
            .filter(|line| !line.trim().is_empty())
            .map(|line| {
                if let Ok(mut obj) = serde_json::from_str::<serde_json::Value>(line) {
                    if let Some(id) = obj.get("_id").cloned() {
                        obj.as_object_mut()
                            .unwrap()
                            .entry("userId")
                            .or_insert(id);
                    }
                    serde_json::to_string(&obj).unwrap_or_else(|_| line.to_string())
                } else {
                    line.to_string()
                }
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    let patched_subs = inject_user_id_from_doc_id(subscriptions_jsonl);
    let patched_overrides = inject_user_id_from_doc_id(overrides_jsonl);

    // subscriptionOwners: _id is originalTransactionId, needs userId from the doc
    // The export already includes userId field in the doc data, so just use _id → originalTransactionId
    fn inject_owner_id(jsonl: &str) -> String {
        jsonl
            .lines()
            .filter(|line| !line.trim().is_empty())
            .map(|line| {
                if let Ok(mut obj) = serde_json::from_str::<serde_json::Value>(line) {
                    if let Some(id) = obj.get("_id").cloned() {
                        obj.as_object_mut()
                            .unwrap()
                            .entry("originalTransactionId")
                            .or_insert(id);
                    }
                    serde_json::to_string(&obj).unwrap_or_else(|_| line.to_string())
                } else {
                    line.to_string()
                }
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    let patched_owners = inject_owner_id(owners_jsonl);

    let subscription_rows =
        parse_jsonl_rows::<FirestoreSubscriptionRow>(&patched_subs, "subscriptions")?;
    let owner_rows = parse_jsonl_rows::<FirestoreSubscriptionOwnerRow>(
        &patched_owners,
        "subscriptionOwners",
    )?;
    let override_rows = parse_jsonl_rows::<FirestoreEntitlementOverrideRow>(
        &patched_overrides,
        "entitlementOverrides",
    )?;

    let mut summary = SubscriptionMigrationSummary::default();
    let mut entitlement_user_ids: BTreeSet<String> = BTreeSet::new();

    for row in subscription_rows {
        let user_id = row.user_id.clone();
        backfill_subscription(pool, row).await?;
        entitlement_user_ids.insert(user_id);
        summary.subscriptions += 1;
    }

    for row in owner_rows {
        backfill_subscription_owner(pool, row).await?;
        summary.subscription_owners += 1;
    }

    for row in override_rows {
        let user_id = row.user_id.clone();
        backfill_entitlement_override(pool, row).await?;
        entitlement_user_ids.insert(user_id);
        summary.entitlement_overrides += 1;
    }

    for user_id in &entitlement_user_ids {
        recompute_entitlement(pool, user_id.as_str()).await?;
        summary.entitlements_recomputed += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Phase G
// ---------------------------------------------------------------------------

pub async fn import_briefing_subscriptions(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows =
        parse_jsonl_rows::<FirestoreBriefingSubscriptionRow>(jsonl, "briefing_subscriptions")?;
    let mut summary = MigrationSummary::default();

    for row in rows {
        let next_dispatch_at = parse_required_rfc3339(&row.next_dispatch_at)?;
        let default_loc = row.default_location.as_ref();
        let default_location_title = default_loc.and_then(|l| l.title.clone());
        let default_location_latitude = default_loc.and_then(|l| l.latitude);
        let default_location_longitude = default_loc.and_then(|l| l.longitude);

        sqlx::query(
            "INSERT INTO briefing_subscriptions
                (user_id, notification_hour, timezone, language, style,
                 next_dispatch_at, default_location_title,
                 default_location_latitude, default_location_longitude)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
             ON CONFLICT (user_id) DO UPDATE
             SET notification_hour = EXCLUDED.notification_hour,
                 timezone = EXCLUDED.timezone,
                 language = EXCLUDED.language,
                 style = EXCLUDED.style,
                 next_dispatch_at = EXCLUDED.next_dispatch_at,
                 default_location_title = EXCLUDED.default_location_title,
                 default_location_latitude = EXCLUDED.default_location_latitude,
                 default_location_longitude = EXCLUDED.default_location_longitude,
                 updated_at = NOW()",
        )
        .bind(&row.id)
        .bind(row.notification_hour)
        .bind(&row.timezone)
        .bind(&row.language)
        .bind(&row.style)
        .bind(next_dispatch_at)
        .bind(&default_location_title)
        .bind(default_location_latitude)
        .bind(default_location_longitude)
        .execute(pool)
        .await?;

        summary.briefing_subscriptions += 1;
    }

    Ok(summary)
}

pub async fn import_admin_audit_logs(
    pool: &PgPool,
    jsonl: &str,
) -> Result<MigrationSummary, AppError> {
    let rows = parse_jsonl_rows::<FirestoreAdminAuditLogRow>(jsonl, "admin_audit_logs")?;
    let mut summary = MigrationSummary::default();

    let ns_al = ns_audit_logs();

    for row in rows {
        let pg_id = to_uuid(&ns_al, &row.id);
        let created_at = parse_optional_rfc3339(&row.created_at)?.unwrap_or_else(Utc::now);

        let before_data = row
            .before_data
            .as_ref()
            .filter(|v| !v.is_null())
            .map(|v| sqlx::types::Json(v.clone()));

        let after_data = row
            .after_data
            .as_ref()
            .filter(|v| !v.is_null())
            .map(|v| sqlx::types::Json(v.clone()));

        sqlx::query(
            "INSERT INTO admin_audit_logs
                (id, actor_id, action, target_id, target_type, before_data, after_data, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             ON CONFLICT (id) DO UPDATE
             SET actor_id = EXCLUDED.actor_id,
                 action = EXCLUDED.action,
                 target_id = EXCLUDED.target_id,
                 target_type = EXCLUDED.target_type,
                 before_data = EXCLUDED.before_data,
                 after_data = EXCLUDED.after_data",
        )
        .bind(pg_id)
        .bind(&row.actor_id)
        .bind(&row.action)
        .bind(&row.target_id)
        .bind(&row.target_type)
        .bind(before_data)
        .bind(after_data)
        .bind(created_at)
        .execute(pool)
        .await?;

        summary.admin_audit_logs += 1;
    }

    Ok(summary)
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

#[allow(clippy::too_many_arguments)]
pub async fn run_data_migration(
    pool: &PgPool,
    users_jsonl: &str,
    auth_accounts_jsonl: &str,
    user_settings_jsonl: &str,
    groups_jsonl: &str,
    promises_jsonl: &str,
    personal_events_jsonl: &str,
    recurring_events_jsonl: &str,
    notifications_jsonl: &str,
    subscriptions_jsonl: &str,
    owners_jsonl: &str,
    overrides_jsonl: &str,
    briefing_subscriptions_jsonl: &str,
    admin_users_jsonl: &str,
    admin_audit_logs_jsonl: &str,
) -> Result<FullMigrationSummary, AppError> {
    let mut core = MigrationSummary::default();

    // Phase A
    tracing::info!("Phase A: users, auth_accounts, admin_users");
    core = core + import_users(pool, users_jsonl).await?;
    core = core + import_auth_accounts(pool, auth_accounts_jsonl).await?;
    core = core + import_admin_users(pool, admin_users_jsonl).await?;

    // Phase B
    tracing::info!("Phase B: user_settings, groups");
    core = core + import_user_settings(pool, user_settings_jsonl).await?;
    core = core + import_groups(pool, groups_jsonl).await?;

    // Phase C: group_members backfill — groups are now present so re-process users map.
    tracing::info!("Phase C: group_members backfill from users.groups map");
    {
        let user_rows = parse_jsonl_rows::<FirestoreUserRow>(users_jsonl, "users")?;
        let ns_grp = ns_groups();
        for row in user_rows {
            for (firestore_group_id, group_info) in &row.groups {
                let pg_group_id = to_uuid(&ns_grp, firestore_group_id);
                let exists: (bool,) =
                    sqlx::query_as("SELECT EXISTS(SELECT 1 FROM groups WHERE id = $1)")
                        .bind(pg_group_id)
                        .fetch_one(pool)
                        .await?;
                if !exists.0 {
                    continue;
                }
                upsert_group_member(pool, pg_group_id, &row.id, group_info).await?;
                core.group_members += 1;
            }
        }
    }

    // Phase D
    tracing::info!("Phase D: schedules");
    core = core + import_promises(pool, promises_jsonl).await?;
    core = core + import_personal_events(pool, personal_events_jsonl).await?;

    // Phase E
    tracing::info!("Phase E: recurring_schedules, notifications");
    core = core + import_recurring_events(pool, recurring_events_jsonl).await?;
    core = core + import_notifications(pool, notifications_jsonl).await?;

    // Phase F
    tracing::info!("Phase F: subscriptions, entitlements");
    let subscription =
        import_subscriptions_phase(pool, subscriptions_jsonl, owners_jsonl, overrides_jsonl)
            .await?;

    // Phase G
    tracing::info!("Phase G: briefing_subscriptions, admin_audit_logs");
    core = core + import_briefing_subscriptions(pool, briefing_subscriptions_jsonl).await?;
    core = core + import_admin_audit_logs(pool, admin_audit_logs_jsonl).await?;

    Ok(FullMigrationSummary { core, subscription })
}
