pub struct Config {
    pub database_url: String,
    pub database_pool_url: String,
    pub port: u16,
    pub firebase_project_id: String,
    pub google_application_credentials: Option<String>,
    pub firebase_service_account_json: Option<String>,
    pub apns_key_id: Option<String>,
    pub apns_team_id: Option<String>,
    pub apns_auth_key: Option<String>,
    pub apns_auth_key_path: Option<String>,
    pub apns_bundle_id: Option<String>,
    pub widget_jwt_secret: Option<String>,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();

        let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

        let database_pool_url =
            std::env::var("DATABASE_POOL_URL").unwrap_or_else(|_| database_url.clone());

        Self {
            database_url,
            database_pool_url,
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .expect("PORT must be a valid number"),
            firebase_project_id: std::env::var("FIREBASE_PROJECT_ID")
                .expect("FIREBASE_PROJECT_ID must be set"),
            google_application_credentials: std::env::var("GOOGLE_APPLICATION_CREDENTIALS").ok(),
            firebase_service_account_json: std::env::var("FIREBASE_SERVICE_ACCOUNT_JSON").ok(),
            apns_key_id: std::env::var("APNS_KEY_ID").ok(),
            apns_team_id: std::env::var("APNS_TEAM_ID").ok(),
            apns_auth_key: std::env::var("APNS_AUTH_KEY").ok(),
            apns_auth_key_path: std::env::var("APNS_AUTH_KEY_PATH").ok(),
            apns_bundle_id: std::env::var("APNS_BUNDLE_ID").ok(),
            widget_jwt_secret: std::env::var("WIDGET_JWT_SECRET").ok(),
        }
    }
}
