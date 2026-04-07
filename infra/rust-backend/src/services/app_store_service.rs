use std::fs;
use std::path::PathBuf;
use std::sync::Arc;

use app_store_server_library::primitives::environment::Environment;
use app_store_server_library::primitives::notification_type_v2::NotificationTypeV2;
use app_store_server_library::primitives::offer_type::OfferType;
use app_store_server_library::primitives::product_type::ProductType;
use app_store_server_library::signed_data_verifier::SignedDataVerifier;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use chrono::{DateTime, Utc};
use serde::de::DeserializeOwned;

use crate::config::Config;
use crate::errors::AppError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppStoreTransactionKind {
    AutoRenewableSubscription,
    NonConsumable,
    Consumable,
    NonRenewingSubscription,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppStoreNotificationKind {
    Subscribed,
    DidChangeRenewalPref,
    DidChangeRenewalStatus,
    OfferRedeemed,
    DidRenew,
    Expired,
    DidFailToRenew,
    GracePeriodExpired,
    PriceIncrease,
    Refund,
    RefundDeclined,
    ConsumptionRequest,
    RenewalExtended,
    Revoke,
    Test,
    RenewalExtension,
    RefundReversed,
    ExternalPurchaseToken,
    OneTimeCharge,
    MetadataUpdate,
    Migration,
    PriceChange,
    RescindConsent,
}

impl AppStoreNotificationKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Subscribed => "SUBSCRIBED",
            Self::DidChangeRenewalPref => "DID_CHANGE_RENEWAL_PREF",
            Self::DidChangeRenewalStatus => "DID_CHANGE_RENEWAL_STATUS",
            Self::OfferRedeemed => "OFFER_REDEEMED",
            Self::DidRenew => "DID_RENEW",
            Self::Expired => "EXPIRED",
            Self::DidFailToRenew => "DID_FAIL_TO_RENEW",
            Self::GracePeriodExpired => "GRACE_PERIOD_EXPIRED",
            Self::PriceIncrease => "PRICE_INCREASE",
            Self::Refund => "REFUND",
            Self::RefundDeclined => "REFUND_DECLINED",
            Self::ConsumptionRequest => "CONSUMPTION_REQUEST",
            Self::RenewalExtended => "RENEWAL_EXTENDED",
            Self::Revoke => "REVOKE",
            Self::Test => "TEST",
            Self::RenewalExtension => "RENEWAL_EXTENSION",
            Self::RefundReversed => "REFUND_REVERSED",
            Self::ExternalPurchaseToken => "EXTERNAL_PURCHASE_TOKEN",
            Self::OneTimeCharge => "ONE_TIME_CHARGE",
            Self::MetadataUpdate => "METADATA_UPDATE",
            Self::Migration => "MIGRATION",
            Self::PriceChange => "PRICE_CHANGE",
            Self::RescindConsent => "RESCIND_CONSENT",
        }
    }
}

#[derive(Debug, Clone)]
pub struct VerifiedTransaction {
    pub original_transaction_id: String,
    pub transaction_id: Option<String>,
    pub product_id: String,
    pub purchase_date: Option<DateTime<Utc>>,
    pub expires_date: Option<DateTime<Utc>>,
    pub signed_date: Option<DateTime<Utc>>,
    pub revocation_date: Option<DateTime<Utc>>,
    pub transaction_kind: Option<AppStoreTransactionKind>,
    pub offer_type: Option<i32>,
    pub offer_identifier: Option<String>,
}

#[derive(Debug, Clone)]
pub struct VerifiedRenewalInfo {
    pub signed_date: Option<DateTime<Utc>>,
    pub grace_period_expires_date: Option<DateTime<Utc>>,
    pub renewal_date: Option<DateTime<Utc>>,
    pub is_in_billing_retry_period: bool,
}

#[derive(Debug, Clone)]
pub struct VerifiedNotification {
    pub notification_type: AppStoreNotificationKind,
    pub signed_date: Option<DateTime<Utc>>,
    pub transaction: VerifiedTransaction,
    pub renewal_info: Option<VerifiedRenewalInfo>,
}

pub trait AppStoreVerifier: Send + Sync {
    fn verify_transaction(&self, signed_transaction: &str)
        -> Result<VerifiedTransaction, AppError>;
    fn verify_notification(&self, signed_payload: &str) -> Result<VerifiedNotification, AppError>;
}

pub type SharedAppStoreVerifier = Arc<dyn AppStoreVerifier>;

