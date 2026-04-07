use axum::extract::{Path, Query, State};
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::response::ApiResponse;
use crate::services::admin_subscription_service::{
    self, DashboardSummary, GrantEntitlementOverrideRequest, ProPlanDashboard,
    RevokeEntitlementOverrideRequest, UserSummaryResult, UserTimeline,
};

pub fn router() -> Router<PgPool> {
    Router::new()
        .route("/api/v1/admin/dashboard/summary", get(get_dashboard_summary))
        .route("/api/v1/admin/pro-plan/dashboard", get(get_pro_plan_dashboard))
        .route("/api/v1/admin/users", get(get_user_summary))
        .route("/api/v1/admin/users/{user_id}/timeline", get(get_user_timeline))
        .route(
            "/api/v1/admin/entitlements/grant",
            post(grant_entitlement_override),
        )
        .route(
            "/api/v1/admin/entitlements/revoke",
            post(revoke_entitlement_override),
        )
}

#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct UserSummaryQuery {
    query: Option<String>,
    field: Option<String>,
    subscription: Option<String>,
    r#override: Option<String>,
    limit: Option<i64>,
    start_after: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct UserTimelineQuery {
    limit: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DashboardSummaryPayload {
    summary: DashboardSummary,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProPlanDashboardPayload {
    dashboard: ProPlanDashboard,
}

#[derive(Debug, Serialize)]
struct SuccessPayload {
    success: bool,
}

async fn get_dashboard_summary(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<DashboardSummaryPayload>, AppError> {
    let summary = admin_subscription_service::build_dashboard_summary(&pool, &claims.uid).await?;
    ApiResponse::ok(DashboardSummaryPayload { summary })
}

async fn get_pro_plan_dashboard(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> Result<ApiResponse<ProPlanDashboardPayload>, AppError> {
    let dashboard = admin_subscription_service::build_pro_plan_dashboard(&pool, &claims.uid).await?;
    ApiResponse::ok(ProPlanDashboardPayload { dashboard })
}

async fn get_user_summary(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Query(query): Query<UserSummaryQuery>,
) -> Result<ApiResponse<UserSummaryResult>, AppError> {
    let result = admin_subscription_service::get_user_summary_with_filters(
        &pool,
        &claims.uid,
        query.query.as_deref(),
        query.field.as_deref().unwrap_or("all"),
        query.subscription.as_deref().unwrap_or("all"),
        query.r#override.as_deref().unwrap_or("all"),
        query.limit.unwrap_or(25),
        query.start_after.as_deref(),
    )
    .await?;
    ApiResponse::ok(result)
}

async fn get_user_timeline(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Path(user_id): Path<String>,
    Query(query): Query<UserTimelineQuery>,
) -> Result<ApiResponse<UserTimeline>, AppError> {
    let timeline = admin_subscription_service::get_user_timeline(
        &pool,
        &claims.uid,
        &user_id,
        query.limit.unwrap_or(20),
    )
    .await?;
    ApiResponse::ok(timeline)
}

async fn grant_entitlement_override(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(request): Json<GrantEntitlementOverrideRequest>,
) -> Result<ApiResponse<SuccessPayload>, AppError> {
    admin_subscription_service::grant_entitlement_override(&pool, &claims.uid, request).await?;
    ApiResponse::ok(SuccessPayload { success: true })
}

async fn revoke_entitlement_override(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(request): Json<RevokeEntitlementOverrideRequest>,
) -> Result<ApiResponse<SuccessPayload>, AppError> {
    admin_subscription_service::revoke_entitlement_override(&pool, &claims.uid, request).await?;
    ApiResponse::ok(SuccessPayload { success: true })
}
