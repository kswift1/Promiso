use std::sync::Mutex;

use chrono::Utc;
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use reqwest::Client;
use tracing;

use crate::errors::AppError;
use crate::models::live_activity::*;

const APNS_HOST_PRODUCTION: &str = "https://api.push.apple.com";
const APNS_HOST_DEVELOPMENT: &str = "https://api.sandbox.push.apple.com";

pub struct RealApnsSender {
    client: Client,
    key_id: String,
    team_id: String,
    auth_key: String,
    bundle_id: String,
    push_host: String,
    channel_host: String,
    jwt_cache: Mutex<Option<(String, i64)>>,
}

impl RealApnsSender {
    pub fn new(config: &crate::config::Config) -> Self {
        let push_host = if config.apns_environment == "production" {
            APNS_HOST_PRODUCTION.to_string()
        } else {
            APNS_HOST_DEVELOPMENT.to_string()
        };

        let client = Client::builder()
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            key_id: config.apns_key_id.clone(),
            team_id: config.apns_team_id.clone(),
            auth_key: config.apns_auth_key.clone(),
            bundle_id: config.apns_bundle_id.clone(),
            channel_host: push_host.clone(),
            push_host,
            jwt_cache: Mutex::new(None),
        }
    }

    pub fn is_configured(&self) -> bool {
        !self.key_id.is_empty() && !self.team_id.is_empty() && !self.auth_key.is_empty()
    }

    fn generate_jwt(&self) -> Result<String, AppError> {
        // Check cache: valid if more than 5 minutes until expiry
        {
            let cache = self
                .jwt_cache
                .lock()
                .map_err(|e| AppError::Internal(format!("JWT cache lock error: {}", e)))?;
            if let Some((ref token, expires_at)) = *cache {
                if Utc::now().timestamp() < expires_at - 300 {
                    return Ok(token.clone());
                }
            }
        }

        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.key_id.clone());

        let now = Utc::now().timestamp();
        let claims = serde_json::json!({
            "iss": self.team_id,
            "iat": now,
        });

        let key = EncodingKey::from_ec_pem(self.auth_key.as_bytes())
            .map_err(|e| AppError::Internal(format!("APNs key error: {}", e)))?;

        let token = encode(&header, &claims, &key)
            .map_err(|e| AppError::Internal(format!("APNs JWT error: {}", e)))?;

        // Cache the token (1 hour expiry)
        {
            let mut cache = self
                .jwt_cache
                .lock()
                .map_err(|e| AppError::Internal(format!("JWT cache lock error: {}", e)))?;
            *cache = Some((token.clone(), now + 3600));
        }

        Ok(token)
    }
}

#[async_trait::async_trait]
impl ApnsSender for RealApnsSender {
    async fn send_push_to_start(
        &self,
        tokens: &[String],
        payload: &ApnsPayload,
    ) -> ApnsResult {
        if !self.is_configured() {
            tracing::warn!("APNs not configured, skipping push_to_start");
            return ApnsResult {
                success_count: 0,
                failure_count: tokens.len() as i32,
            };
        }

        let jwt = match self.generate_jwt() {
            Ok(t) => t,
            Err(e) => {
                tracing::error!("APNs JWT generation failed: {}", e);
                return ApnsResult {
                    success_count: 0,
                    failure_count: tokens.len() as i32,
                };
            }
        };

        let topic = format!("{}.push-type.liveactivity", self.bundle_id);
        let body = serde_json::to_string(payload).unwrap_or_default();

        let mut success = 0i32;
        let mut failure = 0i32;

        for token in tokens {
            let url = format!("{}/3/device/{}", self.push_host, token);
            let result = self
                .client
                .post(&url)
                .header("authorization", format!("bearer {}", jwt))
                .header("apns-push-type", "liveactivity")
                .header("apns-topic", &topic)
                .header("apns-priority", "10")
                .header("content-type", "application/json")
                .body(body.clone())
                .send()
                .await;

            match result {
                Ok(resp) if resp.status().is_success() => success += 1,
                Ok(resp) => {
                    let status = resp.status();
                    let body_text = resp.text().await.unwrap_or_default();
                    tracing::warn!(
                        "APNs push_to_start failed for token {}: {} {}",
                        token,
                        status,
                        body_text
                    );
                    failure += 1;
                }
                Err(e) => {
                    tracing::warn!("APNs push_to_start error for token {}: {}", token, e);
                    failure += 1;
                }
            }
        }

        ApnsResult {
            success_count: success,
            failure_count: failure,
        }
    }

    async fn create_channel(&self) -> Result<String, AppError> {
        if !self.is_configured() {
            return Err(AppError::Internal("APNs not configured".to_string()));
        }

        let jwt = self.generate_jwt()?;
        let url = format!("{}/1/apps/{}/channels", self.channel_host, self.bundle_id);

        let body = serde_json::json!({
            "push-type": "LiveActivity",
            "message-storage-policy": 1
        });

        let resp = self
            .client
            .post(&url)
            .header("authorization", format!("bearer {}", jwt))
            .header("content-type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("APNs channel error: {}", e)))?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body_text = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "APNs channel failed: {} {}",
                status, body_text
            )));
        }

        let channel_id = resp
            .headers()
            .get("apns-channel-id")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string())
            .ok_or_else(|| {
                AppError::Internal("APNs channel-id header missing".to_string())
            })?;

        Ok(channel_id)
    }

    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &ApnsPayload,
    ) -> ApnsResult {
        if !self.is_configured() {
            tracing::warn!("APNs not configured, skipping broadcast");
            return ApnsResult {
                success_count: 0,
                failure_count: 1,
            };
        }

        let jwt = match self.generate_jwt() {
            Ok(t) => t,
            Err(e) => {
                tracing::error!("APNs JWT generation failed: {}", e);
                return ApnsResult {
                    success_count: 0,
                    failure_count: 1,
                };
            }
        };

        let url = format!("{}/4/broadcasts/apps/{}", self.push_host, self.bundle_id);
        let topic = format!("{}.push-type.liveactivity", self.bundle_id);

        let result = self
            .client
            .post(&url)
            .header("authorization", format!("bearer {}", jwt))
            .header("content-type", "application/json")
            .header("apns-push-type", "liveactivity")
            .header("apns-topic", &topic)
            .header("apns-channel-id", channel_id)
            .header("apns-priority", "10")
            .header("apns-expiration", "0")
            .body(serde_json::to_string(payload).unwrap_or_default())
            .send()
            .await;

        match result {
            Ok(resp) if resp.status().is_success() => ApnsResult {
                success_count: 1,
                failure_count: 0,
            },
            Ok(resp) => {
                let status = resp.status();
                let body_text = resp.text().await.unwrap_or_default();
                tracing::warn!(
                    "APNs broadcast failed for channel {}: {} {}",
                    channel_id,
                    status,
                    body_text
                );
                ApnsResult {
                    success_count: 0,
                    failure_count: 1,
                }
            }
            Err(e) => {
                tracing::warn!("APNs broadcast error for channel {}: {}", channel_id, e);
                ApnsResult {
                    success_count: 0,
                    failure_count: 1,
                }
            }
        }
    }
}
