use std::collections::HashMap;
use std::fs;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use jsonwebtoken::{Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::config::Config;
use crate::errors::AppError;
use crate::models::live_activity::LiveActivitySender;
use crate::models::notification::{FcmMessage, NotificationType, PushResult, PushSender};

const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI: &str = "https://oauth2.googleapis.com/token";
const APNS_HOST_PRODUCTION: &str = "https://api.push.apple.com";
const APNS_HOST_DEVELOPMENT: &str = "https://api.sandbox.push.apple.com";
const APNS_CHANNEL_HOST_PRODUCTION: &str = "https://api-manage-broadcast.push.apple.com:2196";
const APNS_CHANNEL_HOST_DEVELOPMENT: &str =
    "https://api-manage-broadcast.sandbox.push.apple.com:2195";

#[derive(Default)]
pub struct NoopPushSender;

pub struct DisabledLiveActivitySender {
    reason: String,
}

#[derive(Clone)]
pub struct ApnsLiveActivitySender {
    key_id: String,
    team_id: String,
    auth_key: String,
    bundle_id: String,
    is_production: bool,
    http_client: reqwest::Client,
}

#[async_trait::async_trait]
impl PushSender for NoopPushSender {
    async fn send_multicast(&self, _tokens: &[String], _message: &FcmMessage) -> PushResult {
        PushResult {
            success: true,
            success_count: 0,
            failure_count: 0,
        }
    }
}

impl DisabledLiveActivitySender {
    pub fn new(reason: impl Into<String>) -> Self {
        Self {
            reason: reason.into(),
        }
    }
}

#[async_trait::async_trait]
impl LiveActivitySender for DisabledLiveActivitySender {
    async fn create_channel(&self) -> Result<String, AppError> {
        Err(AppError::PreconditionFailed(self.reason.clone()))
    }

    async fn send_push_to_start(
        &self,
        _push_to_start_token: &str,
        _payload: &serde_json::Value,
    ) -> Result<(), AppError> {
        Err(AppError::PreconditionFailed(self.reason.clone()))
    }

    async fn send_broadcast(
        &self,
        _channel_id: &str,
        _payload: &serde_json::Value,
    ) -> Result<(), AppError> {
        Err(AppError::PreconditionFailed(self.reason.clone()))
    }
}

#[derive(Clone)]
pub struct FcmPushSender {
    project_id: String,
    credentials: ServiceAccountCredentials,
    http_client: reqwest::Client,
    token_cache: std::sync::Arc<RwLock<Option<CachedAccessToken>>>,
}

#[derive(Clone, Deserialize)]
struct ServiceAccountCredentials {
    client_email: String,
    private_key: String,
    token_uri: Option<String>,
}

struct CachedAccessToken {
    token: String,
    expires_at: Instant,
}

#[derive(Serialize)]
struct ServiceAccountJwtClaims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    exp: usize,
    iat: usize,
}

#[derive(Serialize)]
struct TokenRequestForm<'a> {
    grant_type: &'a str,
    assertion: &'a str,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
}

impl FcmPushSender {
    pub fn from_service_account_file(project_id: String, path: &str) -> Result<Self, AppError> {
        let service_account_json = fs::read_to_string(path).map_err(|error| {
            AppError::Internal(format!(
                "Failed to read Google service account file {path}: {error}"
            ))
        })?;
        Self::from_service_account_json(project_id, &service_account_json)
    }

    pub fn from_service_account_json(
        project_id: String,
        service_account_json: &str,
    ) -> Result<Self, AppError> {
        let credentials: ServiceAccountCredentials = serde_json::from_str(service_account_json)
            .map_err(|error| {
                AppError::Internal(format!(
                    "Failed to parse Google service account JSON: {error}"
                ))
            })?;

        Ok(Self {
            project_id,
            credentials,
            http_client: reqwest::Client::new(),
            token_cache: std::sync::Arc::new(RwLock::new(None)),
        })
    }

    async fn access_token(&self) -> Result<String, AppError> {
        {
            let cached = self.token_cache.read().await;
            if let Some(token) = cached.as_ref() {
                if token.expires_at > Instant::now() + Duration::from_secs(60) {
                    return Ok(token.token.clone());
                }
            }
        }

        let token = self.fetch_access_token().await?;

        {
            let mut cached = self.token_cache.write().await;
            *cached = Some(CachedAccessToken {
                expires_at: Instant::now()
                    + Duration::from_secs(token.expires_in.saturating_sub(60)),
                token: token.access_token.clone(),
            });
        }

        Ok(token.access_token)
    }

