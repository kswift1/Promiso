use std::collections::HashMap;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use axum::extract::Request;
use axum::http::header::AUTHORIZATION;
use axum::middleware::Next;
use axum::response::Response;
use chrono::{DateTime, Duration, Utc};
use jsonwebtoken::{
    decode, decode_header, encode, Algorithm, DecodingKey, EncodingKey, Header, Validation,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::errors::AppError;

const GOOGLE_CERTS_URL: &str =
    "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

#[derive(Debug, Clone)]
pub struct Claims {
    pub uid: String,
    pub email: Option<String>,
    pub session_id: Option<Uuid>,
}

#[derive(Debug, Deserialize)]
struct FirebaseClaims {
    sub: String,
    email: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct WidgetClaims {
    pub sub: String,
    pub scope: String,
    pub exp: usize,
    pub iat: Option<usize>,
    /// 발급 당시 widget_token_version (무효화 판단용)
    pub version: Option<i32>,
    /// 발급 요청 deviceId (WT-2)
    pub device_id: Option<String>,
}

#[derive(Clone)]
pub struct FirebaseAuth {
    project_id: String,
    cached_keys: Arc<RwLock<CachedKeys>>,
    http_client: reqwest::Client,
}

#[derive(Clone)]
pub struct WidgetAuth {
    secret: Option<String>,
}

#[derive(Clone)]
pub struct ServerAuth {
    secret: Option<String>,
    issuer: String,
    access_token_ttl_seconds: i64,
}

struct CachedKeys {
    keys: HashMap<String, DecodingKey>,
    expires_at: std::time::Instant,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct ServerAccessClaims {
    sub: String,
    email: Option<String>,
    token_type: String,
    sid: Option<Uuid>,
    iss: String,
    exp: usize,
    iat: usize,
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
            cached.expires_at = std::time::Instant::now() + std::time::Duration::from_secs(max_age);
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
            session_id: None,
        })
    }
}

impl WidgetAuth {
    pub fn new(secret: Option<String>) -> Self {
        Self { secret }
    }

    pub fn secret(&self) -> Option<&str> {
        self.secret.as_deref()
    }

    fn decode_claims(&self, token: &str) -> Result<WidgetClaims, AppError> {
        let secret = self.secret.as_ref().ok_or_else(|| {
            AppError::Unauthorized("Widget token verification is not configured".to_string())
        })?;

        let token_data = decode::<WidgetClaims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::new(Algorithm::HS256),
        )
        .map_err(|e| AppError::Unauthorized(format!("Widget token validation failed: {e}")))?;

        if token_data.claims.sub.is_empty() {
            return Err(AppError::Unauthorized("Empty sub claim".to_string()));
        }

        if token_data.claims.scope != "widget:read" {
            return Err(AppError::Forbidden(
                "Invalid widget token scope".to_string(),
            ));
        }

        Ok(token_data.claims)
    }

    pub fn verify_token(&self, token: &str) -> Result<Claims, AppError> {
        let claims = self.decode_claims(token)?;

        Ok(Claims {
            uid: claims.sub,
            email: None,
            session_id: None,
        })
    }
}

impl ServerAuth {
    pub fn new(secret: Option<String>, issuer: String, access_token_ttl_seconds: i64) -> Self {
        Self {
            secret,
            issuer,
            access_token_ttl_seconds,
        }
    }

    pub fn issue_access_token(
        &self,
        uid: &str,
        email: Option<&str>,
        session_id: Option<Uuid>,
    ) -> Result<String, AppError> {
        let secret = self
            .secret
            .as_ref()
            .ok_or_else(|| AppError::Internal("AUTH_JWT_SECRET is not configured".to_string()))?;

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| AppError::Internal(format!("Failed to get current time: {e}")))?
            .as_secs() as usize;

        let exp = now.saturating_add(self.access_token_ttl_seconds.max(0) as usize);
        let claims = ServerAccessClaims {
            sub: uid.to_string(),
            email: email.map(ToOwned::to_owned),
            token_type: "access".to_string(),
            sid: session_id,
            iss: self.issuer.clone(),
            exp,
            iat: now,
        };

