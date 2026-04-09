pub mod admin;
pub mod auth;
mod app_config;
mod briefing;
mod emoji;
mod groups;
mod health;
pub mod internal;
mod notifications;
mod places;
mod schedules;
mod subscriptions;
mod users;
mod widget;

use std::sync::Arc;

use axum::middleware;
use axum::Router;
use sqlx::PgPool;

use crate::config::Config;
use crate::middleware::auth::{require_auth, FirebaseAuth, ServerAuth, WidgetAuth};
use crate::push::{build_live_activity_sender, build_push_sender};
use crate::services::app_store_service::{RealAppStoreVerifier, SharedAppStoreVerifier};
use crate::services::provider_verifier::{RealProviderVerifier, SharedProviderVerifier};
use crate::services::storage_service::GcsUploadSigner;

pub fn create_router(pool: PgPool, config: &Config) -> Router {
    let firebase_auth = FirebaseAuth::new(config.firebase_project_id.clone());
    let server_auth = ServerAuth::new(
        config.auth_jwt_secret.clone(),
        config.auth_jwt_issuer.clone(),
        config.auth_access_token_ttl_seconds,
    );
    let widget_auth = WidgetAuth::new(config.widget_jwt_secret.clone());
    let push_sender = build_push_sender(config);
    let live_activity_sender = build_live_activity_sender(config);
    let public_push_sender = push_sender.clone();
    let public_live_activity_sender = live_activity_sender.clone();
    let app_store_verifier: SharedAppStoreVerifier = Arc::new(RealAppStoreVerifier::new(config));
    let provider_verifier: SharedProviderVerifier = Arc::new(RealProviderVerifier::new(config));
    let gcs_upload_signer = match GcsUploadSigner::from_config(config) {
        Ok(signer) => signer,
        Err(error) => {
            tracing::error!("GCS upload signer disabled: {}", error);
            None
        }
    };

    // 인증 필요한 라우트
    let authenticated_routes = users::router()
        .merge(auth::router())
        .merge(admin::router())
        .merge(groups::router())
        .merge(schedules::router())
        .merge(notifications::router())
        .merge(subscriptions::router())
        .merge(briefing::router())
        .merge(widget::router())
        .merge(emoji::router())
        .layer(axum::Extension(app_store_verifier.clone()))
        .layer(axum::Extension(live_activity_sender.clone()))
        .layer(axum::Extension(gcs_upload_signer.clone()))
        .layer(axum::Extension(push_sender))
        .layer(middleware::from_fn(require_auth));

    let public_routes = schedules::public_router()
        .merge(auth::public_router())
        .merge(subscriptions::public_router())
        .merge(widget::widget_snapshot_router())
        .layer(axum::Extension(app_store_verifier))
        .layer(axum::Extension(public_live_activity_sender))
        .layer(axum::Extension(public_push_sender));

    Router::new()
        .merge(health::router()) // /health — 인증 불필요
        .merge(app_config::router()) // /api/v1/app-config — 인증 불필요
        .merge(groups::public_router()) // /api/v1/groups/preview — 인증 불필요
        .merge(places::router()) // /api/v1/places/* — 인증 불필요
        .merge(internal::router()) // /api/v1/internal/* — 스케줄러 전용 (X-Scheduler-Secret 인증)
        .merge(public_routes)
        .merge(authenticated_routes) // /api/v1/users/*, /api/v1/groups/* — 인증 필요
        .layer(axum::Extension(provider_verifier))
        .layer(axum::Extension(server_auth))
        .layer(axum::Extension(widget_auth))
        .layer(axum::Extension(firebase_auth))
        .with_state(pool)
}
