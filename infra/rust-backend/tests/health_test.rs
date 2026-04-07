use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::routes;
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test(migrations = "./migrations")]
async fn health_returns_healthy_when_db_is_available(pool: PgPool) {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");

    let config = Config::from_env();
    let app = routes::create_router(pool, &config);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["status"], "healthy");
    assert_eq!(json["db"], true);
}
