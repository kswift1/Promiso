use std::sync::Arc;

use chrono::{Duration, Utc};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::{
    LiveActivityJob, LiveActivityJobPayload, LiveActivityJobStatus, LiveActivityJobType,
    LiveActivityParticipant, LiveActivitySender, StartScheduleLiveActivityResponse,
    UpdateScheduleLiveActivityRequest, UpdateScheduleLiveActivityResponse,
};
use crate::models::notification::{NotificationType, PushSender, SendPushRequest};
use crate::models::schedule::{Schedule, ScheduleType};
use crate::services::notification_service;

const DEFAULT_TRACKING_DURATION_MINUTES: i16 = 30;
const DEFAULT_END_MINUTES_AFTER_START: i64 = 30;
const JOB_BATCH_SIZE: i64 = 10;
const JOB_LOCK_SECONDS: i64 = 60;
const JOB_MAX_ATTEMPTS: i32 = 3;
const WORKER_POLL_INTERVAL_SECONDS: u64 = 5;

#[derive(Debug, Clone, sqlx::FromRow)]
struct GroupSummary {
    name: String,
    image_url: Option<String>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct AcceptedParticipantRow {
    id: String,
    nickname: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct PushToStartTarget {
    user_id: String,
    push_to_start_token: String,
}

pub async fn sync_schedule_jobs(pool: &PgPool, schedule_id: Uuid) -> Result<(), AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;

    if schedule.schedule_type != ScheduleType::Group {
        return Ok(());
    }

    let accepted_participants = load_accepted_participants(pool, schedule_id).await?;
    let accepted_count = accepted_participants.len() as i64;
    let minimum_participants = schedule.minimum_participants.unwrap_or(2) as i64;
    let tracking_minutes = schedule.tracking_start_minutes_before;
    let now = Utc::now();
    let already_started =
        schedule.live_activity_started_at.is_some() && schedule.live_activity_ended_at.is_none();
    let is_confirmed = accepted_count >= minimum_participants;

    if already_started {
        return Ok(());
    }

    if !is_confirmed || tracking_minutes.is_none() || schedule.start_at <= now {
        cancel_pending_jobs(
            pool,
            schedule_id,
            &[
                LiveActivityJobType::Start,
                LiveActivityJobType::End,
                LiveActivityJobType::Nudge,
            ],
        )
        .await?;

        sqlx::query(
            "UPDATE schedules SET live_activity_channel_id = NULL, \
             live_activity_started_at = NULL, live_activity_nudge_sent_at = NULL, \
             live_activity_ended_at = NULL WHERE id = $1",
        )
        .bind(schedule_id)
        .execute(pool)
        .await?;

        return Ok(());
    }

    let scheduled_at = schedule.start_at - Duration::minutes(tracking_minutes.unwrap() as i64);
    replace_pending_job(
        pool,
        schedule_id,
        LiveActivityJobType::Start,
        scheduled_at,
        None,
    )
    .await?;
    cancel_pending_jobs(
        pool,
        schedule_id,
        &[LiveActivityJobType::End, LiveActivityJobType::Nudge],
    )
    .await?;

    Ok(())
}

pub async fn start_schedule_live_activity(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<StartScheduleLiveActivityResponse, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.user_id != user_id {
        return Err(AppError::Forbidden(
            "호스트만 Live Activity를 시작할 수 있습니다".to_string(),
        ));
    }

    execute_start_job(pool, sender, &schedule).await
}

pub async fn update_schedule_live_activity(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
    user_id: &str,
    req: UpdateScheduleLiveActivityRequest,
) -> Result<UpdateScheduleLiveActivityResponse, AppError> {
    update_schedule_live_activity_internal(pool, sender, schedule_id, user_id, req).await
}

pub async fn update_schedule_live_activity_from_widget(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
    user_id: &str,
    req: UpdateScheduleLiveActivityRequest,
) -> Result<UpdateScheduleLiveActivityResponse, AppError> {
    update_schedule_live_activity_internal(pool, sender, schedule_id, user_id, req).await
}

pub fn spawn_worker(
    pool: PgPool,
    live_activity_sender: Arc<dyn LiveActivitySender>,
    push_sender: Arc<dyn PushSender>,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            if let Err(error) =
                process_due_jobs(&pool, live_activity_sender.as_ref(), push_sender.as_ref()).await
            {
                tracing::error!("Failed to process due live activity jobs: {error}");
            }

            tokio::time::sleep(tokio::time::Duration::from_secs(
                WORKER_POLL_INTERVAL_SECONDS,
            ))
            .await;
        }
    })
}

