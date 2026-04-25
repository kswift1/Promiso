use reqwest::Url;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::media::{
    IssueMediaDeleteUrlsRequest, IssueMediaUploadUrlsRequest, MediaDeleteTargetResponse,
    MediaUploadTargetResponse,
};
use crate::services::storage_service::GcsUploadSigner;

enum MediaBasePath {
    Schedule { prefix: String },
    PersonalEvent { prefix: String },
}

pub async fn issue_upload_urls(
    pool: &PgPool,
    uid: &str,
    req: IssueMediaUploadUrlsRequest,
    signer: &GcsUploadSigner,
) -> Result<Vec<MediaUploadTargetResponse>, AppError> {
    if req.count == 0 || req.count > 3 {
        return Err(AppError::BadRequest(
            "이미지는 1개 이상 3개 이하만 업로드할 수 있습니다".to_string(),
        ));
    }

    let content_type = req
        .content_type
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("image/jpeg");

    if content_type != "image/jpeg" {
        return Err(AppError::BadRequest(
            "이미지는 image/jpeg만 지원합니다".to_string(),
        ));
    }

    let base_path = authorize_base_path(pool, uid, req.base_path.trim()).await?;

    (0..req.count)
        .map(|_| {
            let object_path = match &base_path {
                MediaBasePath::Schedule { prefix } => {
                    format!("{prefix}/{}.jpg", Uuid::new_v4())
                }
                MediaBasePath::PersonalEvent { prefix } => {
                    format!("{prefix}/{}.jpg", Uuid::new_v4())
                }
            };
            let target = signer.sign_put_object(&object_path, content_type)?;

            Ok(MediaUploadTargetResponse {
                object_path: target.object_path,
                upload_url: target.upload_url,
                public_url: target.public_url,
                expires_at: target.expires_at,
                content_type: target.content_type,
            })
        })
        .collect()
}

pub async fn issue_delete_urls(
    pool: &PgPool,
    uid: &str,
    req: IssueMediaDeleteUrlsRequest,
    signer: &GcsUploadSigner,
) -> Result<Vec<MediaDeleteTargetResponse>, AppError> {
    if req.targets.is_empty() || req.targets.len() > 10 {
        return Err(AppError::BadRequest(
            "삭제 대상은 1개 이상 10개 이하만 처리할 수 있습니다".to_string(),
        ));
    }

    let mut responses = Vec::with_capacity(req.targets.len());

    for raw_target in req.targets {
        let object_path = normalize_object_path(raw_target.trim(), signer.bucket())?;
        authorize_object_path(pool, uid, &object_path).await?;
        let target = signer.sign_delete_object(&object_path)?;
        responses.push(MediaDeleteTargetResponse {
            object_path: target.object_path,
            delete_url: target.delete_url,
            expires_at: target.expires_at,
        });
    }

    Ok(responses)
}

async fn authorize_base_path(
    pool: &PgPool,
    uid: &str,
    base_path: &str,
) -> Result<MediaBasePath, AppError> {
    let segments = base_path.split('/').collect::<Vec<_>>();
    if segments.iter().any(|segment| segment.trim().is_empty()) {
        return Err(AppError::BadRequest(
            "base_path가 올바르지 않습니다".to_string(),
        ));
    }

    match segments.as_slice() {
        ["schedule_images", group_id, schedule_id] => {
            if schedule_id.contains("..") {
                return Err(AppError::BadRequest(
                    "base_path가 올바르지 않습니다".to_string(),
                ));
            }

            let group_id = Uuid::parse_str(group_id)
                .map_err(|_| AppError::BadRequest("group_id가 올바르지 않습니다".to_string()))?;

            ensure_group_member(pool, group_id, uid).await?;

            Ok(MediaBasePath::Schedule {
                prefix: base_path.to_string(),
            })
        }
        ["personal_event_images", owner_uid, event_id] => {
            if owner_uid != &uid || event_id.contains("..") {
                return Err(AppError::Forbidden(
                    "해당 경로에 업로드할 권한이 없습니다".to_string(),
                ));
            }

            Ok(MediaBasePath::PersonalEvent {
                prefix: base_path.to_string(),
            })
        }
        _ => Err(AppError::BadRequest(
            "지원하지 않는 업로드 경로입니다".to_string(),
        )),
    }
}

async fn authorize_object_path(
    pool: &PgPool,
    uid: &str,
    object_path: &str,
) -> Result<(), AppError> {
    let segments = object_path.split('/').collect::<Vec<_>>();
    if segments.iter().any(|segment| segment.trim().is_empty()) {
        return Err(AppError::BadRequest(
            "object_path가 올바르지 않습니다".to_string(),
        ));
    }

    match segments.as_slice() {
        ["profile_images", owner_uid, file_name] => {
            if owner_uid != &uid || file_name.contains("..") {
                return Err(AppError::Forbidden(
                    "해당 경로를 삭제할 권한이 없습니다".to_string(),
                ));
            }
            Ok(())
        }
        ["group_images", group_id, file_name] => {
            if file_name.contains("..") {
                return Err(AppError::BadRequest(
                    "object_path가 올바르지 않습니다".to_string(),
                ));
            }

            let group_id = Uuid::parse_str(group_id)
                .map_err(|_| AppError::BadRequest("group_id가 올바르지 않습니다".to_string()))?;
            ensure_group_admin(pool, group_id, uid).await
        }
        ["schedule_images", group_id, schedule_id, file_name] => {
            if schedule_id.contains("..") || file_name.contains("..") {
                return Err(AppError::BadRequest(
                    "object_path가 올바르지 않습니다".to_string(),
                ));
            }

            let group_id = Uuid::parse_str(group_id)
                .map_err(|_| AppError::BadRequest("group_id가 올바르지 않습니다".to_string()))?;
            ensure_group_member(pool, group_id, uid).await
        }
        ["personal_event_images", owner_uid, event_id, file_name] => {
            if owner_uid != &uid || event_id.contains("..") || file_name.contains("..") {
                return Err(AppError::Forbidden(
                    "해당 경로를 삭제할 권한이 없습니다".to_string(),
                ));
            }
            Ok(())
        }
        _ => Err(AppError::BadRequest(
            "지원하지 않는 미디어 경로입니다".to_string(),
        )),
    }
}

