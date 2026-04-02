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

    let pool = sqlx::PgPool::connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    let app = routes::create_router(pool);

    let addr = format!("0.0.0.0:{}", config.port);
    tracing::info!("Starting server on {}", addr);

    let listener = TcpListener::bind(&addr).await.expect("Failed to bind address");
    axum::serve(listener, app).await.expect("Server error");
}