pub struct RealAppStoreVerifier {
    verifier: Option<SignedDataVerifier>,
    allow_decode_fallback: bool,
}

impl RealAppStoreVerifier {
    pub fn new(config: &Config) -> Self {
        let allow_decode_fallback = config.apns_environment != "production";
        let environment = if config.apns_environment == "production" {
            Environment::Production
        } else {
            Environment::Sandbox
        };

        let root_certs = load_root_certificates();
        let verifier = match root_certs {
            Ok(root_certificates) => Some(SignedDataVerifier::new(
                root_certificates,
                environment,
                config
                    .apns_bundle_id
                    .clone()
                    .unwrap_or_else(|| derive_apns_bundle_id(&config.firebase_project_id)),
                config.app_store_apple_id,
            )),
            Err(error) if allow_decode_fallback => {
                tracing::warn!(
                    "App Store root certificate load failed, using decode fallback: {error}"
                );
                None
            }
            Err(error) => panic!("Failed to load App Store root certificates: {error}"),
        };

        Self {
            verifier,
            allow_decode_fallback,
        }
    }

    fn verify_signed_object<T, F>(&self, signed_value: &str, verify: F) -> Result<T, AppError>
    where
        T: DeserializeOwned,
        F: FnOnce(
            &SignedDataVerifier,
            &str,
        ) -> Result<
            T,
            app_store_server_library::signed_data_verifier::SignedDataVerifierError,
        >,
    {
        match &self.verifier {
            Some(verifier) => match verify(verifier, signed_value) {
                Ok(value) => Ok(value),
                Err(error) if self.allow_decode_fallback => {
                    tracing::warn!(
                        "App Store verification failed, falling back to decode-only: {error}"
                    );
                    decode_jws_payload(signed_value)
                }
                Err(error) => Err(AppError::PreconditionFailed(format!(
                    "App Store verification failed: {error}"
                ))),
            },
            None if self.allow_decode_fallback => decode_jws_payload(signed_value),
            None => Err(AppError::Internal(
                "App Store verifier is not configured".to_string(),
            )),
        }
    }
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

impl AppStoreVerifier for RealAppStoreVerifier {
    fn verify_transaction(
        &self,
        signed_transaction: &str,
    ) -> Result<VerifiedTransaction, AppError> {
        let payload = self.verify_signed_object(signed_transaction, |verifier, value| {
            verifier.verify_and_decode_signed_transaction(value)
        })?;
        Ok(map_transaction(payload))
    }

