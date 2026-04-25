pub struct Config {
    pub database_url: String,
    pub database_pool_url: String,
    pub port: u16,
    pub firebase_project_id: String,
    pub gcs_upload_bucket: Option<String>,
    pub gcs_signed_url_ttl_seconds: u32,
    pub auth_jwt_secret: Option<String>,
    pub auth_jwt_issuer: String,
    pub auth_access_token_ttl_seconds: i64,
    pub app_store_apple_id: Option<i64>,
    pub google_application_credentials: Option<String>,
    pub firebase_service_account_json: Option<String>,
    pub apns_key_id: Option<String>,
    pub apns_team_id: Option<String>,
    pub apns_auth_key: Option<String>,
    pub apns_auth_key_path: Option<String>,
    pub apns_bundle_id: Option<String>,
    pub apns_environment: String,
    pub widget_jwt_secret: Option<String>,
    pub odsay_api_key: Option<String>,
    pub kakao_rest_api_key: Option<String>,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();

        let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

        let database_pool_url =
            std::env::var("DATABASE_POOL_URL").unwrap_or_else(|_| database_url.clone());
        let apns_environment =
            std::env::var("APNS_ENVIRONMENT").unwrap_or_else(|_| "development".to_string());

        Self {
            database_url,
            database_pool_url,
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .expect("PORT must be a valid number"),
            firebase_project_id: std::env::var("FIREBASE_PROJECT_ID")
                .expect("FIREBASE_PROJECT_ID must be set"),
            gcs_upload_bucket: std::env::var("GCS_UPLOAD_BUCKET").ok(),
            gcs_signed_url_ttl_seconds: std::env::var("GCS_SIGNED_URL_TTL_SECONDS")
                .unwrap_or_else(|_| "900".to_string())
                .parse()
                .expect("GCS_SIGNED_URL_TTL_SECONDS must be a valid number"),
            auth_jwt_secret: std::env::var("AUTH_JWT_SECRET").ok(),
            auth_jwt_issuer: std::env::var("AUTH_JWT_ISSUER")
                .unwrap_or_else(|_| "promiso".to_string()),
            auth_access_token_ttl_seconds: std::env::var("AUTH_ACCESS_TOKEN_TTL_SECONDS")
                .unwrap_or_else(|_| "900".to_string())
                .parse()
                .expect("AUTH_ACCESS_TOKEN_TTL_SECONDS must be a valid number"),
            app_store_apple_id: std::env::var("APP_STORE_APPLE_ID")
                .ok()
                .and_then(|value| value.parse().ok())
                .or_else(|| {
                    if apns_environment == "production" {
                        Some(1625074042)
                    } else {
                        None
                    }
                }),
            google_application_credentials: std::env::var("GOOGLE_APPLICATION_CREDENTIALS").ok(),
            firebase_service_account_json: std::env::var("FIREBASE_SERVICE_ACCOUNT_JSON").ok(),
            apns_key_id: std::env::var("APNS_KEY_ID").ok(),
            apns_team_id: std::env::var("APNS_TEAM_ID").ok(),
            apns_auth_key: std::env::var("APNS_AUTH_KEY")
                .ok()
                .map(|value| value.replace("\\n", "\n")),
            apns_auth_key_path: std::env::var("APNS_AUTH_KEY_PATH").ok(),
            apns_bundle_id: std::env::var("APNS_BUNDLE_ID").ok(),
            apns_environment,
            widget_jwt_secret: std::env::var("WIDGET_JWT_SECRET").ok(),
            odsay_api_key: std::env::var("ODSAY_API_KEY").ok(),
            kakao_rest_api_key: std::env::var("KAKAO_REST_API_KEY").ok(),
        }
    }
}