async fn ensure_group_member(pool: &PgPool, group_id: Uuid, uid: &str) -> Result<(), AppError> {
    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2)",
    )
    .bind(group_id)
    .bind(uid)
    .fetch_one(pool)
    .await?;

    if !is_member {
        return Err(AppError::Forbidden(
            "해당 그룹에 업로드할 권한이 없습니다".to_string(),
        ));
    }

    Ok(())
}

async fn ensure_group_admin(pool: &PgPool, group_id: Uuid, uid: &str) -> Result<(), AppError> {
    let is_admin: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2 AND role = 'admin')",
    )
    .bind(group_id)
    .bind(uid)
    .fetch_one(pool)
    .await?;

    if !is_admin {
        return Err(AppError::Forbidden(
            "해당 그룹 이미지를 삭제할 권한이 없습니다".to_string(),
        ));
    }

    Ok(())
}

fn normalize_object_path(raw_target: &str, bucket: &str) -> Result<String, AppError> {
    if raw_target.is_empty() {
        return Err(AppError::BadRequest(
            "삭제 대상이 비어 있습니다".to_string(),
        ));
    }

    if let Some(rest) = raw_target.strip_prefix("gs://") {
        return parse_gs_url(rest, bucket);
    }

    if raw_target.starts_with("http://") || raw_target.starts_with("https://") {
        let url = Url::parse(raw_target)
            .map_err(|_| AppError::BadRequest("미디어 URL이 올바르지 않습니다".to_string()))?;

        let Some(host) = url.host_str() else {
            return Err(AppError::BadRequest(
                "미디어 URL이 올바르지 않습니다".to_string(),
            ));
        };

        if host == "storage.googleapis.com" {
            return parse_storage_googleapis_url(&url, bucket);
        }

        if host.contains("firebasestorage.googleapis.com") {
            return parse_firebase_storage_url(&url, bucket);
        }

        return Err(AppError::BadRequest(
            "지원하지 않는 미디어 URL입니다".to_string(),
        ));
    }

    Ok(raw_target.to_string())
}

fn parse_storage_googleapis_url(url: &Url, bucket: &str) -> Result<String, AppError> {
    let path = url.path().trim_start_matches('/');
    let (url_bucket, object_path) = path
        .split_once('/')
        .ok_or_else(|| AppError::BadRequest("미디어 URL이 올바르지 않습니다".to_string()))?;
    ensure_supported_bucket(url_bucket, bucket)?;
    percent_decode(object_path)
}

fn parse_firebase_storage_url(url: &Url, bucket: &str) -> Result<String, AppError> {
    let segments = url
        .path()
        .trim_start_matches('/')
        .split('/')
        .collect::<Vec<_>>();
    match segments.as_slice() {
        ["v0", "b", url_bucket, "o", encoded_object_path] => {
            ensure_supported_bucket(url_bucket, bucket)?;
            percent_decode(encoded_object_path)
        }
        _ => Err(AppError::BadRequest(
            "미디어 URL이 올바르지 않습니다".to_string(),
        )),
    }
}

fn parse_gs_url(raw_target: &str, bucket: &str) -> Result<String, AppError> {
    let (url_bucket, object_path) = raw_target
        .split_once('/')
        .ok_or_else(|| AppError::BadRequest("gs URL이 올바르지 않습니다".to_string()))?;
    ensure_supported_bucket(url_bucket, bucket)?;
    Ok(object_path.to_string())
}

fn ensure_supported_bucket(actual: &str, expected: &str) -> Result<(), AppError> {
    if actual != expected {
        return Err(AppError::BadRequest("지원하지 않는 버킷입니다".to_string()));
    }

    Ok(())
}

fn percent_decode(input: &str) -> Result<String, AppError> {
    let bytes = input.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut index = 0;

    while index < bytes.len() {
        if bytes[index] == b'%' {
            if index + 2 >= bytes.len() {
                return Err(AppError::BadRequest(
                    "미디어 URL이 올바르지 않습니다".to_string(),
                ));
            }

            let hex = std::str::from_utf8(&bytes[index + 1..index + 3])
                .map_err(|_| AppError::BadRequest("미디어 URL이 올바르지 않습니다".to_string()))?;
            let value = u8::from_str_radix(hex, 16)
                .map_err(|_| AppError::BadRequest("미디어 URL이 올바르지 않습니다".to_string()))?;
            decoded.push(value);
            index += 3;
        } else {
            decoded.push(bytes[index]);
            index += 1;
        }
    }

    String::from_utf8(decoded)
        .map_err(|_| AppError::BadRequest("미디어 URL이 올바르지 않습니다".to_string()))
}
