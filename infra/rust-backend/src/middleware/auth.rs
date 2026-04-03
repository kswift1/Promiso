use std::collections::HashMap;
use std::sync::Arc;

use axum::extract::Request;
use axum::http::header::AUTHORIZATION;
use axum::middleware::Next;
use axum::response::Response;
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use tokio::sync::RwLock;

use crate::errors::AppError;

const GOOGLE_CERTS_URL: &str =
    "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

#[derive(Debug, Clone)]
pub struct Claims {
    pub uid: String,
    pub email: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FirebaseClaims {
    sub: String,
    email: Option<String>,
}

#[derive(Clone)]
pub struct FirebaseAuth {
    project_id: String,
    cached_keys: Arc<RwLock<CachedKeys>>,
    http_client: reqwest::Client,
}

struct CachedKeys {
    keys: HashMap<String, DecodingKey>,
    expires_at: std::time::Instant,
}

impl FirebaseAuth {
    pub fn new(project_id: String) -> Self {
        Self {
            project_id,
            cached_keys: Arc::new(RwLock::new(CachedKeys {
                keys: HashMap::new(),
                expires_at: std::time::Instant::now(),
            })),
            http_client: reqwest::Client::new(),
        }
    }

    async fn get_public_keys(&self) -> Result<HashMap<String, DecodingKey>, AppError> {
        // 캐시가 유효하면 그대로 반환
        {
            let cached = self.cached_keys.read().await;
            if cached.expires_at > std::time::Instant::now() && !cached.keys.is_empty() {
                return Ok(cached.keys.clone());
            }
        }

        // 캐시 만료 → Google에서 새로 가져오기
        let response = self
            .http_client
            .get(GOOGLE_CERTS_URL)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("Failed to fetch Firebase keys: {e}")))?;

        // Cache-Control 헤더에서 max-age 파싱
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

        let certs: HashMap<String, String> = response
            .json()
            .await
            .map_err(|e| AppError::Internal(format!("Failed to parse Firebase keys: {e}")))?;

        let mut keys = HashMap::new();
        for (kid, pem) in &certs {
            let key = DecodingKey::from_rsa_pem(pem.as_bytes())
                .map_err(|e| AppError::Internal(format!("Invalid PEM key for kid {kid}: {e}")))?;
            keys.insert(kid.clone(), key);
        }

        // 캐시 갱신
        {
            let mut cached = self.cached_keys.write().await;
            cached.keys = keys.clone();
            cached.expires_at =
                std::time::Instant::now() + std::time::Duration::from_secs(max_age);
        }

        Ok(keys)
    }

    pub async fn verify_token(&self, token: &str) -> Result<Claims, AppError> {
        let header = decode_header(token)
            .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;

        let kid = header
            .kid
            .ok_or_else(|| AppError::Unauthorized("Token missing kid header".to_string()))?;

        let keys = self.get_public_keys().await?;

        let key = keys
            .get(&kid)
            .ok_or_else(|| AppError::Unauthorized("Unknown signing key".to_string()))?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[format!(
            "https://securetoken.google.com/{}",
            self.project_id
        )]);
        validation.set_audience(&[&self.project_id]);

        let token_data = decode::<FirebaseClaims>(token, key, &validation)
            .map_err(|e| AppError::Unauthorized(format!("Token validation failed: {e}")))?;

        if token_data.claims.sub.is_empty() {
            return Err(AppError::Unauthorized("Empty sub claim".to_string()));
        }

        Ok(Claims {
            uid: token_data.claims.sub,
            email: token_data.claims.email,
        })
    }
}

pub async fn require_auth(mut request: Request, next: Next) -> Result<Response, AppError> {
    let firebase_auth = request
        .extensions()
        .get::<FirebaseAuth>()
        .cloned()
        .ok_or_else(|| AppError::Internal("FirebaseAuth not configured".to_string()))?;

    let token = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .ok_or_else(|| {
            AppError::Unauthorized("Missing or invalid Authorization header".to_string())
        })?;

    let claims = firebase_auth.verify_token(token).await?;

    request.extensions_mut().insert(claims);
    Ok(next.run(request).await)
}
