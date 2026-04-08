pub mod admin;
mod briefing;
mod groups;
mod health;
pub mod internal;
mod notifications;
mod schedules;
mod subscriptions;
mod users;

use std::sync::Arc;

use axum::middleware;
use axum::Router;
use sqlx::PgPool;

use crate::config::Config;
use crate::middleware::auth::{require_auth, FirebaseAuth, WidgetAuth};
use crate::push::{build_live_activity_sender, build_push_sender};
use crate::services::app_store_service::{RealAppStoreVerifier, SharedAppStoreVerifier};

pub fn create_router(pool: PgPool, config: &Config) -> Router {
    let firebase_auth = FirebaseAuth::new(config.firebase_project_id.clone());
    let widget_auth = WidgetAuth::new(config.widget_jwt_secret.clone());
    let push_sender = build_push_sender(config);
    let live_activity_sender = build_live_activity_sender(config);
    let public_push_sender = push_sender.clone();
    let public_live_activity_sender = live_activity_sender.clone();
    let app_store_verifier: SharedAppStoreVerifier = Arc::new(RealAppStoreVerifier::new(config));

    // 인증 필요한 라우트
    let authenticated_routes = users::router()
        .merge(admin::router())
        .merge(groups::router())
        .merge(schedules::router())
        .merge(notifications::router())
        .merge(subscriptions::router())
        .merge(briefing::router())
        .layer(axum::Extension(app_store_verifier.clone()))
        .layer(axum::Extension(live_activity_sender.clone()))
        .layer(axum::Extension(push_sender))
        .layer(middleware::from_fn(require_auth));

    let public_routes = schedules::public_router()
        .merge(subscriptions::public_router())
        .layer(axum::Extension(app_store_verifier))
        .layer(axum::Extension(public_live_activity_sender))
        .layer(axum::Extension(public_push_sender));

    Router::new()
        .merge(health::router()) // /health — 인증 불필요
        .merge(groups::public_router()) // /api/v1/groups/preview — 인증 불필요
        .merge(internal::router()) // /api/v1/internal/* — 스케줄러 전용 (X-Scheduler-Secret 인증)
        .merge(public_routes)
        .merge(authenticated_routes) // /api/v1/users/*, /api/v1/groups/* — 인증 필요
        .layer(axum::Extension(widget_auth))
        .layer(axum::Extension(firebase_auth))
        .with_state(pool)
}
