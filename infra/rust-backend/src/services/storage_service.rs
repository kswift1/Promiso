use std::fs;
use std::sync::Arc;

use chrono::{DateTime, Utc};
use rsa::pkcs1v15::SigningKey;
use rsa::pkcs8::DecodePrivateKey;
use rsa::signature::{SignatureEncoding, Signer};
use rsa::RsaPrivateKey;
use serde::Deserialize;
use sha2::{Digest, Sha256};

use crate::config::Config;
use crate::errors::AppError;

const GCS_HOST: &str = "storage.googleapis.com";
const GCS_ALGORITHM: &str = "GOOG4-RSA-SHA256";

#[derive(Clone)]
pub struct GcsUploadSigner {
    bucket: String,
    client_email: String,
    private_key: Arc<RsaPrivateKey>,
    signed_url_ttl_seconds: u32,
}

#[derive(Clone, Debug)]
pub struct SignedUploadTarget {
    pub object_path: String,
    pub upload_url: String,
    pub public_url: String,
    pub expires_at: DateTime<Utc>,
    pub content_type: String,
}

#[derive(Clone, Debug)]
pub struct SignedDeleteTarget {
    pub object_path: String,
    pub delete_url: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Deserialize)]
struct ServiceAccountCredentials {
    client_email: String,
    private_key: String,
}

impl GcsUploadSigner {
    pub fn from_config(config: &Config) -> Result<Option<Self>, AppError> {
        let Some(bucket) = config.gcs_upload_bucket.clone() else {
            return Ok(None);
        };

        if let Some(service_account_json) = config.firebase_service_account_json.as_deref() {
            return Ok(Some(Self::from_service_account_json(
                bucket,
                service_account_json,
                config.gcs_signed_url_ttl_seconds,
            )?));
        }

        if let Some(path) = config.google_application_credentials.as_deref() {
            let service_account_json = fs::read_to_string(path).map_err(|error| {
                AppError::Internal(format!(
                    "Failed to read Google service account file {path}: {error}"
                ))
            })?;
            return Ok(Some(Self::from_service_account_json(
                bucket,
                &service_account_json,
                config.gcs_signed_url_ttl_seconds,
            )?));
        }

        Err(AppError::Internal(
            "GCS upload signing requires GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON"
                .to_string(),
        ))
    }

    fn from_service_account_json(
        bucket: String,
        service_account_json: &str,
        signed_url_ttl_seconds: u32,
    ) -> Result<Self, AppError> {
        let credentials: ServiceAccountCredentials = serde_json::from_str(service_account_json)
            .map_err(|error| {
                AppError::Internal(format!(
                    "Failed to parse Google service account JSON: {error}"
                ))
            })?;

        let private_key =
            RsaPrivateKey::from_pkcs8_pem(&credentials.private_key).map_err(|error| {
                AppError::Internal(format!("Invalid service account private key: {error}"))
            })?;

        Ok(Self {
            bucket,
            client_email: credentials.client_email,
            private_key: Arc::new(private_key),
            signed_url_ttl_seconds,
        })
    }

    pub fn bucket(&self) -> &str {
        &self.bucket
    }

    pub fn public_url(&self, object_path: &str) -> String {
        format!(
            "https://{GCS_HOST}/{}/{}",
            percent_encode(&self.bucket, false),
            percent_encode(object_path, false)
        )
    }