    async fn fetch_access_token(&self) -> Result<TokenResponse, AppError> {
        let token_uri = self
            .credentials
            .token_uri
            .as_deref()
            .unwrap_or(DEFAULT_TOKEN_URI);

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|error| AppError::Internal(format!("Invalid system clock: {error}")))?
            .as_secs() as usize;

        let claims = ServiceAccountJwtClaims {
            iss: &self.credentials.client_email,
            scope: FCM_SCOPE,
            aud: token_uri,
            exp: now + 3600,
            iat: now,
        };

        let assertion = jsonwebtoken::encode(
            &Header::new(Algorithm::RS256),
            &claims,
            &EncodingKey::from_rsa_pem(self.credentials.private_key.as_bytes()).map_err(
                |error| AppError::Internal(format!("Invalid service account private key: {error}")),
            )?,
        )
        .map_err(|error| AppError::Internal(format!("Failed to sign OAuth JWT: {error}")))?;

        self.http_client
            .post(token_uri)
            .form(&TokenRequestForm {
                grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
                assertion: &assertion,
            })
            .send()
            .await
            .map_err(|error| AppError::Internal(format!("Failed to request OAuth token: {error}")))?
            .error_for_status()
            .map_err(|error| AppError::Internal(format!("OAuth token request failed: {error}")))?
            .json::<TokenResponse>()
            .await
            .map_err(|error| AppError::Internal(format!("Failed to decode OAuth token: {error}")))
    }

    fn build_message_payload(&self, token: &str, message: &FcmMessage) -> serde_json::Value {
        let mut data = HashMap::new();
        data.insert(
            "type".to_string(),
            notification_type_wire_value(&message.notification_type),
        );

        if let Some(schedule_id) = message.schedule_id {
            let schedule_id = schedule_id.to_string();
            data.insert("scheduleId".to_string(), schedule_id.clone());
            data.insert("promiseId".to_string(), schedule_id);
        }

        if let Some(group_id) = message.group_id {
            data.insert("groupId".to_string(), group_id.to_string());
        }

        if let Some(related_user_id) = &message.related_user_id {
            data.insert("relatedUserId".to_string(), related_user_id.clone());
        }

        if let Some(extra_data) = &message.data {
            data.extend(extra_data.clone());
        }

        serde_json::json!({
            "message": {
                "token": token,
                "notification": {
                    "title": message.title,
                    "body": message.body,
                },
                "data": data,
                "apns": {
                    "payload": {
                        "aps": {
                            "sound": "default",
                            "mutable-content": 1,
                        }
                    }
                }
            }
        })
    }

    async fn send_message(
        &self,
        token: &str,
        message: &FcmMessage,
        access_token: &str,
    ) -> Result<(), AppError> {
        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.project_id
        );

        let response = self
            .http_client
            .post(&url)
            .bearer_auth(access_token)
            .json(&self.build_message_payload(token, message))
            .send()
            .await
            .map_err(|error| AppError::Internal(format!("Failed to call FCM API: {error}")))?;

        if response.status().is_success() {
            return Ok(());
        }

        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        Err(AppError::Internal(format!(
            "FCM API returned {status}: {body}"
        )))
    }
}

#[async_trait::async_trait]
impl PushSender for FcmPushSender {
    async fn send_multicast(&self, tokens: &[String], message: &FcmMessage) -> PushResult {
        if tokens.is_empty() {
            return PushResult {
                success: true,
                success_count: 0,
                failure_count: 0,
            };
        }

        let access_token = match self.access_token().await {
            Ok(token) => token,
            Err(error) => {
                tracing::error!("Failed to obtain FCM access token: {error}");
                return PushResult {
                    success: false,
                    success_count: 0,
                    failure_count: tokens.len() as i32,
                };
            }
        };

        let mut success_count = 0;
        let mut failure_count = 0;

        for token in tokens {
            match self.send_message(token, message, &access_token).await {
                Ok(()) => success_count += 1,
                Err(error) => {
                    failure_count += 1;
                    tracing::error!("FCM send failed for token {}: {}", token, error);
                }
            }
        }

        PushResult {
            success: failure_count == 0,
            success_count,
            failure_count,
        }
    }
}

