use std::sync::Arc;

use axum::extract::{Path, Query, State};
use axum::http::HeaderMap;
use axum::routing::{delete, get, patch, post};
use axum::{Extension, Json, Router};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::middleware::auth::{Claims, FirebaseAuth};
use crate::models::live_activity::{
    LiveActivitySender, StartScheduleLiveActivityResponse, UpdateScheduleLiveActivityRequest,
    UpdateScheduleLiveActivityResponse, WidgetUpdateScheduleLiveActivityRequest,
};
use crate::models::notification::PushSender;
use crate::models::schedule::*;
use crate::response::ApiResponse;
use crate::services::{live_activity_service, schedule_service};

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
        .route("/{id}/respond", post(respond_schedule))
        .route("/{id}/live-activity/start", post(start_live_activity))
        .route("/{id}/live-activity/eta", post(update_live_activity_eta));

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
        .nest("/api/v1/groups/{group_id}/schedules", group_schedule_routes)
}

pub fn public_router() -> Router<PgPool> {
    Router::new().route(
        "/api/v1/live-activity/widget/eta",
        post(widget_update_live_activity_eta),
    )
}

async fn create_schedule(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    Json(req): Json<CreateScheduleRequest>,
) -> Result<ApiResponse<CreateScheduleResponse>, AppError> {
    let result = schedule_service::create_schedule_with_push_sender(
        &pool,
        push_sender.as_ref(),
        &claims.uid,
        req,
    )
    .await?;
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
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateScheduleRequest>,
) -> Result<ApiResponse<serde_json::Value>, AppError> {
    schedule_service::update_schedule_with_push_sender(
        &pool,
        push_sender.as_ref(),
        &claims.uid,
        id,
        req,
    )
    .await?;
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
    Extension(push_sender): Extension<Arc<dyn PushSender>>,
    Path(id): Path<Uuid>,
    Json(req): Json<RespondScheduleRequest>,
) -> Result<ApiResponse<RespondScheduleResponse>, AppError> {
    let result = schedule_service::respond_schedule_with_push_sender(
        &pool,
        push_sender.as_ref(),
        &claims.uid,
        id,
        req,
    )
    .await?;
    ApiResponse::ok(result)
}

async fn start_live_activity(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(live_activity_sender): Extension<Arc<dyn LiveActivitySender>>,
    Path(id): Path<Uuid>,
) -> Result<ApiResponse<StartScheduleLiveActivityResponse>, AppError> {
    let result = live_activity_service::start_schedule_live_activity(
        &pool,
        live_activity_sender.as_ref(),
        id,
        &claims.uid,
    )
    .await?;
    ApiResponse::ok(result)
}

async fn update_live_activity_eta(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Extension(live_activity_sender): Extension<Arc<dyn LiveActivitySender>>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateScheduleLiveActivityRequest>,
) -> Result<ApiResponse<UpdateScheduleLiveActivityResponse>, AppError> {
    let result = live_activity_service::update_schedule_live_activity(
        &pool,
        live_activity_sender.as_ref(),
        id,
        &claims.uid,
        req,
    )
    .await?;
    ApiResponse::ok(result)
}

async fn widget_update_live_activity_eta(
    State(pool): State<PgPool>,
    Extension(firebase_auth): Extension<FirebaseAuth>,
    Extension(live_activity_sender): Extension<Arc<dyn LiveActivitySender>>,
    headers: HeaderMap,
    Json(req): Json<WidgetUpdateScheduleLiveActivityRequest>,
) -> Result<ApiResponse<UpdateScheduleLiveActivityResponse>, AppError> {
    let user_id = headers
        .get("x-user-id")
        .and_then(|value| value.to_str().ok())
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| AppError::Unauthorized("X-User-Id header is required".to_string()))?;

    if let Some(auth_token) = headers
        .get("x-auth-token")
        .and_then(|value| value.to_str().ok())
        .filter(|value| !value.trim().is_empty())
    {
        let claims = firebase_auth.verify_token(auth_token).await?;
        if claims.uid != user_id {
            return Err(AppError::Unauthorized("Token uid mismatch".to_string()));
        }
    }

    let result = live_activity_service::update_schedule_live_activity_from_widget(
        &pool,
        live_activity_sender.as_ref(),
        req.schedule_id,
        user_id,
        UpdateScheduleLiveActivityRequest {
            channel_id: req.channel_id,
            participants: req.participants,
            tracking_duration_minutes: req.tracking_duration_minutes,
        },
    )
    .await?;
    ApiResponse::ok(result)
}

async fn get_group_schedules(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(group_id): Path<Uuid>,
    Query(query): Query<GroupScheduleQuery>,
) -> Result<ApiResponse<PaginatedScheduleResponse>, AppError> {
    let result = schedule_service::get_group_schedules(&pool, &claims.uid, group_id, query).await?;
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
    let result = schedule_service::create_recurring_schedule(&pool, &claims.uid, req).await?;
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
