mod health;

use axum::Router;
use sqlx::PgPool;

use crate::config::Config;
use crate::middleware::auth::FirebaseAuth;

pub fn create_router(pool: PgPool, config: &Config) -> Router {
    let firebase_auth = FirebaseAuth::new(config.firebase_project_id.clone());

    Router::new()
        .merge(health::router())
        .layer(axum::Extension(firebase_auth))
        .with_state(pool)
}
