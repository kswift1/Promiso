use std::env;
use std::fs;
use std::process;

use promiso_backend::services::data_migration_service::run_data_migration;
use sqlx::postgres::PgPoolOptions;

struct Args {
    users: Option<String>,
    auth_accounts: Option<String>,
    user_settings: Option<String>,
    groups: Option<String>,
    promises: Option<String>,
    personal_events: Option<String>,
    recurring_events: Option<String>,
    notifications: Option<String>,
    subscriptions: Option<String>,
    subscription_owners: Option<String>,
    entitlement_overrides: Option<String>,
    briefing_subscriptions: Option<String>,
    admin_users: Option<String>,
    admin_audit_logs: Option<String>,
}

impl Args {
    fn parse() -> Result<Self, String> {
        let mut args = env::args().skip(1);
        let mut parsed = Self {
            users: None,
            auth_accounts: None,
            user_settings: None,
            groups: None,
            promises: None,
            personal_events: None,
            recurring_events: None,
            notifications: None,
            subscriptions: None,
            subscription_owners: None,
            entitlement_overrides: None,
            briefing_subscriptions: None,
            admin_users: None,
            admin_audit_logs: None,
        };

        while let Some(flag) = args.next() {
            if matches!(flag.as_str(), "--help" | "-h") {
                return Err(usage().to_string());
            }

            let value = args
                .next()
                .ok_or_else(|| format!("missing value for {flag}"))?;

            match flag.as_str() {
                "--users" => parsed.users = Some(value),
                "--auth-accounts" => parsed.auth_accounts = Some(value),
                "--user-settings" => parsed.user_settings = Some(value),
                "--groups" => parsed.groups = Some(value),
                "--promises" => parsed.promises = Some(value),
                "--personal-events" => parsed.personal_events = Some(value),
                "--recurring-events" => parsed.recurring_events = Some(value),
                "--notifications" => parsed.notifications = Some(value),
                "--subscriptions" => parsed.subscriptions = Some(value),
                "--subscription-owners" => parsed.subscription_owners = Some(value),
                "--entitlement-overrides" => parsed.entitlement_overrides = Some(value),
                "--briefing-subscriptions" => parsed.briefing_subscriptions = Some(value),
                "--admin-users" => parsed.admin_users = Some(value),
                "--admin-audit-logs" => parsed.admin_audit_logs = Some(value),
                _ => return Err(format!("unknown flag: {flag}\n\n{}", usage())),
            }
        }

        Ok(parsed)
    }
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    if let Err(message) = run().await {
        eprintln!("{message}");
        process::exit(1);
    }
}

async fn run() -> Result<(), String> {
    let args = Args::parse()?;
    let database_url =
        env::var("DATABASE_URL").map_err(|_| "DATABASE_URL is required".to_string())?;

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .map_err(|error| format!("failed to connect database: {error}"))?;

    let users = read_optional_file(args.users.as_deref(), "users")?;
    let auth_accounts = read_optional_file(args.auth_accounts.as_deref(), "auth_accounts")?;
    let user_settings = read_optional_file(args.user_settings.as_deref(), "user_settings")?;
    let groups = read_optional_file(args.groups.as_deref(), "groups")?;
    let promises = read_optional_file(args.promises.as_deref(), "promises")?;
    let personal_events = read_optional_file(args.personal_events.as_deref(), "personal_events")?;
    let recurring_events =
        read_optional_file(args.recurring_events.as_deref(), "recurring_events")?;
    let notifications = read_optional_file(args.notifications.as_deref(), "notifications")?;
    let subscriptions = read_optional_file(args.subscriptions.as_deref(), "subscriptions")?;
    let subscription_owners =
        read_optional_file(args.subscription_owners.as_deref(), "subscription_owners")?;
    let entitlement_overrides = read_optional_file(
        args.entitlement_overrides.as_deref(),
        "entitlement_overrides",
    )?;
    let briefing_subscriptions = read_optional_file(
        args.briefing_subscriptions.as_deref(),
        "briefing_subscriptions",
    )?;
    let admin_users = read_optional_file(args.admin_users.as_deref(), "admin_users")?;
    let admin_audit_logs =
        read_optional_file(args.admin_audit_logs.as_deref(), "admin_audit_logs")?;

    let summary = run_data_migration(
        &pool,
        &users,
        &auth_accounts,
        &user_settings,
        &groups,
        &promises,
        &personal_events,
        &recurring_events,
        &notifications,
        &subscriptions,
        &subscription_owners,
        &entitlement_overrides,
        &briefing_subscriptions,
        &admin_users,
        &admin_audit_logs,
    )
    .await
    .map_err(|error| format!("data migration failed: {error}"))?;

    println!(
        "data migration completed:\n  \
         users={}\n  \
         auth_accounts={}\n  \
         user_settings={}\n  \
         devices={}\n  \
         notification_endpoints={}\n  \
         live_activity_endpoints={}\n  \
         groups={}\n  \
         group_members={}\n  \
         schedules={}\n  \
         schedule_votes={}\n  \
         recurring_schedules={}\n  \
         notifications={}\n  \
         subscriptions={}\n  \
         subscription_owners={}\n  \
         entitlement_overrides={}\n  \
         entitlements_recomputed={}\n  \
         briefing_subscriptions={}\n  \
         admin_users={}\n  \
         admin_audit_logs={}",
        summary.users(),
        summary.auth_accounts(),
        summary.user_settings(),
        summary.devices(),
        summary.notification_endpoints(),
        summary.live_activity_endpoints(),
        summary.groups(),
        summary.group_members(),
        summary.schedules(),
        summary.schedule_votes(),
        summary.recurring_schedules(),
        summary.notifications(),
        summary.subscriptions(),
        summary.subscription_owners(),
        summary.entitlement_overrides(),
        summary.entitlements_recomputed(),
        summary.briefing_subscriptions(),
        summary.admin_users(),
        summary.admin_audit_logs(),
    );

    Ok(())
}

fn read_optional_file(path: Option<&str>, label: &str) -> Result<String, String> {
    match path {
        Some(path) => fs::read_to_string(path)
            .map_err(|error| format!("failed to read {label} file {path}: {error}")),
        None => Ok(String::new()),
    }
}

fn usage() -> &'static str {
    "usage: cargo run --bin data_migration -- \
  [--users path/to/users.jsonl] \
  [--auth-accounts path/to/auth_accounts.jsonl] \
  [--user-settings path/to/user_settings.jsonl] \
  [--groups path/to/groups.jsonl] \
  [--promises path/to/promises.jsonl] \
  [--personal-events path/to/personal_events.jsonl] \
  [--recurring-events path/to/recurring_events.jsonl] \
  [--notifications path/to/notifications.jsonl] \
  [--subscriptions path/to/subscriptions.jsonl] \
  [--subscription-owners path/to/subscription_owners.jsonl] \
  [--entitlement-overrides path/to/entitlement_overrides.jsonl] \
  [--briefing-subscriptions path/to/briefing_subscriptions.jsonl] \
  [--admin-users path/to/admin_users.jsonl] \
  [--admin-audit-logs path/to/admin_audit_logs.jsonl]"
}
