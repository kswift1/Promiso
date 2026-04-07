use std::sync::Arc;

use promiso_backend::config::Config;
use promiso_backend::routes;
use promiso_backend::services::apns_service::RealApnsSender;
use promiso_backend::services::app_store_service::{RealAppStoreVerifier, SharedAppStoreVerifier};
use promiso_backend::services::task_executor;

use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .init();

    let config = Config::from_env();

    // 마이그레이션은 direct connection 사용 (PgBouncer에서 prepared statement 충돌 방지)
    let migrate_pool = sqlx::PgPool::connect(&config.database_url)
        .await
        .expect("Failed to connect to database for migration");

    sqlx::migrate!()
        .run(&migrate_pool)
        .await
        .expect("Failed to run migrations");

    migrate_pool.close().await;

    // 런타임은 pooled connection 사용
    let pool = sqlx::PgPool::connect(&config.database_pool_url)
        .await
        .expect("Failed to connect to database pool");

    // APNs sender (라우터 + 폴링 루프에서 공유)
    let apns_sender = Arc::new(RealApnsSender::new(&config));
    let app_store_verifier: SharedAppStoreVerifier = Arc::new(RealAppStoreVerifier::new(&config));

    let app = routes::create_router(
        pool.clone(),
        &config,
        apns_sender.clone(),
        app_store_verifier,
    );

    // 백그라운드: scheduled_tasks 폴링 루프
    let poll_pool = pool.clone();
    let poll_apns = apns_sender.clone();
    tokio::spawn(async move {
        task_executor::start_polling_loop(poll_pool, poll_apns).await;
    });

    // [::]:port -> IPv4 + IPv6 동시 바인딩 (iOS 시뮬레이터 호환)
    let addr = format!("[::]:{}", config.port);
    tracing::info!("Starting server on {}", addr);

    let listener = TcpListener::bind(&addr)
        .await
        .expect("Failed to bind address");
    axum::serve(listener, app).await.expect("Server error");
}
