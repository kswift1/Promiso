use axum::extract::{Path, Query, State};
use axum::routing::{delete, get, patch, post};
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::Claims;
use crate::models::schedule::*;
use crate::response::ApiResponse;
use crate::services::schedule_service;

pub fn router() -> Router<PgPool> {
    let schedule_routes = Router::new()
        .route("/", post(create_schedule))
        .route("/home", get(get_home_schedules))
        .route("/personal/past", get(get_personal_past_schedules))
        .route("/calendar", get(get_calendar_schedules))
        .route("/calendar-sync", get(get_calendar_sync))
        .route("/check-conflicts", post(check_conflicts))
        .route("/extract", post(extract_schedule))
        .route("/{id}", get(get_schedule))
        .route("/{id}", patch(update_schedule))
        .route("/{id}", delete(delete_schedule))
        .route("/{id}/respond", post(respond_schedule));

    let recurring_routes = Router::new()
        .route("/", post(create_recurring_schedule))
        .route("/", get(get_recurring_schedules))
        .route("/{id}", patch(update_recurring_schedule))
        .route("/{id}", delete(delete_recurring_schedule));

    // Group-nested schedule routes
    let group_schedule_routes = Router::new().route("/", get(get_group_schedules));

    Router::new()
        .nest("/api/v1/schedules", schedule_routes)
        .nest("/api/v1/recurring-schedules", recurring_routes)
        .nest(
            "/api/v1/groups/{group_id}/schedules",
            group_schedule_routes,
        )
}

async fn create_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CreateScheduleRequest>,
) -> Result<ApiResponse<CreateScheduleResponse>, AppError> {
    let result = schedule_service::create_schedule(&pool, &claims.uid, req).await?;
    ApiResponse::created(result)
}

async fn get_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<ScheduleResponse>, AppError> {
    let result = schedule_service::get_schedule(&pool, &claims.uid, id).await?;
    ApiResponse::ok(result)
}

async fn update_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateScheduleRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    schedule_service::update_schedule(&pool, &claims.uid, id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    schedule_service::delete_schedule(&pool, &claims.uid, id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn respond_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
    Json(req): Json<RespondScheduleRequest>,
) -> Result<ApiResponse<RespondScheduleResponse>, AppError> {
    let result = schedule_service::respond_schedule(&pool, &claims.uid, id, req).await?;
    ApiResponse::ok(result)
}

async fn get_group_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(group_id): Path<Uuid>,
    Query(query): Query<GroupScheduleQuery>,
) -> Result<ApiResponse<PaginatedScheduleResponse>, AppError> {
    let result =
        schedule_service::get_group_schedules(&pool, &claims.uid, group_id, query).await?;
    ApiResponse::ok(result)
}

async fn get_home_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Query(query): Query<HomeQuery>,
) -> Result<ApiResponse<Vec<ScheduleResponse>>, AppError> {
    let result = schedule_service::get_home_schedules(&pool, &claims.uid, query).await?;
    ApiResponse::ok(result)
}

async fn get_personal_past_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Query(query): Query<PersonalPastQuery>,
) -> Result<ApiResponse<Vec<ScheduleResponse>>, AppError> {
    let result = schedule_service::get_personal_past_schedules(
        &pool,
        &claims.uid,
        query.limit.unwrap_or(20),
        query.cursor,
    )
    .await?;
    ApiResponse::ok(result)
}

async fn get_calendar_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Query(query): Query<CalendarQuery>,
) -> Result<ApiResponse<CalendarResponse>, AppError> {
    let result = schedule_service::get_calendar_schedules(&pool, &claims.uid, query).await?;
    ApiResponse::ok(result)
}

async fn get_calendar_sync(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
) -> Result<ApiResponse<Vec<CalendarSyncSchedule>>, AppError> {
    let result = schedule_service::get_calendar_sync(&pool, &claims.uid).await?;
    ApiResponse::ok(result)
}

async fn check_conflicts(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CheckConflictsRequest>,
) -> Result<ApiResponse<Vec<ScheduleConflict>>, AppError> {
    let result = schedule_service::check_conflicts(&pool, &claims.uid, req).await?;
    ApiResponse::ok(result)
}

async fn extract_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<ExtractScheduleRequest>,
) -> Result<ApiResponse<ExtractScheduleResponse>, AppError> {
    let result = schedule_service::extract_schedule(&pool, &claims.uid, req).await?;
    ApiResponse::ok(result)
}

async fn create_recurring_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CreateRecurringScheduleRequest>,
) -> Result<ApiResponse<CreateRecurringScheduleResponse>, AppError> {
    let result =
        schedule_service::create_recurring_schedule(&pool, &claims.uid, req).await?;
    ApiResponse::created(result)
}

async fn get_recurring_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
) -> Result<ApiResponse<Vec<RecurringSchedule>>, AppError> {
    let result = schedule_service::get_recurring_schedules(&pool, &claims.uid).await?;
    ApiResponse::ok(result)
}

async fn update_recurring_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateRecurringScheduleRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    schedule_service::update_recurring_schedule(&pool, &claims.uid, id, req).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}

async fn delete_recurring_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    schedule_service::delete_recurring_schedule(&pool, &claims.uid, id).await?;
    ApiResponse::ok(serde_json::json!({"success": true}))
}
