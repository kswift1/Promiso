use promiso_backend::config::Config;
use promiso_backend::routes;

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

    let app = routes::create_router(pool);

    let addr = format!("0.0.0.0:{}", config.port);
    tracing::info!("Starting server on {}", addr);

    let listener = TcpListener::bind(&addr).await.expect("Failed to bind address");
    axum::serve(listener, app).await.expect("Server error");
}
