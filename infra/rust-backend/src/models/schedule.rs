use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ============================================================
// DB 열거형 (PostgreSQL 타입 매핑)
// ============================================================

#[derive(Debug, Clone, PartialEq, Eq, sqlx::Type, Serialize, Deserialize)]
#[sqlx(type_name = "schedule_type", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum ScheduleType {
    Group,
    Personal,
}

#[derive(Debug, Clone, PartialEq, Eq, sqlx::Type, Serialize, Deserialize)]
#[sqlx(type_name = "vote_status", rename_all = "lowercase")]
pub enum VoteStatus {
    Accepted,
    Declined,
}

#[derive(Debug, Clone, PartialEq, Eq, sqlx::Type, Serialize, Deserialize)]
#[sqlx(type_name = "recurrence_frequency", rename_all = "lowercase")]
pub enum RecurrenceFrequency {
    Daily,
    Weekly,
    Monthly,
}

// ============================================================
// DB 모델
// ============================================================

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Schedule {
    pub id: Uuid,
    pub schedule_type: ScheduleType,
    pub user_id: String,
    pub title: String,
    pub emoji: Option<String>,
    pub description: Option<String>,
    pub description_blocks: Option<serde_json::Value>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub location_name: Option<String>,
    pub location_address: Option<String>,
    pub location_latitude: Option<f64>,
    pub location_longitude: Option<f64>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    // 그룹일정 전용
    pub group_id: Option<Uuid>,
    pub minimum_participants: Option<i16>,
    pub is_confirmed: Option<bool>,
    pub vote_deadline: Option<DateTime<Utc>>,
    pub vote_live_activity_channel_id: Option<String>,
    pub vote_live_activity_started_at: Option<DateTime<Utc>>,
    pub vote_live_activity_finalized_at: Option<DateTime<Utc>>,
    pub vote_live_activity_ended_at: Option<DateTime<Utc>>,
    pub tracking_start_minutes_before: Option<i16>,
    pub image_urls: Option<Vec<String>>,
    pub live_activity_channel_id: Option<String>,
    pub live_activity_started_at: Option<DateTime<Utc>>,
    pub live_activity_nudge_sent_at: Option<DateTime<Utc>>,
    pub live_activity_ended_at: Option<DateTime<Utc>>,
    // 개인일정 전용
    pub reminder_minutes_before: Option<i16>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct ScheduleVote {
    pub schedule_id: Uuid,
    pub user_id: String,
    pub status: VoteStatus,
    pub responded_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct RecurringSchedule {
    pub id: Uuid,
    pub user_id: String,
    pub title: String,
    pub emoji: Option<String>,
    pub description: Option<String>,
    pub start_time_hour: i16,
    pub start_time_minute: i16,
    pub end_time_hour: Option<i16>,
    pub end_time_minute: Option<i16>,
    pub location_name: Option<String>,
    pub location_address: Option<String>,
    pub location_latitude: Option<f64>,
    pub location_longitude: Option<f64>,
    pub reminder_minutes_before: Option<i16>,
    pub frequency: RecurrenceFrequency,
    pub days_of_week: Option<Vec<i16>>,
    pub day_of_month: Option<i16>,
    pub series_start_date: NaiveDate,
    pub series_end_date: Option<NaiveDate>,
    pub excluded_dates: Option<Vec<NaiveDate>>,
    pub overrides: Option<serde_json::Value>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// ============================================================
// 요청 DTO
// ============================================================

#[derive(Debug, Deserialize)]
pub struct CreateScheduleRequest {
    pub schedule_type: ScheduleType,
    pub group_id: Option<Uuid>,
    pub title: String,
    pub emoji: Option<String>,
    pub description: Option<String>,
    pub description_blocks: Option<serde_json::Value>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub location: Option<LocationRequest>,
    pub minimum_participants: Option<i16>,
    pub tracking_start_minutes_before: Option<i16>,
    pub image_urls: Option<Vec<String>>,
    pub reminder_minutes_before: Option<i16>,
}

#[derive(Debug, Deserialize)]
pub struct LocationRequest {
    pub name: String,
    pub address: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateScheduleRequest {
    // Option<Option<T>> 패턴:
    //   None          -> 변경 없음 (JSON에서 필드 생략)
    //   Some(None)    -> 삭제 (JSON에서 "field": null)
    //   Some(Some(v)) -> 값 변경 (JSON에서 "field": "value")
    pub title: Option<String>,
    pub emoji: Option<Option<String>>,
    pub description: Option<Option<String>>,
    pub description_blocks: Option<Option<serde_json::Value>>,
    pub start_at: Option<DateTime<Utc>>,
    pub end_at: Option<Option<DateTime<Utc>>>,
    pub location: Option<Option<LocationRequest>>,
    pub minimum_participants: Option<i16>,
    pub tracking_start_minutes_before: Option<Option<i16>>,
    pub image_urls: Option<Option<Vec<String>>>,
    pub reminder_minutes_before: Option<Option<i16>>,
}

#[derive(Debug, Deserialize)]
pub struct RespondScheduleRequest {
    pub status: String, // "accepted" | "declined" | "pending"
}

#[derive(Debug, Deserialize)]
pub struct CheckConflictsRequest {
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub min_gap_minutes: Option<i32>,
    pub exclude_ids: Option<Vec<Uuid>>,
    pub timezone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateRecurringScheduleRequest {
    pub title: String,
    pub emoji: Option<String>,
    pub description: Option<String>,
    pub start_time: TimeComponents,
    pub end_time: Option<TimeComponents>,
    pub location: Option<LocationRequest>,
    pub reminder_minutes_before: Option<i16>,
    pub frequency: RecurrenceFrequency,
    pub days_of_week: Option<Vec<i16>>,
    pub day_of_month: Option<i16>,
    pub series_start_date: NaiveDate,
    pub series_end_date: Option<NaiveDate>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TimeComponents {
    pub hour: i16,
    pub minute: i16,
}

#[derive(Debug, Deserialize)]
pub struct UpdateRecurringScheduleRequest {
    pub title: Option<String>,
    pub emoji: Option<Option<String>>,
    pub description: Option<Option<String>>,
    pub start_time: Option<TimeComponents>,
    pub end_time: Option<Option<TimeComponents>>,
    pub location: Option<Option<LocationRequest>>,
    pub reminder_minutes_before: Option<Option<i16>>,
    pub frequency: Option<RecurrenceFrequency>,
    pub days_of_week: Option<Option<Vec<i16>>>,
    pub day_of_month: Option<Option<i16>>,
    pub series_start_date: Option<NaiveDate>,
    pub series_end_date: Option<Option<NaiveDate>>,
    pub excluded_dates: Option<Vec<NaiveDate>>,
    pub overrides: Option<serde_json::Value>,
}

// 쿼리 파라미터
#[derive(Debug, Deserialize)]
pub struct GroupScheduleQuery {
    pub status: Option<String>, // "active" | "past"
    pub limit: Option<i64>,
    pub cursor: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CalendarQuery {
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub accepted_only: Option<bool>,
    pub timezone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HomeQuery {
    pub limit: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct PersonalPastQuery {
    pub limit: Option<i64>,
    pub cursor: Option<DateTime<Utc>>,
}

// ============================================================
// 응답 DTO
// ============================================================

#[derive(Debug, Serialize)]
pub struct CreateScheduleResponse {
    pub schedule_id: Uuid,
    pub title: String,
    pub group_id: Option<Uuid>,
    pub start_at: DateTime<Utc>,
    pub is_confirmed: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct ScheduleResponse {
    pub id: Uuid,
    pub schedule_type: ScheduleType,
    pub user_id: String,
    pub title: String,
    pub emoji: Option<String>,
    pub description: Option<String>,
    pub description_blocks: Option<serde_json::Value>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub location: Option<LocationResponse>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    // 그룹일정 전용
    pub group_id: Option<Uuid>,
    pub host_id: Option<String>,
    pub minimum_participants: Option<i16>,
    pub is_confirmed: Option<bool>,
    pub vote_deadline: Option<DateTime<Utc>>,
    pub tracking_start_minutes_before: Option<i16>,
    pub image_urls: Option<Vec<String>>,
    pub votes: Option<VotesResponse>,
    // 개인일정 전용
    pub reminder_minutes_before: Option<i16>,
}

#[derive(Debug, Serialize)]
pub struct LocationResponse {
    pub name: String,
    pub address: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct VotesResponse {
    pub accepted: Vec<String>,
    pub declined: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct RespondScheduleResponse {
    pub schedule_id: Uuid,
    pub status: String,
    pub is_confirmed: bool,
    pub confirmed_schedule: Option<CalendarSyncSchedule>,
}

#[derive(Debug, Serialize)]
pub struct CalendarSyncSchedule {
    pub id: Uuid,
    pub title: String,
    pub emoji: Option<String>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub location: Option<String>,
    pub group_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct ScheduleConflict {
    pub id: String,
    pub source: String,
    pub severity: String,
    pub title: String,
    pub emoji: Option<String>,
    pub start_at: DateTime<Utc>,
    pub end_at: Option<DateTime<Utc>>,
    pub overlap_minutes: i64,
    pub gap_minutes: i64,
}

#[derive(Debug, Serialize)]
pub struct PaginatedScheduleResponse {
    pub data: Vec<ScheduleResponse>,
    pub cursor: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct CalendarResponse {
    pub schedules: Vec<ScheduleResponse>,
    pub recurring_instances: Vec<RecurringInstance>,
}

#[derive(Debug, Serialize)]
pub struct RecurringInstance {
    pub recurring_schedule_id: Uuid,
    pub title: String,
    pub emoji: Option<String>,
    pub date: NaiveDate,
    pub start_time: TimeComponents,
    pub end_time: Option<TimeComponents>,
    pub location: Option<LocationResponse>,
}

#[derive(Debug, Serialize)]
pub struct CreateRecurringScheduleResponse {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct ExtractScheduleRequest {
    pub text: Option<String>,
    pub image_base64: Option<String>,
    pub timezone: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ExtractScheduleResponse {
    pub title: Option<String>,
    pub emoji: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub location: Option<String>,
    pub address: Option<String>,
    pub description: Option<String>,
    pub description_blocks: Option<serde_json::Value>,
}
