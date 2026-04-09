use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::routes;
use sqlx::PgPool;
use tower::ServiceExt;

fn test_config() -> Config {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");
    Config::from_env()
}

#[sqlx::test(migrations = "./migrations")]
async fn app_config_public_route_returns_seeded_config(pool: PgPool) {
    let app = routes::create_router(pool, &test_config());

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/app-config")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["data"]["forceUpdateVersion"], "0.0.0");
    assert_eq!(json["data"]["recommendedVersion"], "0.0.0");
    assert_eq!(
        json["data"]["appStoreURL"],
        "https://apps.apple.com/kr/app/id6757733720"
    );
}
