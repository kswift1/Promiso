use chrono::{Duration, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::*;
use crate::models::schedule::Schedule;
use crate::services::scheduled_task_service;

// ============================================================
// 내부 헬퍼
// ============================================================

/// schedules 테이블에서 id로 Schedule 조회. 없으면 NotFound.
async fn fetch_schedule(pool: &PgPool, schedule_id: Uuid) -> Result<Schedule, AppError> {
    sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))
}

/// schedule.user_id == user_uid 확인. 아니면 Forbidden.
fn ensure_host(schedule: &Schedule, user_uid: &str, action: &str) -> Result<(), AppError> {
    if schedule.user_id != user_uid {
        return Err(AppError::Forbidden(format!(
            "Only host can {}",
            action
        )));
    }
    Ok(())
}

/// accepted 유저들의 push_to_start_token 수집
async fn collect_push_to_start_tokens(
    pool: &PgPool,
    user_ids: &[String],
) -> Result<Vec<String>, AppError> {
    if user_ids.is_empty() {
        return Ok(Vec::new());
    }
    let rows: Vec<(String,)> = sqlx::query_as(
        "SELECT push_to_start_token FROM devices \
         WHERE user_id = ANY($1) AND push_to_start_token IS NOT NULL",
    )
    .bind(user_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(rows.into_iter().map(|(t,)| t).collect())
}

/// schedule_votes에서 accepted 유저 목록 조회
async fn get_accepted_user_ids(
    pool: &PgPool,
    schedule_id: Uuid,
) -> Result<Vec<String>, AppError> {
    let rows: Vec<(String,)> = sqlx::query_as(
        "SELECT user_id FROM schedule_votes \
         WHERE schedule_id = $1 AND status = 'accepted'",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(rows.into_iter().map(|(id,)| id).collect())
}

/// schedule_votes에서 accepted count 조회
async fn count_accepted(pool: &PgPool, schedule_id: Uuid) -> Result<i64, AppError> {
    let row: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes \
         WHERE schedule_id = $1 AND status = 'accepted'",
    )
    .bind(schedule_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(row.0)
}

/// vote 결과 (accepted / declined 리스트) 조회 -- VoteMember (id + name) 포함
async fn get_vote_lists_with_names(
    pool: &PgPool,
    schedule_id: Uuid,
) -> Result<(Vec<VoteMember>, Vec<VoteMember>), AppError> {
    let rows: Vec<(String, String, String)> = sqlx::query_as(
        "SELECT sv.user_id, u.nickname, sv.status::TEXT \
         FROM schedule_votes sv \
         JOIN users u ON u.id = sv.user_id \
         WHERE sv.schedule_id = $1",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let mut accepted = Vec::new();
    let mut declined = Vec::new();
    for (user_id, name, status) in rows {
        let member = VoteMember { id: user_id, name };
        match status.as_str() {
            "accepted" => accepted.push(member),
            "declined" => declined.push(member),
            _ => {}
        }
    }
    Ok((accepted, declined))
}

/// group_members count for a group
async fn count_group_members(pool: &PgPool, group_id: Uuid) -> Result<i64, AppError> {
    let row: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
            .bind(group_id)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    Ok(row.0)
}

// ============================================================
// Schedule LiveActivity
// ============================================================

pub async fn start_live_activity(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    user_uid: &str,
    schedule_id: Uuid,
) -> Result<LiveActivityResponse, AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 권한: 호스트만 시작 가능
    ensure_host(&schedule, user_uid, "start live activity")?;

    // 참가자 수 확인
    let accepted_count = count_accepted(pool, schedule_id).await?;
    let minimum = schedule.minimum_participants.unwrap_or(2) as i64;

    if accepted_count < minimum {
        // 인원 부족: 성공 반환하지만 APNs 전송 안 함
        return Ok(LiveActivityResponse {
            success: true,
            success_count: 0,
            failure_count: 0,
        });
    }

    // tracking 기본값 30
    let tracking_minutes = schedule.tracking_start_minutes_before.unwrap_or(30) as i64;

    // accepted 유저들의 push_to_start_token 수집
    let accepted_users = get_accepted_user_ids(pool, schedule_id).await?;
    let tokens = collect_push_to_start_tokens(pool, &accepted_users).await?;

    // APNs 채널 생성 + Push to Start 전송
    let channel_id = apns.create_channel().await?;
    let payload = ApnsPayload {
        event: "start".to_string(),
        content_state: serde_json::json!({
            "schedule_id": schedule_id.to_string(),
        }),
        channel_id: Some(channel_id),
        dismissal_date: None,
        alert: None,
    };

    let apns_result = if !tokens.is_empty() {
        apns.send_push_to_start(&tokens, &payload).await
    } else {
        ApnsResult {
            success_count: 0,
            failure_count: 0,
        }
    };

    // 종료 task: start_at + 30분
    let end_execute_at = schedule.start_at + Duration::minutes(30);
    scheduled_task_service::create_task(
        pool,
        "end_live_activity",
        schedule_id,
        end_execute_at,
        serde_json::json!({"action": "end_live_activity"}),
    )
    .await?;

    // 넛지 task: now + tracking/2분, 약속당 1개
    let nudge_execute_at = Utc::now() + Duration::minutes(tracking_minutes / 2);
    let nudge_payload = serde_json::json!({
        "action": "nudge",
        "user_ids": accepted_users,
    });
    scheduled_task_service::create_task(
        pool,
        "nudge",
        schedule_id,
        nudge_execute_at,
        nudge_payload,
    )
    .await?;

    // la_started = true 업데이트
    sqlx::query("UPDATE schedules SET la_started = true WHERE id = $1")
        .bind(schedule_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(LiveActivityResponse {
        success: true,
        success_count: apns_result.success_count,
        failure_count: apns_result.failure_count,
    })
}

pub async fn update_eta(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    _user_uid: &str,
    schedule_id: Uuid,
    req: UpdateETARequest,
) -> Result<LiveActivityResponse, AppError> {
    let _schedule = fetch_schedule(pool, schedule_id).await?;

    // 참가자 상태 분석
    let total_count = req.participants.len() as i32;
    let arrived_count = req
        .participants
        .iter()
        .filter(|p| p.estimated_arrival_minutes == Some(0))
        .count() as i32;

    // alert: 첫 번째 도착자 또는 모두 도착 시
    let alert = if arrived_count == 1 && total_count > 1 {
        // 첫 도착자 이름 찾기
        let first_arrived = req
            .participants
            .iter()
            .find(|p| p.estimated_arrival_minutes == Some(0));
        first_arrived.map(|p| ApnsAlert {
            title: "도착 알림".to_string(),
            body: format!("{}님이 도착했습니다!", p.name),
        })
    } else if arrived_count == total_count && total_count > 1 {
        // 모두 도착 alert
        Some(ApnsAlert {
            title: "모두 도착!".to_string(),
            body: "모든 멤버들이 도착했어요! 잠시 후 종료됩니다".to_string(),
        })
    } else {
        None
    };

    // content_state 구성
    let content_state = serde_json::to_value(&req.participants)
        .map_err(|e| AppError::Internal(e.to_string()))?;

    let payload = ApnsPayload {
        event: "update".to_string(),
        content_state,
        channel_id: Some(req.channel_id.clone()),
        dismissal_date: None,
        alert,
    };

    let apns_result = apns.send_broadcast(&req.channel_id, &payload).await;

    // 모두 도착: delayed_end_live_activity task (5분 후)
    if arrived_count == total_count && total_count > 1 {
        let delayed_end_at = Utc::now() + Duration::minutes(5);
        scheduled_task_service::create_task(
            pool,
            "delayed_end_live_activity",
            schedule_id,
            delayed_end_at,
            serde_json::json!({"action": "delayed_end_live_activity"}),
        )
        .await?;
    }

    Ok(LiveActivityResponse {
        success: true,
        success_count: apns_result.success_count,
        failure_count: apns_result.failure_count,
    })
}

pub async fn schedule_live_activity(
    pool: &PgPool,
    schedule_id: Uuid,
) -> Result<(), AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 이미 시작된 경우 무시
    if schedule.la_started {
        return Ok(());
    }

    // 기존 pending tasks 취소 (재스케줄 지원)
    scheduled_task_service::cancel_pending_tasks(pool, schedule_id, None).await?;

    // 새 version 생성
    let new_version = Uuid::new_v4();

    // tracking 기본값 30
    let tracking_minutes = schedule.tracking_start_minutes_before.unwrap_or(30) as i64;

    // DB 업데이트
    sqlx::query(
        "UPDATE schedules SET la_scheduled = true, la_scheduled_at = NOW(), \
         la_schedule_version = $1 WHERE id = $2",
    )
    .bind(new_version)
    .bind(schedule_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // scheduled_tasks에 start_live_activity task INSERT
    let execute_at = schedule.start_at - Duration::minutes(tracking_minutes);
    scheduled_task_service::create_task(
        pool,
        "start_live_activity",
        schedule_id,
        execute_at,
        serde_json::json!({
            "action": "start_live_activity",
            "version": new_version.to_string(),
        }),
    )
    .await?;

    Ok(())
}

pub async fn cancel_live_activity_schedule(
    pool: &PgPool,
    schedule_id: Uuid,
) -> Result<(), AppError> {
    // la_scheduled 리셋
    sqlx::query(
        "UPDATE schedules SET la_scheduled = false, la_scheduled_at = NULL, \
         la_schedule_version = NULL WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // pending tasks 취소
    scheduled_task_service::cancel_pending_tasks(pool, schedule_id, None).await?;

    Ok(())
}

// ============================================================
// Vote LiveActivity
// ============================================================

pub async fn start_vote(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    user_uid: &str,
    schedule_id: Uuid,
) -> Result<VoteStartResponse, AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 권한: 호스트만
    ensure_host(&schedule, user_uid, "start vote")?;

    // 유효성: 과거 일정
    if schedule.start_at <= Utc::now() {
        return Err(AppError::PreconditionFailed(
            "이미 시작된 일정에는 투표를 시작할 수 없습니다".to_string(),
        ));
    }

    // 유효성: vote_deadline 지남
    if let Some(deadline) = schedule.vote_deadline {
        if deadline <= Utc::now() {
            return Err(AppError::PreconditionFailed(
                "투표 마감 기한이 지났습니다".to_string(),
            ));
        }
    }

    // 유효성: 이미 투표 진행 중
    if schedule.vote_channel_id.is_some() {
        return Err(AppError::Conflict(
            "이미 투표가 진행 중입니다".to_string(),
        ));
    }

    // APNs 채널 생성
    let channel_id = apns.create_channel().await?;

    // vote_ended_at 계산: min(start_at - tracking*60초, now + 8시간)
    let tracking_minutes = schedule.tracking_start_minutes_before.unwrap_or(0) as i64;
    let deadline_by_tracking = if tracking_minutes > 0 {
        schedule.start_at - Duration::minutes(tracking_minutes)
    } else {
        schedule.start_at
    };
    let deadline_by_max = Utc::now() + Duration::hours(8);
    let vote_ended_at = if deadline_by_tracking < deadline_by_max {
        deadline_by_tracking
    } else {
        deadline_by_max
    };

    // DB 업데이트
    sqlx::query(
        "UPDATE schedules SET vote_channel_id = $1, vote_started_at = NOW(), \
         vote_ended_at = $2 WHERE id = $3",
    )
    .bind(&channel_id)
    .bind(vote_ended_at)
    .bind(schedule_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 호스트 자동 수락
    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) \
         VALUES ($1, $2, 'accepted'::vote_status) \
         ON CONFLICT (schedule_id, user_id) DO UPDATE SET status = 'accepted'::vote_status",
    )
    .bind(schedule_id)
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 그룹 멤버 디바이스에서 push_to_start_token 수집 (호스트 제외)
    let group_id = schedule.group_id.ok_or_else(|| {
        AppError::Internal("Schedule has no group_id".to_string())
    })?;

    // 호스트 이름 조회
    let host_row: Option<(String,)> = sqlx::query_as(
        "SELECT nickname FROM users WHERE id = $1",
    )
    .bind(user_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;
    let host_name = host_row.map(|(n,)| n).unwrap_or_default();

    let total_members = count_group_members(pool, group_id).await? as i32;

    let member_rows: Vec<(String,)> = sqlx::query_as(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let member_ids: Vec<String> = member_rows.into_iter().map(|(id,)| id).collect();
    let tokens = collect_push_to_start_tokens(pool, &member_ids).await?;

    let payload = ApnsPayload {
        event: "start".to_string(),
        content_state: serde_json::json!({
            "accepted": [{"id": user_uid, "name": host_name}],
            "declined": [],
            "pendingCount": total_members - 1,
            "isFinalized": false,
        }),
        channel_id: Some(channel_id.clone()),
        dismissal_date: Some(vote_ended_at.timestamp()),
        alert: Some(ApnsAlert {
            title: "참여 투표".to_string(),
            body: "참여 여부를 확인해주세요".to_string(),
        }),
    };

    let apns_result = if !tokens.is_empty() {
        apns.send_push_to_start(&tokens, &payload).await
    } else {
        ApnsResult {
            success_count: 0,
            failure_count: 0,
        }
    };

    Ok(VoteStartResponse {
        success: true,
        success_count: apns_result.success_count,
        failure_count: apns_result.failure_count,
        channel_id: Some(channel_id),
    })
}

pub async fn respond_vote(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    user_uid: &str,
    schedule_id: Uuid,
    req: VoteRespondRequest,
) -> Result<VoteRespondResponse, AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 권한: 그룹 멤버인지 확인
    let group_id = schedule.group_id.ok_or_else(|| {
        AppError::Internal("Schedule has no group_id".to_string())
    })?;

    let is_member: Option<(String,)> = sqlx::query_as(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if is_member.is_none() {
        return Err(AppError::Forbidden(
            "그룹 멤버만 투표에 응답할 수 있습니다".to_string(),
        ));
    }

    // 트랜잭션 시작
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // UPSERT vote (tx 사용)
    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) \
         VALUES ($1, $2, $3::vote_status) \
         ON CONFLICT (schedule_id, user_id) DO UPDATE SET \
           status = $3::vote_status, responded_at = NOW()",
    )
    .bind(schedule_id)
    .bind(user_uid)
    .bind(&req.response)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 투표 결과 조회 (tx 사용, 인라인 -- VoteMember)
    let rows: Vec<(String, String, String)> = sqlx::query_as(
        "SELECT sv.user_id, u.nickname, sv.status::TEXT \
         FROM schedule_votes sv \
         JOIN users u ON u.id = sv.user_id \
         WHERE sv.schedule_id = $1",
    )
    .bind(schedule_id)
    .fetch_all(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let mut accepted = Vec::new();
    let mut declined = Vec::new();
    for (user_id, name, status) in rows {
        let member = VoteMember { id: user_id, name };
        match status.as_str() {
            "accepted" => accepted.push(member),
            "declined" => declined.push(member),
            _ => {}
        }
    }

    // count (tx 사용)
    let row: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
            .bind(group_id)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    let total_member_count = row.0 as i32;
    let responded_count = (accepted.len() + declined.len()) as i32;

    // 자동 확정: 모든 멤버가 응답했으면
    let is_finalized = responded_count >= total_member_count;

    if is_finalized {
        sqlx::query("UPDATE schedules SET vote_finalized = true WHERE id = $1")
            .bind(schedule_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    }

    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // broadcast
    let pending_count = (total_member_count - responded_count).max(0);
    let content_state = VoteContentState {
        accepted: accepted.clone(),
        declined: declined.clone(),
        pending_count,
        is_finalized,
    };

    if let Some(ref ch) = schedule.vote_channel_id {
        let event = if is_finalized { "end" } else { "update" };
        let payload = ApnsPayload {
            event: event.to_string(),
            content_state: serde_json::to_value(&content_state)
                .map_err(|e| AppError::Internal(e.to_string()))?,
            channel_id: Some(ch.clone()),
            dismissal_date: None,
            alert: None,
        };
        apns.send_broadcast(ch, &payload).await;
    }

    Ok(VoteRespondResponse {
        success: true,
        content_state,
    })
}

pub async fn finalize_vote(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    user_uid: &str,
    schedule_id: Uuid,
) -> Result<VoteRespondResponse, AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 권한: 호스트만
    ensure_host(&schedule, user_uid, "finalize vote")?;

    // DB 업데이트
    sqlx::query(
        "UPDATE schedules SET vote_finalized = true, vote_ended_at = NOW() WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 투표 결과 조회
    let (accepted, declined) = get_vote_lists_with_names(pool, schedule_id).await?;
    let group_id = schedule.group_id.ok_or_else(|| {
        AppError::Internal("Schedule has no group_id".to_string())
    })?;
    let total_member_count = count_group_members(pool, group_id).await? as i32;
    let responded_count = (accepted.len() + declined.len()) as i32;
    let pending_count = (total_member_count - responded_count).max(0);

    let content_state = VoteContentState {
        accepted: accepted.clone(),
        declined: declined.clone(),
        pending_count,
        is_finalized: true,
    };

    // broadcast end event
    if let Some(ref ch) = schedule.vote_channel_id {
        let payload = ApnsPayload {
            event: "end".to_string(),
            content_state: serde_json::to_value(&content_state)
                .map_err(|e| AppError::Internal(e.to_string()))?,
            channel_id: Some(ch.clone()),
            dismissal_date: None,
            alert: Some(ApnsAlert {
                title: "호스트가 투표를 마감했습니다".to_string(),
                body: format!(
                    "참여 {}명 / 불참 {}명",
                    accepted.len(),
                    declined.len()
                ),
            }),
        };
        apns.send_broadcast(ch, &payload).await;
    }

    Ok(VoteRespondResponse {
        success: true,
        content_state,
    })
}

pub async fn end_vote(
    pool: &PgPool,
    apns: &dyn ApnsSender,
    user_uid: &str,
    schedule_id: Uuid,
) -> Result<(), AppError> {
    let schedule = fetch_schedule(pool, schedule_id).await?;

    // 권한: 호스트만
    ensure_host(&schedule, user_uid, "end vote")?;

    let old_channel_id = schedule.vote_channel_id.clone();

    // DB 업데이트: vote_ended_at 설정, vote_channel_id NULL
    sqlx::query(
        "UPDATE schedules SET vote_ended_at = NOW(), vote_channel_id = NULL WHERE id = $1",
    )
    .bind(schedule_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // broadcast end event (이전 channel_id가 있었으면)
    if let Some(ref ch) = old_channel_id {
        let (accepted, declined) = get_vote_lists_with_names(pool, schedule_id).await?;
        let group_id = schedule
            .group_id
            .ok_or_else(|| AppError::Internal("no group_id".into()))?;
        let total_member_count = count_group_members(pool, group_id).await? as i32;
        let responded_count = (accepted.len() + declined.len()) as i32;
        let pending_count = (total_member_count - responded_count).max(0);

        let content_state = VoteContentState {
            accepted,
            declined,
            pending_count,
            is_finalized: true,
        };

        let payload = ApnsPayload {
            event: "end".to_string(),
            content_state: serde_json::to_value(&content_state)
                .map_err(|e| AppError::Internal(e.to_string()))?,
            channel_id: Some(ch.clone()),
            dismissal_date: None,
            alert: None,
        };
        apns.send_broadcast(ch, &payload).await;
    }

    Ok(())
}