        encode(
            &Header::new(Algorithm::HS256),
            &claims,
            &EncodingKey::from_secret(secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(format!("Failed to encode access JWT: {e}")))
    }

    pub fn access_token_expires_at(&self) -> DateTime<Utc> {
        Utc::now() + Duration::seconds(self.access_token_ttl_seconds.max(0))
    }

    pub fn verify_access_token(&self, token: &str) -> Result<Claims, AppError> {
        let secret = self.secret.as_ref().ok_or_else(|| {
            AppError::Unauthorized("Server token verification is not configured".to_string())
        })?;

        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&[self.issuer.as_str()]);

        let token_data = decode::<ServerAccessClaims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &validation,
        )
        .map_err(|e| AppError::Unauthorized(format!("Server token validation failed: {e}")))?;

        if token_data.claims.sub.is_empty() {
            return Err(AppError::Unauthorized("Empty sub claim".to_string()));
        }

        if token_data.claims.token_type != "access" {
            return Err(AppError::Forbidden("Invalid server token type".to_string()));
        }

        Ok(Claims {
            uid: token_data.claims.sub,
            email: token_data.claims.email,
            session_id: token_data.claims.sid,
        })
    }
}

pub async fn verify_widget_or_firebase_token(
    firebase_auth: &FirebaseAuth,
    server_auth: &ServerAuth,
    widget_auth: &WidgetAuth,
    pool: &PgPool,
    token: &str,
    provided_device_id: Option<&str>,
) -> Result<Claims, AppError> {
    let header = decode_header(token)
        .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;

    if header.alg == Algorithm::HS256 {
        if let Ok(claims) = server_auth.verify_access_token(token) {
            return Ok(claims);
        }

        let claims = widget_auth.decode_claims(token)?;
        let token_version = claims
            .version
            .ok_or_else(|| AppError::Unauthorized("Widget token version is missing".to_string()))?;
        let token_device_id = claims
            .device_id
            .as_deref()
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                AppError::Unauthorized("Widget token device_id is missing".to_string())
            })?;
        let request_device_id = provided_device_id
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| AppError::Unauthorized("X-Device-Id header is required".to_string()))?;

        if request_device_id != token_device_id {
            return Err(AppError::Unauthorized(
                "Widget token device mismatch".to_string(),
            ));
        }

        let current_version: Option<(i32,)> =
            sqlx::query_as("SELECT widget_token_version FROM users WHERE id = $1")
                .bind(&claims.sub)
                .fetch_optional(pool)
                .await?;

        let current_version = current_version.ok_or_else(|| {
            AppError::Unauthorized("Widget token user does not exist".to_string())
        })?;

        if current_version.0 != token_version {
            return Err(AppError::Unauthorized(
                "Widget token has been revoked".to_string(),
            ));
        }

        return Ok(Claims {
            uid: claims.sub,
            email: None,
            session_id: None,
        });
    }

    firebase_auth.verify_token(token).await
}

