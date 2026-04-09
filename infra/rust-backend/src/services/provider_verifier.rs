use std::sync::Arc;

use async_trait::async_trait;
use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::de::DeserializeOwned;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use tokio::sync::RwLock;

use crate::config::Config;
use crate::errors::AppError;
use crate::models::auth::{AppleSignInRequest, GoogleSignInRequest};

const APPLE_JWKS_URL: &str = "https://appleid.apple.com/auth/keys";
const GOOGLE_JWKS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";

#[derive(Debug, Clone)]
pub struct VerifiedProviderProfile {
    pub provider_type: String,
    pub provider_uid: String,
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub profile_image_url: Option<String>,
}

#[async_trait]
pub trait ProviderVerifier: Send + Sync {
    async fn verify_apple_sign_in(
        &self,
        req: &AppleSignInRequest,
    ) -> Result<VerifiedProviderProfile, AppError>;

    async fn verify_google_sign_in(
        &self,
        req: &GoogleSignInRequest,
    ) -> Result<VerifiedProviderProfile, AppError>;
}

pub type SharedProviderVerifier = Arc<dyn ProviderVerifier>;

#[derive(Clone)]
pub struct RealProviderVerifier {
    http_client: reqwest::Client,
    apple_audiences: Vec<String>,
    google_client_ids: Vec<String>,
    apple_jwks: Arc<RwLock<CachedJwks>>,
    google_jwks: Arc<RwLock<CachedJwks>>,
}

struct CachedJwks {
    jwks: Option<JwkSet>,
    expires_at: std::time::Instant,
}

#[derive(Debug, Deserialize)]
struct AppleIdentityClaims {
    sub: String,
    email: Option<String>,
    nonce: Option<String>,
    email_verified: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
struct GoogleIdentityClaims {
    sub: String,
    email: Option<String>,
    email_verified: Option<bool>,
    name: Option<String>,
    picture: Option<String>,
}

impl RealProviderVerifier {
    pub fn new(config: &Config) -> Self {
        Self {
            http_client: reqwest::Client::new(),
            apple_audiences: resolve_list(
                "APPLE_CLIENT_IDS",
                default_apple_audiences(&config.firebase_project_id),
            ),
            google_client_ids: resolve_list(
                "GOOGLE_CLIENT_IDS",
                default_google_client_ids(&config.firebase_project_id),
            ),
            apple_jwks: Arc::new(RwLock::new(CachedJwks {
                jwks: None,
                expires_at: std::time::Instant::now(),
            })),
            google_jwks: Arc::new(RwLock::new(CachedJwks {
                jwks: None,
                expires_at: std::time::Instant::now(),
            })),
        }
    }

    async fn get_jwks(
        &self,
        url: &str,
        cache: &Arc<RwLock<CachedJwks>>,
    ) -> Result<JwkSet, AppError> {
        {
            let cached = cache.read().await;
            if cached.expires_at > std::time::Instant::now() {
                if let Some(jwks) = &cached.jwks {
                    return Ok(jwks.clone());
                }
            }
        }

        let response = self
            .http_client
            .get(url)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("Failed to fetch provider JWKs: {e}")))?;

        let max_age = response
            .headers()
            .get("cache-control")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| {
                v.split(',').find_map(|part| {
                    let part = part.trim();
                    part.strip_prefix("max-age=")
                        .and_then(|age| age.parse::<u64>().ok())
                })
            })
            .unwrap_or(3600);

        let jwks: JwkSet = response
            .json()
            .await
            .map_err(|e| AppError::Internal(format!("Failed to parse provider JWKs: {e}")))?;

        {
            let mut cached = cache.write().await;
            cached.jwks = Some(jwks.clone());
            cached.expires_at = std::time::Instant::now() + std::time::Duration::from_secs(max_age);
        }

        Ok(jwks)
    }

    async fn verify_token<T: DeserializeOwned>(
        &self,
        token: &str,
        jwks_url: &str,
        cache: &Arc<RwLock<CachedJwks>>,
        validation: Validation,
    ) -> Result<T, AppError> {
        let header = decode_header(token)
            .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;
        let kid = header
            .kid
            .ok_or_else(|| AppError::Unauthorized("Token missing kid header".to_string()))?;

        let jwks = self.get_jwks(jwks_url, cache).await?;
        let jwk = jwks
            .find(&kid)
            .ok_or_else(|| AppError::Unauthorized("Unknown signing key".to_string()))?;
        let decoding_key = DecodingKey::from_jwk(jwk)
            .map_err(|e| AppError::Internal(format!("Invalid provider JWK: {e}")))?;

        let token_data = decode::<T>(token, &decoding_key, &validation).map_err(|e| {
            AppError::Unauthorized(format!("Provider token validation failed: {e}"))
        })?;

        Ok(token_data.claims)
    }
}