pub async fn process_due_jobs(
    pool: &PgPool,
    live_activity_sender: &dyn LiveActivitySender,
    push_sender: &dyn PushSender,
) -> Result<(), AppError> {
    let jobs = claim_due_jobs(pool).await?;

    for job in jobs {
        let result = match job.job_type {
            LiveActivityJobType::Start => process_start_job(pool, live_activity_sender, &job).await,
            LiveActivityJobType::End => process_end_job(pool, live_activity_sender, &job).await,
            LiveActivityJobType::Nudge => process_nudge_job(pool, push_sender, &job).await,
        };

        match result {
            Ok(()) => mark_job_succeeded(pool, job.id).await?,
            Err(error) => handle_job_failure(pool, &job, &error.to_string()).await?,
        }
    }

    Ok(())
}

async fn update_schedule_live_activity_internal(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
    user_id: &str,
    req: UpdateScheduleLiveActivityRequest,
) -> Result<UpdateScheduleLiveActivityResponse, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;
    ensure_accepted_participant(pool, schedule_id, user_id).await?;

    if req.channel_id.trim().is_empty() {
        return Err(AppError::BadRequest("channel_id는 필수입니다".to_string()));
    }

    if req.participants.is_empty() {
        return Err(AppError::BadRequest(
            "participants는 비어 있을 수 없습니다".to_string(),
        ));
    }

    if !req
        .participants
        .iter()
        .any(|participant| participant.id == user_id)
    {
        return Err(AppError::Forbidden(
            "본인의 ETA만 갱신할 수 있습니다".to_string(),
        ));
    }

    if let Some(channel_id) = &schedule.live_activity_channel_id {
        if channel_id != &req.channel_id {
            return Err(AppError::Conflict(
                "활성 Live Activity 채널이 일치하지 않습니다".to_string(),
            ));
        }
    }

    let accepted_ids = load_accepted_participants(pool, schedule_id)
        .await?
        .into_iter()
        .map(|participant| participant.id)
        .collect::<std::collections::HashSet<_>>();

    if req
        .participants
        .iter()
        .any(|participant| !accepted_ids.contains(&participant.id))
    {
        return Err(AppError::Forbidden(
            "accepted 참가자만 ETA를 갱신할 수 있습니다".to_string(),
        ));
    }

    let tracking_duration_minutes = req
        .tracking_duration_minutes
        .unwrap_or(DEFAULT_TRACKING_DURATION_MINUTES);
    let arrived_participants = req
        .participants
        .iter()
        .filter(|participant| participant.estimated_arrival_minutes == Some(0))
        .collect::<Vec<_>>();
    let arrived_count = arrived_participants.len();
    let total_count = req.participants.len();
    let current_user_just_arrived = arrived_participants
        .iter()
        .any(|participant| participant.id == user_id);

    let alert = if arrived_count == 1 && total_count > 1 && current_user_just_arrived {
        Some(json!({
            "title": "🎉 첫 도착!",
            "body": "가장 먼저 도착했어요!"
        }))
    } else if arrived_count == total_count && total_count > 1 {
        Some(json!({
            "title": "✅ 모두 도착!",
            "body": "모든 멤버들이 도착했어요! 잠시 후 종료됩니다"
        }))
    } else {
        None
    };

    let payload = build_update_payload(tracking_duration_minutes, &req.participants, alert.clone());
    sender.send_broadcast(&req.channel_id, &payload).await?;

    if schedule.live_activity_channel_id.is_none() {
        sqlx::query(
            "UPDATE schedules SET live_activity_channel_id = $1, updated_at = NOW() WHERE id = $2",
        )
        .bind(&req.channel_id)
        .bind(schedule_id)
        .execute(pool)
        .await?;
    }

    if arrived_count == total_count && total_count > 1 {
        let delay_minutes = match current_environment() {
            RuntimeEnvironment::Dev => 1,
            RuntimeEnvironment::Stage => 3,
            RuntimeEnvironment::Release => 5,
        };

        replace_pending_job(
            pool,
            schedule_id,
            LiveActivityJobType::End,
            Utc::now() + Duration::minutes(delay_minutes),
            Some(LiveActivityJobPayload {
                channel_id: Some(req.channel_id.clone()),
            }),
        )
        .await?;
    } else {
        schedule_default_end_job(pool, schedule_id, schedule.start_at, &req.channel_id).await?;
    }

    Ok(UpdateScheduleLiveActivityResponse {
        success: true,
        success_count: 1,
        failure_count: 0,
    })
}