pub async fn require_auth(mut request: Request, next: Next) -> Result<Response, AppError> {
    let token = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .ok_or_else(|| {
            AppError::Unauthorized("Missing or invalid Authorization header".to_string())
        })?;

    let header = decode_header(token)
        .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;

    let claims = if header.alg == Algorithm::HS256 {
        let server_auth = request
            .extensions()
            .get::<ServerAuth>()
            .cloned()
            .ok_or_else(|| AppError::Internal("ServerAuth not configured".to_string()))?;
        server_auth.verify_access_token(token)?
    } else {
        let firebase_auth = request
            .extensions()
            .get::<FirebaseAuth>()
            .cloned()
            .ok_or_else(|| AppError::Internal("FirebaseAuth not configured".to_string()))?;
        firebase_auth.verify_token(token).await?
    };

    request.extensions_mut().insert(claims);
    Ok(next.run(request).await)
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use axum::body::Body;
    use axum::extract::Extension;
    use axum::http::header::AUTHORIZATION;
    use axum::http::{Request, StatusCode};
    use axum::middleware;
    use axum::routing::get;
    use axum::Router;
    use http_body_util::BodyExt;
    use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::{require_auth, AppError, ServerAccessClaims, ServerAuth, WidgetAuth, WidgetClaims};

    async fn protected(Extension(claims): Extension<super::Claims>) -> String {
        claims.uid
    }

    #[test]
    fn widget_auth_verifies_valid_token() {
        let widget_auth = WidgetAuth::new(Some("test-secret".to_string()));
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time should work")
            .as_secs() as usize;
        let token = encode(
            &Header::new(Algorithm::HS256),
            &WidgetClaims {
                sub: "user_123".to_string(),
                scope: "widget:read".to_string(),
                exp: now + 3600,
                iat: Some(now),
                version: None,
                device_id: None,
            },
            &EncodingKey::from_secret("test-secret".as_bytes()),
        )
        .expect("token should encode");

        let claims = widget_auth
            .verify_token(&token)
            .expect("token should verify");

        assert_eq!(claims.uid, "user_123");
    }

    #[test]
    fn widget_auth_rejects_invalid_scope() {
        let widget_auth = WidgetAuth::new(Some("test-secret".to_string()));
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time should work")
            .as_secs() as usize;
        let token = encode(
            &Header::new(Algorithm::HS256),
            &WidgetClaims {
                sub: "user_123".to_string(),
                scope: "widget:write".to_string(),
                exp: now + 3600,
                iat: Some(now),
                version: None,
                device_id: None,
            },
            &EncodingKey::from_secret("test-secret".as_bytes()),
        )
        .expect("token should encode");

        let error = widget_auth
            .verify_token(&token)
            .expect_err("invalid scope should fail");

        assert!(matches!(error, AppError::Forbidden(_)));
    }

    #[test]
    fn server_auth_issues_and_verifies_access_token() {
        let server_auth = ServerAuth::new(
            Some("test-server-secret".to_string()),
            "promiso-test".to_string(),
            900,
        );

        let token = server_auth
            .issue_access_token("user_123", Some("user@test.com"), Some(Uuid::nil()))
            .expect("token should encode");

        let claims = server_auth
            .verify_access_token(&token)
            .expect("token should verify");

        assert_eq!(claims.uid, "user_123");
        assert_eq!(claims.email.as_deref(), Some("user@test.com"));
    }

    #[test]
    fn server_auth_rejects_non_access_token_type() {
        let server_auth = ServerAuth::new(
            Some("test-server-secret".to_string()),
            "promiso-test".to_string(),
            900,
        );
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time should work")
            .as_secs() as usize;
        let token = encode(
            &Header::new(Algorithm::HS256),
            &ServerAccessClaims {
                sub: "user_123".to_string(),
                email: Some("user@test.com".to_string()),
                token_type: "refresh".to_string(),
                sid: Some(Uuid::nil()),
                iss: "promiso-test".to_string(),
                exp: now + 3600,
                iat: now,
            },
            &EncodingKey::from_secret("test-server-secret".as_bytes()),
        )
        .expect("token should encode");

        let error = server_auth
            .verify_access_token(&token)
            .expect_err("refresh token should be rejected");

        assert!(matches!(error, AppError::Forbidden(_)));
    }

    #[tokio::test]
    async fn require_auth_accepts_server_access_token() {
        let server_auth = ServerAuth::new(
            Some("test-server-secret".to_string()),
            "promiso-test".to_string(),
            900,
        );
        let token = server_auth
            .issue_access_token("user_123", Some("user@test.com"), Some(Uuid::nil()))
            .expect("token should encode");

        let app = Router::new()
            .route("/protected", get(protected))
            .layer(middleware::from_fn(require_auth))
            .layer(Extension(server_auth));

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/protected")
                    .header(AUTHORIZATION, format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("request should succeed");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.unwrap().to_bytes();
        assert_eq!(std::str::from_utf8(&body).unwrap(), "user_123");
    }
}
