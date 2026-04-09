use chrono::{DateTime, Utc};
use serde::Serialize;

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct AppConfigResponse {
    pub force_update_version: String,
    pub recommended_version: String,
    #[serde(rename = "appStoreURL")]
    pub app_store_url: String,
    #[serde(rename = "privacyPolicyURL")]
    pub privacy_policy_url: String,
    #[serde(rename = "termsOfServiceURL")]
    pub terms_of_service_url: String,
    pub support_email: String,
    #[serde(rename = "notionFAQDatabaseId")]
    pub notion_faq_database_id: String,
    pub updated_at: DateTime<Utc>,
}

impl AppConfigResponse {
    pub fn default_config() -> Self {
        Self {
            force_update_version: "0.0.0".to_string(),
            recommended_version: "0.0.0".to_string(),
            app_store_url: "https://apps.apple.com/kr/app/id6757733720".to_string(),
            privacy_policy_url: "https://www.notion.so/3029e497067580beb0aaf485a0dd4a02"
                .to_string(),
            terms_of_service_url: "https://www.notion.so/3029e4970675802ab781e282bb92d63b"
                .to_string(),
            support_email: "kswen0203@icloud.com".to_string(),
            notion_faq_database_id: "3029e4970675812ca3d6c852867858a2".to_string(),
            updated_at: Utc::now(),
        }
    }
}
