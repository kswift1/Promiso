use chrono::{Duration, Utc};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::{
    LiveActivitySender, StartScheduleLiveActivityResponse, UpdateVoteLiveActivityResponse,
    VoteLiveActivityContentState, VoteLiveActivityMember,
};
use crate::models::notification::{PushSender, VoteInfo};
use crate::models::schedule::{Schedule, ScheduleType};
use crate::services::live_activity_service::LiveActivityJobScheduler;
use crate::services::{live_activity_service, notification_service};

const DEFAULT_VOTE_DEADLINE_MINUTES_BEFORE: i16 = 30;
const MAX_VOTE_WINDOW_HOURS: i64 = 8;

#[derive(Debug, Clone, sqlx::FromRow)]
struct GroupMemberRow {
    id: String,
    nickname: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct ScheduleVoteRow {
    user_id: String,
    nickname: String,
    status: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct PushToStartTarget {
    user_id: String,
    push_to_start_token: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct GroupSummary {
    name: String,
}

pub async fn start_vote_live_activity(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    push_sender: Option<&dyn PushSender>,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<StartScheduleLiveActivityResponse, AppError> {
    start_vote_live_activity_internal(pool, sender, push_sender, None, schedule_id, user_id).await
}

pub async fn start_vote_live_activity_with_scheduler(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    push_sender: Option<&dyn PushSender>,
    live_activity_job_scheduler: &dyn LiveActivityJobScheduler,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<StartScheduleLiveActivityResponse, AppError> {
    start_vote_live_activity_internal(
        pool,
        sender,
        push_sender,
        Some(live_activity_job_scheduler),
        schedule_id,
        user_id,
    )
    .await
}

async fn start_vote_live_activity_internal(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    push_sender: Option<&dyn PushSender>,
    live_activity_job_scheduler: Option<&dyn LiveActivityJobScheduler>,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<StartScheduleLiveActivityResponse, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.user_id != user_id {
        return Err(AppError::Forbidden(
            "호스트만 투표 LiveActivity를 시작할 수 있습니다".to_string(),
        ));
    }

    if schedule.start_at <= Utc::now() {
        return Err(AppError::PreconditionFailed(
            "약속 시간이 이미 지났습니다".to_string(),
        ));
    }

    if schedule.vote_live_activity_channel_id.is_some()
        && schedule.vote_live_activity_ended_at.is_none()
    {
        return Err(AppError::Conflict("이미 투표가 진행 중입니다".to_string()));
    }

    let old_votes = load_vote_infos(pool, schedule.id).await?;

    let vote_deadline = compute_vote_deadline(&schedule)?;
    let group_id = schedule
        .group_id
        .ok_or_else(|| AppError::Internal("그룹 일정에 group_id가 없습니다".to_string()))?;
    let group_members = load_group_members(pool, group_id).await?;
    let total_member_count = group_members.len() as i32;
    let host_name = group_members
        .iter()
        .find(|member| member.id == schedule.user_id)
        .map(|member| member.nickname.clone())
        .unwrap_or_else(|| "호스트".to_string());

    let content_state = load_vote_start_content_state(pool, &schedule, host_name.as_str()).await?;
    let member_ids = group_members
        .iter()
        .map(|member| member.id.clone())
        .collect::<Vec<_>>();
    let targets = load_push_to_start_targets(pool, &member_ids).await?;

    if targets.is_empty() {
        return Ok(StartScheduleLiveActivityResponse {
            success: true,
            success_count: 0,
            failure_count: total_member_count,
            channel_id: None,
        });
    }

    let channel_id = sender.create_channel().await?;
    let group = sqlx::query_as::<_, GroupSummary>("SELECT name FROM groups WHERE id = $1")
        .bind(group_id)
        .fetch_optional(pool)
        .await?
        .unwrap_or(GroupSummary {
            name: String::new(),
        });

    let emoji = schedule.emoji.clone().unwrap_or_else(|| "📅".to_string());
    let mut success_count = 0;
    let mut failure_count = 0;

    for target in &targets {
        let payload = build_vote_start_payload(
            &schedule,
            target.user_id.as_str(),
            &channel_id,
            &emoji,
            &host_name,
            group.name.as_str(),
            total_member_count,
            vote_deadline.timestamp(),
            &content_state,
        );

        match sender
            .send_push_to_start(&target.push_to_start_token, &payload)
            .await
        {
            Ok(()) => success_count += 1,
            Err(error) => {
                failure_count += 1;
                tracing::error!(
                    "Failed to send vote Live Activity push-to-start for schedule {} user {}: {}",
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

    persist_vote_live_activity_start(pool, &schedule, &channel_id).await?;

    let new_votes = load_vote_infos(pool, schedule.id).await?;
    if let Some(push_sender) = push_sender {
        if let Err(error) = notification_service::notify_schedule_votes_updated(
            pool,
            push_sender,
            schedule.id,
            &old_votes,
            &new_votes,
        )
        .await
        {
            tracing::error!(
                "Failed to notify schedule vote update after vote live activity start {}: {}",
                schedule.id,
                error
            );
        }
    }

    if let Some(scheduler) = live_activity_job_scheduler {
        live_activity_service::sync_schedule_jobs_with_scheduler(pool, scheduler, schedule.id)
            .await?;
    } else if let Err(error) = live_activity_service::sync_schedule_jobs(pool, schedule.id).await {
        tracing::error!(
            "Failed to sync live activity jobs after vote live activity start {}: {}",
            schedule.id,
            error
        );
    }

    Ok(StartScheduleLiveActivityResponse {
        success: failure_count == 0,
        success_count,
        failure_count,
        channel_id: Some(channel_id),
    })
}

pub async fn broadcast_vote_state_if_active(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
) -> Result<Option<UpdateVoteLiveActivityResponse>, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    let channel_id = match active_vote_channel(&schedule) {
        Some(channel_id) => channel_id,
        None => return Ok(None),
    };

    let content_state = load_vote_content_state(
        pool,
        &schedule,
        schedule.vote_live_activity_finalized_at.is_some(),
    )
    .await?;
    let is_finalized = content_state.is_finalized;
    let payload = build_vote_state_payload(
        if is_finalized { "end" } else { "update" },
        &content_state,
        if is_finalized {
            Some(json!({
                "title": "투표가 마감되었습니다",
                "body": format!(
                    "참여 {}명 / 불참 {}명",
                    content_state.accepted_members.len(),
                    content_state.declined_members.len()
                )
            }))
        } else {
            None
        },
        is_finalized,
    );

    sender.send_broadcast(channel_id.as_str(), &payload).await?;

    if is_finalized {
        mark_vote_live_activity_finished(pool, schedule.id, true).await?;
    }

    Ok(Some(UpdateVoteLiveActivityResponse {
        success: true,
        content_state,
    }))
}

pub async fn finalize_vote_live_activity(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
    user_id: &str,
) -> Result<UpdateVoteLiveActivityResponse, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    if schedule.user_id != user_id {
        return Err(AppError::Forbidden(
            "호스트만 투표를 마감할 수 있습니다".to_string(),
        ));
    }

    let content_state = load_vote_content_state(pool, &schedule, true).await?;

    if let Some(channel_id) = active_vote_channel(&schedule) {
        let payload = build_vote_state_payload(
            "end",
            &content_state,
            Some(json!({
                "title": "호스트가 투표를 마감했습니다",
                "body": format!(
                    "참여 {}명 / 불참 {}명",
                    content_state.accepted_members.len(),
                    content_state.declined_members.len()
                )
            })),
            true,
        );
        sender.send_broadcast(channel_id.as_str(), &payload).await?;
    }

    mark_vote_live_activity_finished(pool, schedule.id, true).await?;

    Ok(UpdateVoteLiveActivityResponse {
        success: true,
        content_state,
    })
}

pub async fn end_vote_live_activity_if_active(
    pool: &PgPool,
    sender: &dyn LiveActivitySender,
    schedule_id: Uuid,
) -> Result<bool, AppError> {
    let schedule = load_schedule(pool, schedule_id).await?;
    ensure_group_schedule(&schedule)?;

    let Some(channel_id) = active_vote_channel(&schedule) else {
        return Ok(false);
    };

    let content_state = load_vote_content_state(pool, &schedule, true).await?;
    let payload = build_vote_state_payload("end", &content_state, None, true);
    sender.send_broadcast(channel_id.as_str(), &payload).await?;
    mark_vote_live_activity_finished(pool, schedule.id, false).await?;

    Ok(true)
}

async fn load_schedule(pool: &PgPool, schedule_id: Uuid) -> Result<Schedule, AppError> {
    sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))
}

fn ensure_group_schedule(schedule: &Schedule) -> Result<(), AppError> {
    if schedule.schedule_type != ScheduleType::Group {
        return Err(AppError::BadRequest(
            "그룹 일정만 Live Activity를 사용할 수 있습니다".to_string(),
        ));
    }
    Ok(())
}

fn active_vote_channel(schedule: &Schedule) -> Option<String> {
    if schedule.vote_live_activity_ended_at.is_some() {
        return None;
    }

    schedule.vote_live_activity_channel_id.clone()
}

fn compute_vote_deadline(schedule: &Schedule) -> Result<chrono::DateTime<Utc>, AppError> {
    let tracking_minutes = schedule
        .tracking_start_minutes_before
        .unwrap_or(DEFAULT_VOTE_DEADLINE_MINUTES_BEFORE) as i64;
    let deadline_from_schedule = schedule.start_at - Duration::minutes(tracking_minutes);
    let max_deadline = Utc::now() + Duration::hours(MAX_VOTE_WINDOW_HOURS);
    let vote_deadline = deadline_from_schedule.min(max_deadline);

    if vote_deadline <= Utc::now() {
        return Err(AppError::PreconditionFailed(
            "투표 마감 시간이 이미 지났습니다".to_string(),
        ));
    }

    Ok(vote_deadline)
}

async fn persist_vote_live_activity_start(
    pool: &PgPool,
    schedule: &Schedule,
    channel_id: &str,
) -> Result<(), AppError> {
    let mut tx = pool.begin().await?;

    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status, responded_at) \
         VALUES ($1, $2, 'accepted'::vote_status, NOW()) \
         ON CONFLICT (schedule_id, user_id) \
         DO UPDATE SET status = 'accepted'::vote_status, responded_at = NOW()",
    )
    .bind(schedule.id)
    .bind(&schedule.user_id)
    .execute(&mut *tx)
    .await?;

    let minimum_participants = schedule.minimum_participants.unwrap_or(2) as i64;
    let accepted_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes \
         WHERE schedule_id = $1 AND status = 'accepted'::vote_status",
    )
    .bind(schedule.id)
    .fetch_one(&mut *tx)
    .await?;

    sqlx::query(
        "UPDATE schedules SET is_confirmed = $1, vote_live_activity_channel_id = $2, \
         vote_live_activity_started_at = NOW(), vote_live_activity_finalized_at = NULL, \
         vote_live_activity_ended_at = NULL, updated_at = NOW() WHERE id = $3",
    )
    .bind(accepted_count.0 >= minimum_participants)
    .bind(channel_id)
    .bind(schedule.id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(())
}

async fn load_group_members(
    pool: &PgPool,
    group_id: Uuid,
) -> Result<Vec<GroupMemberRow>, AppError> {
    sqlx::query_as::<_, GroupMemberRow>(
        "SELECT u.id, u.nickname \
         FROM group_members gm \
         JOIN users u ON u.id = gm.user_id \
         WHERE gm.group_id = $1 \
         ORDER BY gm.joined_at, u.id",
    )
    .bind(group_id)
    .fetch_all(pool)
    .await
    .map_err(Into::into)
}

async fn load_vote_content_state(
    pool: &PgPool,
    schedule: &Schedule,
    force_finalized: bool,
) -> Result<VoteLiveActivityContentState, AppError> {
    let group_id = schedule
        .group_id
        .ok_or_else(|| AppError::Internal("그룹 일정에 group_id가 없습니다".to_string()))?;
    let total_member_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
            .bind(group_id)
            .fetch_one(pool)
            .await?;
    let vote_rows = sqlx::query_as::<_, ScheduleVoteRow>(
        "SELECT sv.user_id, u.nickname, sv.status::TEXT AS status \
         FROM schedule_votes sv \
         JOIN users u ON u.id = sv.user_id \
         WHERE sv.schedule_id = $1 \
         ORDER BY sv.responded_at, sv.user_id",
    )
    .bind(schedule.id)
    .fetch_all(pool)
    .await?;

    let mut accepted_members = Vec::new();
    let mut declined_members = Vec::new();

    for row in vote_rows {
        let member = VoteLiveActivityMember {
            id: row.user_id,
            name: row.nickname,
        };
        match row.status.as_str() {
            "accepted" => accepted_members.push(member),
            "declined" => declined_members.push(member),
            _ => {}
        }
    }

    let responded_count = accepted_members.len() + declined_members.len();
    let pending_count = (total_member_count.0 as usize).saturating_sub(responded_count) as i32;
    let is_finalized = force_finalized || responded_count >= total_member_count.0 as usize;

    Ok(VoteLiveActivityContentState {
        accepted_members,
        declined_members,
        pending_count,
        is_finalized,
    })
}

async fn load_vote_start_content_state(
    pool: &PgPool,
    schedule: &Schedule,
    host_name: &str,
) -> Result<VoteLiveActivityContentState, AppError> {
    let mut content_state = load_vote_content_state(pool, schedule, false).await?;
    let total_member_count = content_state.accepted_members.len()
        + content_state.declined_members.len()
        + content_state.pending_count.max(0) as usize;
    let host_already_accepted = content_state
        .accepted_members
        .iter()
        .any(|member| member.id == schedule.user_id);

    content_state
        .declined_members
        .retain(|member| member.id != schedule.user_id);

    if !host_already_accepted {
        content_state.accepted_members.insert(
            0,
            VoteLiveActivityMember {
                id: schedule.user_id.clone(),
                name: host_name.to_string(),
            },
        );
    }

    let responded_count =
        content_state.accepted_members.len() + content_state.declined_members.len();
    content_state.pending_count = total_member_count.saturating_sub(responded_count) as i32;
    content_state.is_finalized = responded_count >= total_member_count;

    Ok(content_state)
}

async fn load_vote_infos(pool: &PgPool, schedule_id: Uuid) -> Result<Vec<VoteInfo>, AppError> {
    let rows: Vec<(String, String)> = sqlx::query_as(
        "SELECT user_id, status::TEXT \
         FROM schedule_votes \
         WHERE schedule_id = $1 \
         ORDER BY responded_at, user_id",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|(user_id, status)| VoteInfo { user_id, status })
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

async fn mark_vote_live_activity_finished(
    pool: &PgPool,
    schedule_id: Uuid,
    finalized: bool,
) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE schedules \
         SET vote_live_activity_channel_id = NULL, \
             vote_live_activity_finalized_at = CASE WHEN $1 THEN NOW() ELSE vote_live_activity_finalized_at END, \
             vote_live_activity_ended_at = NOW(), \
             updated_at = NOW() \
         WHERE id = $2",
    )
    .bind(finalized)
    .bind(schedule_id)
    .execute(pool)
    .await?;

    Ok(())
}

fn build_vote_start_payload(
    schedule: &Schedule,
    current_user_id: &str,
    channel_id: &str,
    emoji: &str,
    host_name: &str,
    group_name: &str,
    total_member_count: i32,
    vote_deadline: i64,
    content_state: &VoteLiveActivityContentState,
) -> serde_json::Value {
    json!({
        "aps": {
            "timestamp": Utc::now().timestamp(),
            "event": "start",
            "dismissal-date": vote_deadline,
            "input-push-channel": channel_id,
            "attributes-type": "VoteActivityAttributes",
            "attributes": {
                "scheduleId": schedule.id.to_string(),
                "currentUserId": current_user_id,
                "emoji": emoji,
                "title": schedule.title,
                "location": schedule.location_name,
                "scheduledTime": schedule.start_at.timestamp() as f64,
                "hostId": schedule.user_id,
                "hostName": host_name,
                "channelId": channel_id,
                "groupName": if group_name.is_empty() { None::<String> } else { Some(group_name.to_string()) },
                "totalMemberCount": total_member_count,
                "minimumParticipants": schedule.minimum_participants.unwrap_or(2),
                "voteDeadline": vote_deadline as f64,
            },
            "content-state": content_state,
            "alert": {
                "title": format!("{emoji} {}", schedule.title),
                "body": "참여 여부를 확인해주세요"
            }
        }
    })
}

fn build_vote_state_payload(
    event: &str,
    content_state: &VoteLiveActivityContentState,
    alert: Option<serde_json::Value>,
    dismissed: bool,
) -> serde_json::Value {
    let mut payload = json!({
        "aps": {
            "timestamp": Utc::now().timestamp(),
            "event": event,
            "content-state": content_state,
        }
    });

    if dismissed {
        payload["aps"]["dismissal-date"] = json!(Utc::now().timestamp());
    }

    if let Some(alert) = alert {
        payload["aps"]["alert"] = alert;
    }

    payload
}
