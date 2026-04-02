pub struct Config {
    pub database_url: String,
    pub port: u16,
    pub firebase_project_id: String,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();

        Self {
            database_url: std::env::var("DATABASE_URL")
                .expect("DATABASE_URL must be set"),
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .expect("PORT must be a valid number"),
            firebase_project_id: std::env::var("FIREBASE_PROJECT_ID")
                .expect("FIREBASE_PROJECT_ID must be set"),
        }
    }
}