impl ApnsLiveActivitySender {
    pub fn from_config(config: &Config) -> Result<Self, AppError> {
        let key_id = config
            .apns_key_id
            .clone()
            .ok_or_else(|| AppError::PreconditionFailed("APNS_KEY_ID must be set".to_string()))?;
        let team_id = config
            .apns_team_id
            .clone()
            .ok_or_else(|| AppError::PreconditionFailed("APNS_TEAM_ID must be set".to_string()))?;
        let auth_key = load_apns_auth_key(config)?;
        let bundle_id = config
            .apns_bundle_id
            .clone()
            .unwrap_or_else(|| derive_apns_bundle_id(&config.firebase_project_id));

        Ok(Self {
            key_id,
            team_id,
            auth_key,
            bundle_id,
            is_production: !config.firebase_project_id.contains("-dev"),
            http_client: reqwest::Client::builder().build().map_err(|error| {
                AppError::Internal(format!("Failed to build APNs client: {error}"))
            })?,
        })
    }

    fn authorization_token(&self) -> Result<String, AppError> {
        #[derive(Serialize)]
        struct Claims<'a> {
            iss: &'a str,
            iat: usize,
        }

        let issued_at = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|error| AppError::Internal(format!("Invalid system clock: {error}")))?
            .as_secs() as usize;

        let header = Header {
            alg: Algorithm::ES256,
            kid: Some(self.key_id.clone()),
            ..Header::default()
        };

        jsonwebtoken::encode(
            &header,
            &Claims {
                iss: &self.team_id,
                iat: issued_at,
            },
            &EncodingKey::from_ec_pem(self.auth_key.as_bytes())
                .map_err(|error| AppError::Internal(format!("Invalid APNs auth key: {error}")))?,
        )
        .map_err(|error| AppError::Internal(format!("Failed to sign APNs JWT: {error}")))
    }

    fn push_host(&self) -> &'static str {
        if self.is_production {
            APNS_HOST_PRODUCTION
        } else {
            APNS_HOST_DEVELOPMENT
        }
    }

    fn channel_host(&self) -> &'static str {
        if self.is_production {
            APNS_CHANNEL_HOST_PRODUCTION
        } else {
            APNS_CHANNEL_HOST_DEVELOPMENT
        }
    }

    fn topic(&self) -> String {
        format!("{}.push-type.liveactivity", self.bundle_id)
    }

    async fn execute_request(
        &self,
        request: reqwest::RequestBuilder,
        success_statuses: &[reqwest::StatusCode],
    ) -> Result<reqwest::Response, AppError> {
        let response = request
            .send()
            .await
            .map_err(|error| AppError::Internal(format!("Failed to call APNs: {error}")))?;

        if success_statuses.contains(&response.status()) {
            return Ok(response);
        }

        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        Err(AppError::Internal(format!(
            "APNs returned {status}: {body}"
        )))
    }
}

#[async_trait::async_trait]
impl LiveActivitySender for ApnsLiveActivitySender {
    async fn create_channel(&self) -> Result<String, AppError> {
        let token = self.authorization_token()?;
        let url = format!("{}/1/apps/{}/channels", self.channel_host(), self.bundle_id);
        let response = self
            .execute_request(
                self.http_client
                    .post(url)
                    .bearer_auth(token)
                    .header("content-type", "application/json")
                    .json(&serde_json::json!({
                        "push-type": "LiveActivity",
                        "message-storage-policy": 1
                    })),
                &[reqwest::StatusCode::OK, reqwest::StatusCode::CREATED],
            )
            .await?;

        response
            .headers()
            .get("apns-channel-id")
            .and_then(|value| value.to_str().ok())
            .map(|value| value.to_string())
            .ok_or_else(|| {
                AppError::Internal("APNs channel response missing apns-channel-id".to_string())
            })
    }