async fn process_start_job(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    job: &LiveActivityJob,
) -> Result<(), AppError> {
    let schedule = load_schedule(pool, job.schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.live_activity_started_at.is_some() && schedule.live_activity_ended_at.is_none() {
        return Ok(());
    }

    let response = execute_start_job(pool, sender, &schedule).await?;
    if response.success_count == 0 {
        return Err(AppError::Internal(
            "No successful Live Activity push-to-start delivery".to_string(),
        ));
    }

    Ok(())
}

async fn process_end_job(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    job: &LiveActivityJob,
) -> Result<(), AppError> {
    let schedule = load_schedule(pool, job.schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.live_activity_ended_at.is_some() {
        return Ok(());
    }

    let payload: Option<LiveActivityJobPayload> = job
        .payload
        .as_ref()
        .map(|payload| serde_json::from_value(payload.clone()))
        .transpose()
        .map_err(|error| {
            AppError::Internal(format!("Invalid live activity end job payload: {error}"))
        })?;

    let channel_id = payload
        .and_then(|payload| payload.channel_id)
        .or_else(|| schedule.live_activity_channel_id.clone())
        .ok_or_else(|| AppError::BadRequest("Live Activity channel_id가 없습니다".to_string()))?;

    let tracking_duration_minutes = schedule
        .tracking_start_minutes_before
        .unwrap_or(DEFAULT_TRACKING_DURATION_MINUTES);
    let payload = build_end_payload(tracking_duration_minutes);

    sender.send_broadcast(&channel_id, &payload).await?;

    sqlx::query(
        "UPDATE schedules SET live_activity_ended_at = NOW(), updated_at = NOW() WHERE id = $1",
    )
    .bind(schedule.id)
    .execute(pool)
    .await?;

    Ok(())
}

async fn process_nudge_job(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    job: &LiveActivityJob,
) -> Result<(), AppError> {
    let schedule = load_schedule(pool, job.schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.live_activity_nudge_sent_at.is_some() || Utc::now() >= schedule.start_at {
        return Ok(());
    }

    let accepted_participants = load_accepted_participants(pool, schedule.id).await?;
    if accepted_participants.is_empty() {
        return Ok(());
    }

    let remaining_minutes = ((schedule.start_at - Utc::now()).num_seconds() + 59) / 60;
    let safe_title = schedule.title.chars().take(100).collect::<String>();
    notification_service::send_push_internal(
        pool,
        push_sender,
        SendPushRequest {
            user_ids: accepted_participants
                .into_iter()
                .map(|participant| participant.id)
                .collect(),
            notification_type: NotificationType::LocationSharingReminder,
            title: format!("⏰ {safe_title} {}분 전!", remaining_minutes.max(0)),
            body: "잘 오고 계신가요? 👋 잠금화면 또는 앱에서 실시간 도착 예정시간을 공유해주세요!"
                .to_string(),
            schedule_id: Some(schedule.id),
            group_id: schedule.group_id,
            related_user_id: None,
            data: None,
        },
    )
    .await?;

    sqlx::query(
        "UPDATE schedules SET live_activity_nudge_sent_at = NOW(), updated_at = NOW() WHERE id = $1",
    )
    .bind(schedule.id)
    .execute(pool)
    .await?;

    Ok(())
}

async fn execute_start_job(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule: &Schedule,
) -> Result<StartScheduleLiveActivityResponse, AppError> {
    ensure_group_schedule(schedule)?;

    let group_id = schedule
        .group_id
        .ok_or_else(|| AppError::Internal("그룹 일정에 group_id가 없습니다".to_string()))?;
    let accepted_participants = load_accepted_participants(pool, schedule.id).await?;
    let accepted_count = accepted_participants.len() as i64;
    let minimum_participants = schedule.minimum_participants.unwrap_or(2) as i64;

    if accepted_count < minimum_participants {
        return Err(AppError::PreconditionFailed(
            "확정된 일정만 Live Activity를 시작할 수 있습니다".to_string(),
        ));
    }

    let tracking_duration_minutes = schedule
        .tracking_start_minutes_before
        .unwrap_or(DEFAULT_TRACKING_DURATION_MINUTES);
    let targets = load_push_to_start_targets(
        pool,
        &accepted_participants
            .iter()
            .map(|participant| participant.id.clone())
            .collect::<Vec<_>>(),
    )
    .await?;

    if targets.is_empty() {
        return Err(AppError::PreconditionFailed(
            "Push to Start 토큰이 등록된 디바이스가 없습니다".to_string(),
        ));
    }

    let group =
        sqlx::query_as::<_, GroupSummary>("SELECT name, image_url FROM groups WHERE id = $1")
            .bind(group_id)
            .fetch_optional(pool)
            .await?
            .unwrap_or(GroupSummary {
                name: String::new(),
                image_url: None,
            });

    let host_name = accepted_participants
        .iter()
        .find(|participant| participant.id == schedule.user_id)
        .map(|participant| participant.name.clone())
        .unwrap_or_else(|| "호스트".to_string());

    let channel_id = sender.create_channel().await?;
    let participants = accepted_participants
        .iter()
        .map(|participant| LiveActivityParticipant {
            id: participant.id.clone(),
            name: participant.name.clone(),
            estimated_arrival_minutes: None,
        })
        .collect::<Vec<_>>();

    let emoji = schedule.emoji.clone().unwrap_or_else(|| "📅".to_string());
    let mut success_count = 0;
    let mut failure_count = 0;

    for target in &targets {
        let payload = build_start_payload(
            schedule,
            target.user_id.as_str(),
            &channel_id,
            tracking_duration_minutes,
            &participants,
            &emoji,
            &host_name,
            group.name.as_str(),
            group.image_url.as_deref(),
        );

        match sender
            .send_push_to_start(&target.push_to_start_token, &payload)
            .await
        {
            Ok(()) => success_count += 1,
            Err(error) => {
                failure_count += 1;
                tracing::error!(
                    "Failed to send Live Activity push-to-start for schedule {} user {}: {}",
                    schedule.id,
                    target.user_id,
                    error
                );
            }
        }
    }

    if success_count == 0 {
        return Err(AppError::Internal(
            "Push to Start delivery failed for all devices".to_string(),
        ));
    }

    sqlx::query(
        "UPDATE schedules SET live_activity_channel_id = $1, live_activity_started_at = NOW(), \
         live_activity_nudge_sent_at = NULL, live_activity_ended_at = NULL, updated_at = NOW() \
         WHERE id = $2",
    )
    .bind(&channel_id)
    .bind(schedule.id)
    .execute(pool)
    .await?;

    cancel_pending_jobs(pool, schedule.id, &[LiveActivityJobType::Start]).await?;

    schedule_default_end_job(pool, schedule.id, schedule.start_at, &channel_id).await?;

    replace_pending_job(
        pool,
        schedule.id,
        LiveActivityJobType::Nudge,
        Utc::now() + Duration::minutes((tracking_duration_minutes / 2) as i64),
        None,
    )
    .await?;

    Ok(StartScheduleLiveActivityResponse {
        success: failure_count == 0,
        success_count,
        failure_count,
        channel_id: Some(channel_id),
    })
}

async fn claim_due_jobs(pool: &PgPool) -> Result<Vec<LiveActivityJob>, AppError> {
    sqlx::query_as::<_, LiveActivityJob>(
        "WITH due_jobs AS ( \
           SELECT id \
           FROM live_activity_jobs \
           WHERE status = 'pending'::live_activity_job_status \
             AND scheduled_at <= NOW() \
             AND (locked_until IS NULL OR locked_until < NOW()) \
           ORDER BY scheduled_at \
           LIMIT $1 \
           FOR UPDATE SKIP LOCKED \
         ) \
         UPDATE live_activity_jobs jobs \
         SET locked_until = NOW() + ($2::TEXT || ' seconds')::INTERVAL, \
             attempts = attempts + 1, \
             updated_at = NOW() \
         FROM due_jobs \
         WHERE jobs.id = due_jobs.id \
         RETURNING jobs.*",
    )
    .bind(JOB_BATCH_SIZE)
    .bind(JOB_LOCK_SECONDS)
    .fetch_all(pool)
    .await
    .map_err(Into::into)
}

async fn schedule_default_end_job(
    pool: &PgPool,
    schedule_id: Uuid,
    start_at: chrono::DateTime<Utc>,
    channel_id: &str,
) -> Result<(), AppError> {
    replace_pending_job(
        pool,
        schedule_id,
        LiveActivityJobType::End,
        start_at + Duration::minutes(DEFAULT_END_MINUTES_AFTER_START),
        Some(LiveActivityJobPayload {
            channel_id: Some(channel_id.to_string()),
        }),
    )
    .await
}

async fn mark_job_succeeded(pool: &PgPool, job_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE live_activity_jobs \
         SET status = 'succeeded'::live_activity_job_status, locked_until = NULL, updated_at = NOW() \
         WHERE id = $1",
    )
    .bind(job_id)
    .execute(pool)
    .await?;
    Ok(())
}

async fn handle_job_failure(
    pool: &PgPool,
    job: &LiveActivityJob,
    error: &str,
) -> Result<(), AppError> {
    let next_status = if job.attempts >= JOB_MAX_ATTEMPTS {
        LiveActivityJobStatus::Failed
    } else {
        LiveActivityJobStatus::Pending
    };

    sqlx::query(
        "UPDATE live_activity_jobs \
         SET status = $2, locked_until = NULL, last_error = $3, updated_at = NOW() \
         WHERE id = $1",
    )
    .bind(job.id)
    .bind(next_status)
    .bind(error)
    .execute(pool)
    .await?;

    Ok(())
}

async fn replace_pending_job(
    pool: &PgPool,
    schedule_id: Uuid,
    job_type: LiveActivityJobType,
    scheduled_at: chrono::DateTime<Utc>,
    payload: Option<LiveActivityJobPayload>,
) -> Result<(), AppError> {
    cancel_pending_jobs(pool, schedule_id, std::slice::from_ref(&job_type)).await?;

    sqlx::query(
        "INSERT INTO live_activity_jobs (schedule_id, job_type, scheduled_at, payload) \
         VALUES ($1, $2, $3, $4)",
    )
    .bind(schedule_id)
    .bind(job_type)
    .bind(scheduled_at)
    .bind(
        payload
            .map(|payload| serde_json::to_value(payload))
            .transpose()
            .map_err(|error| {
                AppError::Internal(format!(
                    "Failed to encode live activity job payload: {error}"
                ))
            })?,
    )
    .execute(pool)
    .await?;

    Ok(())
}

async fn cancel_pending_jobs(
    pool: &PgPool,
    schedule_id: Uuid,
    job_types: &[LiveActivityJobType],
) -> Result<(), AppError> {
    if job_types.is_empty() {
        return Ok(());
    }

    sqlx::query(
        "UPDATE live_activity_jobs \
         SET status = 'cancelled'::live_activity_job_status, locked_until = NULL, updated_at = NOW() \
         WHERE schedule_id = $1 \
           AND job_type = ANY($2) \
           AND status = 'pending'::live_activity_job_status",
    )
    .bind(schedule_id)
    .bind(job_types)
    .execute(pool)
    .await?;

    Ok(())
}

async fn load_schedule(pool: &PgPool, schedule_id: Uuid) -> Result<Schedule, AppError> {
    sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))
}