    fn verify_notification(&self, signed_payload: &str) -> Result<VerifiedNotification, AppError> {
        let payload = self.verify_signed_object(signed_payload, |verifier, value| {
            verifier.verify_and_decode_notification(value)
        })?;

        let data = payload
            .data
            .ok_or_else(|| AppError::BadRequest("Missing notification data".to_string()))?;
        let signed_transaction = data
            .signed_transaction_info
            .ok_or_else(|| AppError::BadRequest("Missing signedTransactionInfo".to_string()))?;

        let transaction = self.verify_transaction(&signed_transaction)?;
        let renewal_info = match data.signed_renewal_info {
            Some(signed_renewal_info) => {
                let payload = self
                    .verify_signed_object(&signed_renewal_info, |verifier, value| {
                        verifier.verify_and_decode_renewal_info(value)
                    })?;
                Some(VerifiedRenewalInfo {
                    signed_date: payload.signed_date,
                    grace_period_expires_date: payload.grace_period_expires_date,
                    renewal_date: payload.renewal_date,
                    is_in_billing_retry_period: payload.is_in_billing_retry_period.unwrap_or(false),
                })
            }
            None => None,
        };

        Ok(VerifiedNotification {
            notification_type: map_notification_type(payload.notification_type),
            signed_date: payload.signed_date,
            transaction,
            renewal_info,
        })
    }
}

fn load_root_certificates() -> Result<Vec<Vec<u8>>, std::io::Error> {
    let cert_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../firebase/functions/certs");
    let g2 = fs::read(cert_dir.join("AppleRootCA-G2.der"))?;
    let g3 = fs::read(cert_dir.join("AppleRootCA-G3.der"))?;
    Ok(vec![g2, g3])
}

fn decode_jws_payload<T: DeserializeOwned>(signed_value: &str) -> Result<T, AppError> {
    let mut parts = signed_value.split('.');
    let _header = parts
        .next()
        .ok_or_else(|| AppError::PreconditionFailed("Invalid JWS format".to_string()))?;
    let payload = parts
        .next()
        .ok_or_else(|| AppError::PreconditionFailed("Invalid JWS format".to_string()))?;

    if parts.next().is_none() {
        return Err(AppError::PreconditionFailed(
            "Invalid JWS format".to_string(),
        ));
    }

    let decoded = URL_SAFE_NO_PAD
        .decode(payload)
        .map_err(|error| AppError::PreconditionFailed(format!("Invalid JWS payload: {error}")))?;

    serde_json::from_slice(&decoded)
        .map_err(|error| AppError::PreconditionFailed(format!("Invalid JWS payload JSON: {error}")))
}

fn map_transaction(
    payload: app_store_server_library::primitives::jws_transaction_decoded_payload::JWSTransactionDecodedPayload,
) -> VerifiedTransaction {
    VerifiedTransaction {
        original_transaction_id: payload.original_transaction_id.unwrap_or_default(),
        transaction_id: payload.transaction_id,
        product_id: payload.product_id.unwrap_or_default(),
        purchase_date: payload.purchase_date,
        expires_date: payload.expires_date,
        signed_date: payload.signed_date,
        revocation_date: payload.revocation_date,
        transaction_kind: payload.r#type.map(map_product_type),
        offer_type: payload.offer_type.map(map_offer_type),
        offer_identifier: payload.offer_identifier,
    }
}

fn map_product_type(product_type: ProductType) -> AppStoreTransactionKind {
    match product_type {
        ProductType::AutoRenewableSubscription => {
            AppStoreTransactionKind::AutoRenewableSubscription
        }
        ProductType::NonConsumable => AppStoreTransactionKind::NonConsumable,
        ProductType::Consumable => AppStoreTransactionKind::Consumable,
        ProductType::NonRenewingSubscription => AppStoreTransactionKind::NonRenewingSubscription,
    }
}

fn map_offer_type(offer_type: OfferType) -> i32 {
    match offer_type {
        OfferType::IntroductoryOffer => 1,
        OfferType::PromotionalOffer => 2,
        OfferType::OfferCode => 3,
        OfferType::WinBackOffer => 4,
    }
}

fn map_notification_type(notification_type: NotificationTypeV2) -> AppStoreNotificationKind {
    match notification_type {
        NotificationTypeV2::Subscribed => AppStoreNotificationKind::Subscribed,
        NotificationTypeV2::DidChangeRenewalPref => AppStoreNotificationKind::DidChangeRenewalPref,
        NotificationTypeV2::DidChangeRenewalStatus => {
            AppStoreNotificationKind::DidChangeRenewalStatus
        }
        NotificationTypeV2::OfferRedeemed => AppStoreNotificationKind::OfferRedeemed,
        NotificationTypeV2::DidRenew => AppStoreNotificationKind::DidRenew,
        NotificationTypeV2::Expired => AppStoreNotificationKind::Expired,
        NotificationTypeV2::DidFailToRenew => AppStoreNotificationKind::DidFailToRenew,
        NotificationTypeV2::GracePeriodExpired => AppStoreNotificationKind::GracePeriodExpired,
        NotificationTypeV2::PriceIncrease => AppStoreNotificationKind::PriceIncrease,
        NotificationTypeV2::Refund => AppStoreNotificationKind::Refund,
        NotificationTypeV2::RefundDeclined => AppStoreNotificationKind::RefundDeclined,
        NotificationTypeV2::ConsumptionRequest => AppStoreNotificationKind::ConsumptionRequest,
        NotificationTypeV2::RenewalExtended => AppStoreNotificationKind::RenewalExtended,
        NotificationTypeV2::Revoke => AppStoreNotificationKind::Revoke,
        NotificationTypeV2::Test => AppStoreNotificationKind::Test,
        NotificationTypeV2::RenewalExtension => AppStoreNotificationKind::RenewalExtension,
        NotificationTypeV2::RefundReversed => AppStoreNotificationKind::RefundReversed,
        NotificationTypeV2::ExternalPurchaseToken => {
            AppStoreNotificationKind::ExternalPurchaseToken
        }
        NotificationTypeV2::OneTimeCharge => AppStoreNotificationKind::OneTimeCharge,
        NotificationTypeV2::MetadataUpdate => AppStoreNotificationKind::MetadataUpdate,
        NotificationTypeV2::Migration => AppStoreNotificationKind::Migration,
        NotificationTypeV2::PriceChange => AppStoreNotificationKind::PriceChange,
        NotificationTypeV2::RescindConsent => AppStoreNotificationKind::RescindConsent,
    }
}
