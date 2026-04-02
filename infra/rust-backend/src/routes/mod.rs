mod health;

use axum::Router;
use sqlx::PgPool;

pub fn create_router(pool: PgPool) -> Router {
    Router::new()
        .merge(health::router())
        .with_state(pool)
}