async fn ensure_accepted_participant(
    pool: &PgPool,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<(), AppError> {
    let accepted = sqlx::query_scalar::<_, i32>(
        "SELECT 1 \
         FROM schedule_votes \
         WHERE schedule_id = $1 \
           AND user_id = $2 \
           AND status = 'accepted'::vote_status",
    )
    .bind(schedule_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    if accepted.is_none() {
        return Err(AppError::Forbidden(
            "accepted 참가자만 Live Activity를 사용할 수 있습니다".to_string(),
        ));
    }

    Ok(())
}

async fn load_accepted_participants(
    pool: &PgPool,
    schedule_id: Uuid,
) -> Result<Vec<LiveActivityParticipant>, AppError> {
    let rows = sqlx::query_as::<_, AcceptedParticipantRow>(
        "SELECT u.id, u.nickname \
         FROM schedule_votes sv \
         JOIN users u ON u.id = sv.user_id \
         WHERE sv.schedule_id = $1 \
           AND sv.status = 'accepted'::vote_status \
         ORDER BY sv.responded_at, u.id",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|row| LiveActivityParticipant {
            id: row.id,
            name: row.nickname,
            estimated_arrival_minutes: None,
        })
        .collect())
}

async fn load_push_to_start_targets(
    pool: &PgPool,
    user_ids: &[String],
) -> Result<Vec<PushToStartTarget>, AppError> {
    if user_ids.is_empty() {
        return Ok(Vec::new());
    }

    sqlx::query_as::<_, PushToStartTarget>(
        "SELECT d.user_id, la.push_to_start_token \
         FROM live_activity_endpoints la \
         JOIN devices d ON d.id = la.device_id \
         WHERE d.user_id = ANY($1) \
           AND la.push_to_start_token IS NOT NULL",
    )
    .bind(user_ids)
    .fetch_all(pool)
    .await
    .map_err(Into::into)
}

fn ensure_group_schedule(schedule: &Schedule) -> Result<(), AppError> {
    if schedule.schedule_type != ScheduleType::Group {
        return Err(AppError::BadRequest(
            "그룹 일정만 Live Activity를 사용할 수 있습니다".to_string(),
        ));
    }
    Ok(())
}

fn build_start_payload(
    schedule: &Schedule,
    current_user_id: &str,
    channel_id: &str,
    tracking_duration_minutes: i16,
    participants: &[LiveActivityParticipant],
    emoji: &str,
    host_name: &str,
    group_name: &str,
    group_image_url: Option<&str>,
) -> serde_json::Value {
    json!({
        "aps": {
            "timestamp": Utc::now().timestamp(),
            "event": "start",
            "input-push-channel": channel_id,
            "attributes-type": "ScheduleActivityAttributes",
            "attributes": {
                "trackingDurationMinutes": tracking_duration_minutes,
                "scheduleId": schedule.id.to_string(),
                "currentUserId": current_user_id,
                "emoji": emoji,
                "title": schedule.title,
                "location": schedule.location_name,
                "latitude": schedule.location_latitude,
                "longitude": schedule.location_longitude,
                "scheduledTime": schedule.start_at.timestamp() as f64,
                "hostId": schedule.user_id,
                "hostName": host_name,
                "channelId": channel_id,
                "groupName": if group_name.is_empty() { None::<String> } else { Some(group_name.to_string()) },
                "groupImageUrl": group_image_url,
            },
            "content-state": {
                "trackingDurationMinutes": tracking_duration_minutes,
                "participants": participants,
            },
            "alert": {
                "title": format!("{emoji} {}", schedule.title),
                "body": "실시간 공유가 시작되었습니다"
            }
        }
    })
}

fn build_update_payload(
    tracking_duration_minutes: i16,
    participants: &[LiveActivityParticipant],
    alert: Option<serde_json::Value>,
) -> serde_json::Value {
    let mut payload = json!({
        "aps": {
            "timestamp": Utc::now().timestamp(),
            "event": "update",
            "content-state": {
                "trackingDurationMinutes": tracking_duration_minutes,
                "participants": participants,
            }
        }
    });

    if let Some(alert) = alert {
        payload["aps"]["alert"] = alert;
    }

    payload
}

fn build_end_payload(tracking_duration_minutes: i16) -> serde_json::Value {
    json!({
        "aps": {
            "timestamp": Utc::now().timestamp(),
            "event": "end",
            "dismissal-date": Utc::now().timestamp() - 60,
            "content-state": {
                "trackingDurationMinutes": tracking_duration_minutes,
                "participants": [],
            }
        }
    })
}

#[derive(Debug, Clone, Copy)]
enum RuntimeEnvironment {
    Dev,
    Stage,
    Release,
}

fn current_environment() -> RuntimeEnvironment {
    let project_id = std::env::var("FIREBASE_PROJECT_ID").unwrap_or_default();
    if project_id.contains("-dev") {
        RuntimeEnvironment::Dev
    } else if project_id.contains("-stage") {
        RuntimeEnvironment::Stage
    } else {
        RuntimeEnvironment::Release
    }
}
