use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::app_config::AppConfigResponse;

pub async fn get_app_config(pool: &PgPool) -> Result<AppConfigResponse, AppError> {
    let config = sqlx::query_as::<_, AppConfigResponse>(
        "SELECT force_update_version, recommended_version, app_store_url, \
                privacy_policy_url, terms_of_service_url, support_email, \
                updated_at \
         FROM app_config \
         WHERE singleton = TRUE",
    )
    .fetch_optional(pool)
    .await?;

    Ok(config.unwrap_or_else(AppConfigResponse::default_config))
}
