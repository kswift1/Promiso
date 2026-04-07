pub struct Config {
    pub database_url: String,
    pub database_pool_url: String,
    pub port: u16,
    pub firebase_project_id: String,

    // APNs
    pub apns_key_id: String,
    pub apns_team_id: String,
    pub apns_auth_key: String,
    pub apns_bundle_id: String,
    pub apns_environment: String,
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
            apns_key_id: std::env::var("APNS_KEY_ID").unwrap_or_default(),
            apns_team_id: std::env::var("APNS_TEAM_ID").unwrap_or_default(),
            apns_auth_key: std::env::var("APNS_AUTH_KEY")
                .unwrap_or_default()
                .replace("\\n", "\n"),
            apns_bundle_id: std::env::var("APNS_BUNDLE_ID").unwrap_or_default(),
            apns_environment: std::env::var("APNS_ENVIRONMENT")
                .unwrap_or_else(|_| "development".to_string()),
        }
    }
}
