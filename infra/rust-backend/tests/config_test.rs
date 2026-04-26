use promiso_backend::config::Config;

#[test]
fn production_config_defaults_to_promiso_app_store_apple_id() {
    std::env::set_var("DATABASE_URL", "postgresql://localhost/promiso_test");
    std::env::set_var("FIREBASE_PROJECT_ID", "promiso-prod");
    std::env::set_var("APNS_ENVIRONMENT", "production");
    std::env::remove_var("APP_STORE_APPLE_ID");

    let config = Config::from_env();

    assert_eq!(config.app_store_apple_id, Some(6757733720));
}
