use axum::extract::Request;
use axum::http::header::AUTHORIZATION;
use axum::middleware::Next;
use axum::response::Response;

use crate::errors::AppError;

#[derive(Debug, Clone)]
pub struct Claims {
    pub uid: String,
    pub email: Option<String>,
}

pub async fn require_auth(
    mut request: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .ok_or_else(|| AppError::Unauthorized("Missing or invalid Authorization header".to_string()))?;

    let claims = verify_firebase_token(token).await?;

    request.extensions_mut().insert(claims);
    Ok(next.run(request).await)
}

async fn verify_firebase_token(token: &str) -> Result<Claims, AppError> {
    // TODO: Firebase 공개 키로 JWT 서명 검증 구현
    // 현재는 토큰에서 uid를 디코딩만 함 (개발용)
    let _header = jsonwebtoken::decode_header(token)
        .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;

    // 개발 단계: 서명 검증 없이 페이로드만 디코딩
    // Prod에서는 Firebase 공개 키로 검증 필수
    let mut validation = jsonwebtoken::Validation::default();
    validation.insecure_disable_signature_validation();
    validation.validate_aud = false;

    let token_data = jsonwebtoken::decode::<serde_json::Value>(
        token,
        &jsonwebtoken::DecodingKey::from_secret(b""),
        &validation,
    )
    .map_err(|e| AppError::Unauthorized(format!("Invalid token: {e}")))?;

    let uid = token_data
        .claims
        .get("sub")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::Unauthorized("Missing sub claim".to_string()))?
        .to_string();

    let email = token_data
        .claims
        .get("email")
        .and_then(|v| v.as_str())
        .map(String::from);

    Ok(Claims { uid, email })
}
