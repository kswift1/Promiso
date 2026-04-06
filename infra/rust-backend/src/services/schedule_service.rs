use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::schedule::*;

// ============================================================
// 그룹/개인 일정 CRUD
// ============================================================

pub async fn create_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _req: CreateScheduleRequest,
) -> Result<CreateScheduleResponse, AppError> {
    todo!()
}

pub async fn get_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _schedule_id: Uuid,
) -> Result<ScheduleResponse, AppError> {
    todo!()
}

pub async fn update_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _schedule_id: Uuid,
    _req: UpdateScheduleRequest,
) -> Result<(), AppError> {
    todo!()
}

pub async fn delete_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _schedule_id: Uuid,
) -> Result<(), AppError> {
    todo!()
}

pub async fn respond_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _schedule_id: Uuid,
    _req: RespondScheduleRequest,
) -> Result<RespondScheduleResponse, AppError> {
    todo!()
}

// ============================================================
// 목록/조회
// ============================================================

pub async fn get_group_schedules(
    _pool: &PgPool,
    _user_id: &str,
    _group_id: Uuid,
    _query: GroupScheduleQuery,
) -> Result<PaginatedScheduleResponse, AppError> {
    todo!()
}

pub async fn get_home_schedules(
    _pool: &PgPool,
    _user_id: &str,
    _query: HomeQuery,
) -> Result<Vec<ScheduleResponse>, AppError> {
    todo!()
}

pub async fn get_calendar_schedules(
    _pool: &PgPool,
    _user_id: &str,
    _query: CalendarQuery,
) -> Result<CalendarResponse, AppError> {
    todo!()
}

pub async fn get_calendar_sync(
    _pool: &PgPool,
    _user_id: &str,
) -> Result<Vec<CalendarSyncSchedule>, AppError> {
    todo!()
}

pub async fn check_conflicts(
    _pool: &PgPool,
    _user_id: &str,
    _req: CheckConflictsRequest,
) -> Result<Vec<ScheduleConflict>, AppError> {
    todo!()
}

// ============================================================
// 반복일정
// ============================================================

pub async fn create_recurring_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _req: CreateRecurringScheduleRequest,
) -> Result<CreateRecurringScheduleResponse, AppError> {
    todo!()
}

pub async fn get_recurring_schedules(
    _pool: &PgPool,
    _user_id: &str,
) -> Result<Vec<RecurringSchedule>, AppError> {
    todo!()
}

pub async fn update_recurring_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _id: Uuid,
    _req: UpdateRecurringScheduleRequest,
) -> Result<(), AppError> {
    todo!()
}

pub async fn delete_recurring_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _id: Uuid,
) -> Result<(), AppError> {
    todo!()
}

// ============================================================
// AI 일정 추출
// ============================================================

pub async fn extract_schedule(
    _pool: &PgPool,
    _user_id: &str,
    _req: ExtractScheduleRequest,
) -> Result<ExtractScheduleResponse, AppError> {
    todo!()
}
