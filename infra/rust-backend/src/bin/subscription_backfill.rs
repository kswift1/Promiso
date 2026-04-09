use std::env;
use std::fs;
use std::process;

use promiso_backend::services::subscription_backfill_service::run_jsonl_backfill;
use sqlx::postgres::PgPoolOptions;

struct Args {
    subscriptions: Option<String>,
    subscription_owners: Option<String>,
    entitlement_overrides: Option<String>,
}

impl Args {
    fn parse() -> Result<Self, String> {
        let mut args = env::args().skip(1);
        let mut parsed = Self {
            subscriptions: None,
            subscription_owners: None,
            entitlement_overrides: None,
        };

        while let Some(flag) = args.next() {
            if matches!(flag.as_str(), "--help" | "-h") {
                return Err(usage().to_string());
            }

            let value = args
                .next()
                .ok_or_else(|| format!("missing value for {flag}"))?;

            match flag.as_str() {
                "--subscriptions" => parsed.subscriptions = Some(value),
                "--subscription-owners" => parsed.subscription_owners = Some(value),
                "--entitlement-overrides" => parsed.entitlement_overrides = Some(value),
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

    let subscriptions = read_optional_file(args.subscriptions.as_deref(), "subscriptions")?;
    let subscription_owners =
        read_optional_file(args.subscription_owners.as_deref(), "subscription owners")?;
    let entitlement_overrides = read_optional_file(
        args.entitlement_overrides.as_deref(),
        "entitlement overrides",
    )?;

    let summary = run_jsonl_backfill(
        &pool,
        &subscriptions,
        &subscription_owners,
        &entitlement_overrides,
    )
    .await
    .map_err(|error| format!("subscription backfill failed: {error}"))?;

    println!(
        "subscription backfill completed: subscriptions={}, subscription_owners={}, entitlement_overrides={}, entitlements_recomputed={}",
        summary.subscriptions,
        summary.subscription_owners,
        summary.entitlement_overrides,
        summary.entitlements_recomputed,
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
    "usage: cargo run --bin subscription_backfill -- \
  [--subscriptions path/to/subscriptions.jsonl] \
  [--subscription-owners path/to/subscription_owners.jsonl] \
  [--entitlement-overrides path/to/entitlement_overrides.jsonl]"
}