#[async_trait]
impl ProviderVerifier for RealProviderVerifier {
    async fn verify_apple_sign_in(
        &self,
        req: &AppleSignInRequest,
    ) -> Result<VerifiedProviderProfile, AppError> {
        if req.identity_token.trim().is_empty()
            || req.user_identifier.trim().is_empty()
            || req.raw_nonce.trim().is_empty()
        {
            return Err(AppError::BadRequest(
                "Apple sign-in request is missing required fields".to_string(),
            ));
        }

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&["https://appleid.apple.com"]);
        let audiences: Vec<&str> = self.apple_audiences.iter().map(String::as_str).collect();
        validation.set_audience(&audiences);

        let claims: AppleIdentityClaims = self
            .verify_token(&req.identity_token, APPLE_JWKS_URL, &self.apple_jwks, validation)
            .await?;

        if claims.sub != req.user_identifier {
            return Err(AppError::Unauthorized(
                "Apple token subject mismatch".to_string(),
            ));
        }

        let expected_nonce = hex::encode(Sha256::digest(req.raw_nonce.as_bytes()));
        if claims.nonce.as_deref() != Some(expected_nonce.as_str()) {
            return Err(AppError::Unauthorized(
                "Apple token nonce mismatch".to_string(),
            ));
        }

        if claims.email.is_some() && !is_verified_claim(claims.email_verified.as_ref()) {
            return Err(AppError::Unauthorized(
                "Apple email is not verified".to_string(),
            ));
        }

        Ok(VerifiedProviderProfile {
            provider_type: "apple".to_string(),
            provider_uid: claims.sub,
            email: claims.email.or_else(|| req.email.clone()),
            display_name: req.full_name.clone().filter(|value| !value.trim().is_empty()),
            profile_image_url: None,
        })
    }

    async fn verify_google_sign_in(
        &self,
        req: &GoogleSignInRequest,
    ) -> Result<VerifiedProviderProfile, AppError> {
        if req.id_token.trim().is_empty() || req.user_identifier.trim().is_empty() {
            return Err(AppError::BadRequest(
                "Google sign-in request is missing required fields".to_string(),
            ));
        }

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&["accounts.google.com", "https://accounts.google.com"]);
        let audiences: Vec<&str> = self.google_client_ids.iter().map(String::as_str).collect();
        validation.set_audience(&audiences);

        let claims: GoogleIdentityClaims = self
            .verify_token(&req.id_token, GOOGLE_JWKS_URL, &self.google_jwks, validation)
            .await?;

        if claims.sub != req.user_identifier {
            return Err(AppError::Unauthorized(
                "Google token subject mismatch".to_string(),
            ));
        }

        if claims.email.is_some() && claims.email_verified == Some(false) {
            return Err(AppError::Unauthorized(
                "Google email is not verified".to_string(),
            ));
        }

        Ok(VerifiedProviderProfile {
            provider_type: "google".to_string(),
            provider_uid: claims.sub,
            email: claims.email.or_else(|| req.email.clone()),
            display_name: claims
                .name
                .or_else(|| req.full_name.clone())
                .filter(|value| !value.trim().is_empty()),
            profile_image_url: claims
                .picture
                .or_else(|| req.profile_image_url.clone())
                .filter(|value| !value.trim().is_empty()),
        })
    }
}

fn resolve_list(var_name: &str, defaults: Vec<String>) -> Vec<String> {
    std::env::var(var_name)
        .ok()
        .map(|value| {
            value
                .split(',')
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned)
                .collect::<Vec<_>>()
        })
        .filter(|values| !values.is_empty())
        .unwrap_or(defaults)
}

fn default_google_client_ids(firebase_project_id: &str) -> Vec<String> {
    let client_id = if firebase_project_id.contains("-dev") {
        "809932911903-ugv4efpvkv09e3fq4hs4ccnv33mtj936.apps.googleusercontent.com"
    } else if firebase_project_id.contains("-stage") {
        "511041416523-bek4g2m6qojqcoecd17mvft1kvn7vogt.apps.googleusercontent.com"
    } else {
        "367716701610-efrvms6v48eldljh34falbhclkvsrqvt.apps.googleusercontent.com"
    };

    vec![client_id.to_string()]
}

fn default_apple_audiences(firebase_project_id: &str) -> Vec<String> {
    let audience = if firebase_project_id.contains("-dev") {
        "com.promiso.dev"
    } else if firebase_project_id.contains("-stage") {
        "com.promiso.stage"
    } else {
        "com.promiso"
    };

    vec![audience.to_string()]
}

fn is_verified_claim(value: Option<&serde_json::Value>) -> bool {
    match value {
        Some(serde_json::Value::Bool(bool_value)) => *bool_value,
        Some(serde_json::Value::String(string_value)) => string_value == "true",
        None => true,
        _ => false,
    }
}