    pub fn sign_put_object(
        &self,
        object_path: &str,
        content_type: &str,
    ) -> Result<SignedUploadTarget, AppError> {
        let now = Utc::now();
        let timestamp = now.format("%Y%m%dT%H%M%SZ").to_string();
        let datestamp = now.format("%Y%m%d").to_string();
        let credential_scope = format!("{datestamp}/auto/storage/goog4_request");
        let credential = format!("{}/{}", self.client_email, credential_scope);
        let canonical_uri = format!(
            "/{}/{}",
            percent_encode(&self.bucket, false),
            percent_encode(object_path, false)
        );

        let mut query_params = vec![
            ("X-Goog-Algorithm".to_string(), GCS_ALGORITHM.to_string()),
            ("X-Goog-Credential".to_string(), credential),
            ("X-Goog-Date".to_string(), timestamp.clone()),
            (
                "X-Goog-Expires".to_string(),
                self.signed_url_ttl_seconds.to_string(),
            ),
            (
                "X-Goog-SignedHeaders".to_string(),
                "content-type;host".to_string(),
            ),
        ];
        query_params.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

        let canonical_query_string = query_params
            .iter()
            .map(|(key, value)| {
                format!(
                    "{}={}",
                    percent_encode(key, true),
                    percent_encode(value, true)
                )
            })
            .collect::<Vec<_>>()
            .join("&");

        let canonical_headers = format!("content-type:{content_type}\nhost:{GCS_HOST}\n");
        let canonical_request = format!(
            "PUT\n{canonical_uri}\n{canonical_query_string}\n{canonical_headers}\ncontent-type;host\nUNSIGNED-PAYLOAD"
        );
        let canonical_request_hash = hex::encode(Sha256::digest(canonical_request.as_bytes()));
        let string_to_sign =
            format!("{GCS_ALGORITHM}\n{timestamp}\n{credential_scope}\n{canonical_request_hash}");

        let signing_key = SigningKey::<Sha256>::new((*self.private_key).clone());
        let signature = signing_key.sign(string_to_sign.as_bytes());
        let signature_hex = hex::encode(signature.to_bytes());
        let upload_url = format!(
            "https://{GCS_HOST}{canonical_uri}?{canonical_query_string}&X-Goog-Signature={signature_hex}"
        );

        Ok(SignedUploadTarget {
            object_path: object_path.to_string(),
            public_url: self.public_url(object_path),
            upload_url,
            expires_at: now + chrono::Duration::seconds(self.signed_url_ttl_seconds as i64),
            content_type: content_type.to_string(),
        })
    }

    pub fn sign_delete_object(&self, object_path: &str) -> Result<SignedDeleteTarget, AppError> {
        let now = Utc::now();
        let timestamp = now.format("%Y%m%dT%H%M%SZ").to_string();
        let datestamp = now.format("%Y%m%d").to_string();
        let credential_scope = format!("{datestamp}/auto/storage/goog4_request");
        let credential = format!("{}/{}", self.client_email, credential_scope);
        let canonical_uri = format!(
            "/{}/{}",
            percent_encode(&self.bucket, false),
            percent_encode(object_path, false)
        );

        let mut query_params = vec![
            ("X-Goog-Algorithm".to_string(), GCS_ALGORITHM.to_string()),
            ("X-Goog-Credential".to_string(), credential),
            ("X-Goog-Date".to_string(), timestamp.clone()),
            (
                "X-Goog-Expires".to_string(),
                self.signed_url_ttl_seconds.to_string(),
            ),
            ("X-Goog-SignedHeaders".to_string(), "host".to_string()),
        ];
        query_params.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

        let canonical_query_string = query_params
            .iter()
            .map(|(key, value)| {
                format!(
                    "{}={}",
                    percent_encode(key, true),
                    percent_encode(value, true)
                )
            })
            .collect::<Vec<_>>()
            .join("&");

        let canonical_headers = format!("host:{GCS_HOST}\n");
        let canonical_request = format!(
            "DELETE\n{canonical_uri}\n{canonical_query_string}\n{canonical_headers}\nhost\nUNSIGNED-PAYLOAD"
        );
        let canonical_request_hash = hex::encode(Sha256::digest(canonical_request.as_bytes()));
        let string_to_sign =
            format!("{GCS_ALGORITHM}\n{timestamp}\n{credential_scope}\n{canonical_request_hash}");

        let signing_key = SigningKey::<Sha256>::new((*self.private_key).clone());
        let signature = signing_key.sign(string_to_sign.as_bytes());
        let signature_hex = hex::encode(signature.to_bytes());
        let delete_url = format!(
            "https://{GCS_HOST}{canonical_uri}?{canonical_query_string}&X-Goog-Signature={signature_hex}"
        );

        Ok(SignedDeleteTarget {
            object_path: object_path.to_string(),
            delete_url,
            expires_at: now + chrono::Duration::seconds(self.signed_url_ttl_seconds as i64),
        })
    }
}

fn percent_encode(input: &str, encode_slash: bool) -> String {
    let mut encoded = String::with_capacity(input.len());

    for byte in input.bytes() {
        let is_unreserved = matches!(
            byte,
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~'
        );

        if is_unreserved || (!encode_slash && byte == b'/') {
            encoded.push(byte as char);
        } else {
            encoded.push('%');
            encoded.push_str(&format!("{byte:02X}"));
        }
    }

    encoded
}
