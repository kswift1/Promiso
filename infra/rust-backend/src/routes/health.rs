use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};
use sqlx::PgPool;

pub fn router() -> Router<PgPool> {
    Router::new().route("/health", get(health_check))
}

async fn health_check(State(pool): State<PgPool>) -> Json<Value> {
    let db_ok = sqlx::query("SELECT 1").execute(&pool).await.is_ok();

    Json(json!({
        "status": if db_ok { "healthy" } else { "degraded" },
        "db": db_ok,
    }))
}
