use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use promiso_backend::config::Config;
use promiso_backend::middleware::auth::ServerAuth;
use promiso_backend::models::auth::CreateSessionInput;
use promiso_backend::routes;
use promiso_backend::services::auth_service;
use sqlx::PgPool;
use tower::ServiceExt;

fn test_config() -> Config {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "test-project");
    std::env::set_var("AUTH_JWT_SECRET", "test-server-secret");
    std::env::set_var("AUTH_JWT_ISSUER", "promiso-test");
    Config::from_env()
}

fn server_auth() -> ServerAuth {
    ServerAuth::new(
        Some("test-server-secret".to_string()),
        "promiso-test".to_string(),
        900,
    )
}

async fn insert_auth_account(pool: &PgPool, user_id: &str) {
    sqlx::query(
        "INSERT INTO auth_accounts \
         (user_id, provider_type, provider_uid, email, display_name, profile_image_url) \
         VALUES ($1, 'google', $2, $3, $4, $5)",
    )
    .bind(user_id)
    .bind(format!("provider-{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .bind(format!("display-{user_id}"))
    .bind(format!("https://example.com/{user_id}.jpg"))
    .execute(pool)
    .await
    .expect("insert auth account");
}

#[sqlx::test(migrations = "./migrations")]
async fn faq_public_route_exists_and_reports_missing_secret(pool: PgPool) {
    std::env::remove_var("NOTION_FAQ_API_KEY");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .uri("/api/v1/faq")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::PRECONDITION_FAILED);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["error"]["code"], "failed-precondition");
}

#[sqlx::test(migrations = "./migrations")]
async fn weather_route_exists_and_reports_missing_secret(pool: PgPool) {
    std::env::remove_var("KMA_API_KEY");
    insert_auth_account(&pool, "weather_route_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "weather_route_user".to_string(),
            device_id: "device-weather".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/weather")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "latitude": 37.5665,
                        "longitude": 126.9780,
                        "target_date": "2026-04-09T09:00:00Z"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::PRECONDITION_FAILED);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["error"]["code"], "failed-precondition");
}

#[sqlx::test(migrations = "./migrations")]
async fn transportation_route_exists_and_returns_walking_only_without_secrets(pool: PgPool) {
    std::env::remove_var("ODSAY_API_KEY");
    std::env::remove_var("KAKAO_REST_API_KEY");
    insert_auth_account(&pool, "transportation_route_user").await;

    let tokens = auth_service::create_session(
        &pool,
        &server_auth(),
        CreateSessionInput {
            user_id: "transportation_route_user".to_string(),
            device_id: "device-transportation".to_string(),
            platform: "ios".to_string(),
            app_version: None,
            user_agent: None,
        },
    )
    .await
    .expect("create session");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/transportation")
                .header("authorization", format!("Bearer {}", tokens.access_token))
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({
                        "from_lat": 37.5665,
                        "from_lng": 126.9780,
                        "to_lat": 37.5680,
                        "to_lng": 126.9820
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["data"]["transit_routes"], serde_json::json!([]));
    assert!(json["data"]["driving"].is_null());
    assert!(json["data"]["walking_minutes"].as_i64().unwrap_or(0) > 0);
    assert!(json["data"]["walking_distance_km"].as_f64().unwrap_or(0.0) > 0.0);
}
