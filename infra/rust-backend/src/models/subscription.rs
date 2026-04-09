use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

// ============================================================
// DB 열거형 (PostgreSQL 타입 매핑)
// ============================================================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "subscription_status", rename_all = "snake_case")]
#[serde(rename_all = "camelCase")]
pub enum SubscriptionStatus {
    None,
    Subscribed,
    Lifetime,
    Expired,
    GracePeriod,
    Revoked,
}

impl SubscriptionStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::None => "none",
            Self::Subscribed => "subscribed",
            Self::Lifetime => "lifetime",
            Self::Expired => "expired",
            Self::GracePeriod => "grace_period",
            Self::Revoked => "revoked",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "entitlement_source", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum EntitlementSource {
    Subscription,
    Override,
    None,
}

// ============================================================
// DB 모델
// ============================================================

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct SubscriptionRecord {
    pub user_id: String,
    pub status: SubscriptionStatus,
    pub product_id: Option<String>,
    pub original_transaction_id: Option<String>,
    pub expiration_date: Option<DateTime<Utc>>,
    pub purchase_date: Option<DateTime<Utc>>,
    pub latest_app_store_signed_date: Option<i64>,
    pub latest_transaction_id: Option<String>,
    pub last_notification_type: Option<String>,
    pub last_offer_type: Option<i32>,
    pub last_offer_identifier: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct SubscriptionOwnerRecord {
    pub original_transaction_id: String,
    pub user_id: String,
    pub product_id: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct EntitlementOverrideRecord {
    pub user_id: String,
    pub is_active: bool,
    pub override_type: String,
    pub reason: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
    pub created_by: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub revoked_by: Option<String>,
    pub revoked_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct EntitlementRecord {
    pub user_id: String,
    pub has_pro: bool,
    pub source: EntitlementSource,
    pub subscription_status: Option<SubscriptionStatus>,
    pub product_id: Option<String>,
    pub expiration_date: Option<DateTime<Utc>>,
    pub override_active: bool,
    pub override_expires_at: Option<DateTime<Utc>>,
    pub override_type: Option<String>,
    pub last_offer_type: Option<i32>,
    pub last_offer_identifier: Option<String>,
    pub updated_at: DateTime<Utc>,
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VerifyPurchaseRequest {
    pub transaction_jws: String,
    pub product_id: String,
    pub force_transfer: Option<bool>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppleNotificationRequest {
    pub signed_payload: String,
}

// ============================================================
// 응답 DTO
// ============================================================

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubscriptionStatusResponse {
    pub status: SubscriptionStatus,
    pub product_id: Option<String>,
    pub original_transaction_id: Option<String>,
    pub expiration_date: Option<DateTime<Utc>>,
    pub purchase_date: Option<DateTime<Utc>>,
    pub latest_app_store_signed_date: Option<i64>,
    pub latest_transaction_id: Option<String>,
    pub last_notification_type: Option<String>,
    pub last_offer_type: Option<i32>,
    pub last_offer_identifier: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EntitlementResponse {
    pub has_pro: bool,
    pub source: EntitlementSource,
    pub subscription_status: Option<SubscriptionStatus>,
    pub product_id: Option<String>,
    pub expiration_date: Option<DateTime<Utc>>,
    pub override_active: bool,
    pub override_expires_at: Option<DateTime<Utc>>,
    pub override_type: Option<String>,
    pub last_offer_type: Option<i32>,
    pub last_offer_identifier: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VerifyPurchaseResponse {
    pub success: bool,
    pub subscription_status: SubscriptionStatusResponse,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SuccessResponse {
    pub success: bool,
}