    async fn send_push_to_start(
        &self,
        push_to_start_token: &str,
        payload: &serde_json::Value,
    ) -> Result<(), AppError> {
        let token = self.authorization_token()?;
        let url = format!("{}/3/device/{}", self.push_host(), push_to_start_token);
        self.execute_request(
            self.http_client
                .post(url)
                .bearer_auth(token)
                .header("content-type", "application/json")
                .header("apns-push-type", "liveactivity")
                .header("apns-topic", self.topic())
                .header("apns-priority", "10")
                .json(payload),
            &[reqwest::StatusCode::OK],
        )
        .await
        .map(|_| ())
    }

    async fn send_broadcast(
        &self,
        channel_id: &str,
        payload: &serde_json::Value,
    ) -> Result<(), AppError> {
        let token = self.authorization_token()?;
        let url = format!("{}/4/broadcasts/apps/{}", self.push_host(), self.bundle_id);
        self.execute_request(
            self.http_client
                .post(url)
                .bearer_auth(token)
                .header("content-type", "application/json")
                .header("apns-push-type", "liveactivity")
                .header("apns-topic", self.topic())
                .header("apns-channel-id", channel_id)
                .header("apns-priority", "10")
                .header("apns-expiration", "0")
                .json(payload),
            &[reqwest::StatusCode::OK],
        )
        .await
        .map(|_| ())
    }
}

pub fn build_push_sender(config: &Config) -> Arc<dyn PushSender> {
    if let Some(service_account_json) = config.firebase_service_account_json.as_deref() {
        return match FcmPushSender::from_service_account_json(
            config.firebase_project_id.clone(),
            service_account_json,
        ) {
            Ok(sender) => Arc::new(sender),
            Err(error) => {
                tracing::error!("Failed to initialize FCM sender from env JSON: {error}");
                Arc::new(NoopPushSender)
            }
        };
    }

    if let Some(credentials_path) = config.google_application_credentials.as_deref() {
        return match FcmPushSender::from_service_account_file(
            config.firebase_project_id.clone(),
            credentials_path,
        ) {
            Ok(sender) => Arc::new(sender),
            Err(error) => {
                tracing::error!("Failed to initialize FCM sender from file: {error}");
                Arc::new(NoopPushSender)
            }
        };
    }

    tracing::warn!(
        "FCM sender disabled: set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON"
    );
    Arc::new(NoopPushSender)
}

pub fn build_live_activity_sender(config: &Config) -> Arc<dyn LiveActivitySender> {
    match ApnsLiveActivitySender::from_config(config) {
        Ok(sender) => Arc::new(sender),
        Err(error) => {
            tracing::warn!("Live Activity sender disabled: {error}");
            Arc::new(DisabledLiveActivitySender::new(
                "APNs Live Activity sender is not configured",
            ))
        }
    }
}

fn notification_type_wire_value(notification_type: &NotificationType) -> String {
    match notification_type {
        NotificationType::ScheduleInvitation => "promise_invitation".to_string(),
        NotificationType::ScheduleReminder => "promise_reminder".to_string(),
        NotificationType::ScheduleConfirmed => "promise_confirmed".to_string(),
        NotificationType::ScheduleCancelled => "promise_cancelled".to_string(),
        NotificationType::ScheduleUpdated => "promise_updated".to_string(),
        NotificationType::LocationSharingReminder => "location_sharing_reminder".to_string(),
        NotificationType::GroupInvitation => "group_invitation".to_string(),
        NotificationType::GroupUpdate => "group_update".to_string(),
        NotificationType::AttendanceResponse => "attendance_response".to_string(),
        NotificationType::System => "system".to_string(),
    }
}

fn load_apns_auth_key(config: &Config) -> Result<String, AppError> {
    if let Some(raw_key) = config.apns_auth_key.as_deref() {
        return Ok(raw_key.trim().replace("\\n", "\n"));
    }

    if let Some(path) = config.apns_auth_key_path.as_deref() {
        return fs::read_to_string(path).map_err(|error| {
            AppError::Internal(format!("Failed to read APNs auth key file {path}: {error}"))
        });
    }

    Err(AppError::PreconditionFailed(
        "APNS_AUTH_KEY or APNS_AUTH_KEY_PATH must be set".to_string(),
    ))
}

fn derive_apns_bundle_id(firebase_project_id: &str) -> String {
    if firebase_project_id.contains("-dev") {
        "com.promiso.dev".to_string()
    } else if firebase_project_id.contains("-stage") {
        "com.promiso.stage".to_string()
    } else {
        "com.promiso".to_string()
    }
}
