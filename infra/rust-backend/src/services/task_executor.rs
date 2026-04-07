use std::sync::Arc;

use sqlx::PgPool;
use tokio::time::{interval, Duration};
use tracing::{error, info, warn};

use crate::models::live_activity::{ApnsSender, ScheduledTask};
use crate::services::apns_service::RealApnsSender;
use crate::services::{live_activity_service, scheduled_task_service};

const POLL_INTERVAL_SECS: u64 = 30;

/// 서버 시작 시 호출. 30초마다 pending tasks를 폴링하여 실행.
pub async fn start_polling_loop(pool: PgPool, apns: Arc<RealApnsSender>) {
    let mut ticker = interval(Duration::from_secs(POLL_INTERVAL_SECS));

    info!(
        "Scheduled task polling loop started (interval: {}s)",
        POLL_INTERVAL_SECS
    );

    loop {
        ticker.tick().await;

        match scheduled_task_service::poll_pending_tasks(&pool).await {
            Ok(tasks) => {
                if !tasks.is_empty() {
                    info!("Polled {} pending tasks", tasks.len());
                }
                for task in tasks {
                    let pool = pool.clone();
                    let apns = apns.clone();
                    tokio::spawn(async move {
                        execute_task(&pool, &apns, &task).await;
                    });
                }
            }
            Err(e) => {
                error!("Failed to poll scheduled tasks: {}", e);
            }
        }
    }
}

/// 개별 task 실행. task_type에 따라 분기.
async fn execute_task(pool: &PgPool, apns: &RealApnsSender, task: &ScheduledTask) {
    info!(
        "Executing task: {} (schedule: {})",
        task.task_type, task.schedule_id
    );

    let result = match task.task_type.as_str() {
        "start_live_activity" => execute_start_live_activity(pool, apns, task).await,
        "end_live_activity" | "delayed_end_live_activity" => {
            execute_end_live_activity(pool, apns, task).await
        }
        "nudge" => execute_nudge(pool, task).await,
        other => {
            warn!("Unknown task type: {}", other);
            Ok(())
        }
    };

    match result {
        Ok(()) => {
            if let Err(e) = scheduled_task_service::mark_task_completed(pool, task.id).await {
                error!("Failed to mark task {} completed: {}", task.id, e);
            }
        }
        Err(e) => {
            error!("Task {} failed: {}", task.id, e);
            if let Err(e) = scheduled_task_service::mark_task_failed(pool, task.id).await {
                error!("Failed to mark task {} failed: {}", task.id, e);
            }
        }
    }
}

async fn execute_start_live_activity(
    pool: &PgPool,
    apns: &RealApnsSender,
    task: &ScheduledTask,
) -> Result<(), crate::errors::AppError> {
    // payload에서 version 확인
    let task_version = task
        .payload
        .get("version")
        .and_then(|v| v.as_str())
        .and_then(|s| uuid::Uuid::parse_str(s).ok());

    // schedule 조회
    let schedule = sqlx::query_as::<_, crate::models::schedule::Schedule>(
        "SELECT * FROM schedules WHERE id = $1",
    )
    .bind(task.schedule_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| crate::errors::AppError::Internal(e.to_string()))?
    .ok_or_else(|| crate::errors::AppError::NotFound("Schedule not found".into()))?;

    // version 불일치 -> stale task, 스킵
    if let (Some(task_ver), Some(sched_ver)) = (task_version, schedule.la_schedule_version) {
        if task_ver != sched_ver {
            info!("Stale task skipped (version mismatch): {}", task.id);
            return Ok(());
        }
    }

    // 이미 시작됨 -> 스킵
    if schedule.la_started {
        info!("Task skipped (already started): {}", task.id);
        return Ok(());
    }

    // 호스트 user_id로 start_live_activity 호출
    live_activity_service::start_live_activity(pool, apns, &schedule.user_id, task.schedule_id)
        .await?;

    Ok(())
}

async fn execute_end_live_activity(
    pool: &PgPool,
    apns: &RealApnsSender,
    task: &ScheduledTask,
) -> Result<(), crate::errors::AppError> {
    use crate::models::live_activity::ApnsPayload;

    // schedule 조회하여 channel_id 확인
    let schedule = sqlx::query_as::<_, crate::models::schedule::Schedule>(
        "SELECT * FROM schedules WHERE id = $1",
    )
    .bind(task.schedule_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| crate::errors::AppError::Internal(e.to_string()))?;

    let schedule = match schedule {
        Some(s) => s,
        None => {
            info!(
                "Schedule not found for end task, skipping: {}",
                task.schedule_id
            );
            return Ok(());
        }
    };

    // payload에서 channel_id 확인, 없으면 vote_channel_id 사용
    let channel_id = task
        .payload
        .get("channel_id")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .or(schedule.vote_channel_id);

    if let Some(ch) = channel_id {
        let now = chrono::Utc::now().timestamp() - 60; // 과거 시간으로 즉시 제거
        let payload = ApnsPayload {
            event: "end".to_string(),
            content_state: serde_json::json!({}),
            channel_id: Some(ch.clone()),
            dismissal_date: Some(now),
            alert: None,
        };
        apns.send_broadcast(&ch, &payload).await;
    }

    // la_started = false 리셋
    sqlx::query("UPDATE schedules SET la_started = false WHERE id = $1")
        .bind(task.schedule_id)
        .execute(pool)
        .await
        .map_err(|e| crate::errors::AppError::Internal(e.to_string()))?;

    Ok(())
}

async fn execute_nudge(
    pool: &PgPool,
    task: &ScheduledTask,
) -> Result<(), crate::errors::AppError> {
    // payload에서 user_ids 추출
    let user_ids: Vec<String> = task
        .payload
        .get("user_ids")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    if user_ids.is_empty() {
        info!("No user_ids in nudge payload, skipping");
        return Ok(());
    }

    // 약속 정보 조회
    let schedule = sqlx::query_as::<_, crate::models::schedule::Schedule>(
        "SELECT * FROM schedules WHERE id = $1",
    )
    .bind(task.schedule_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| crate::errors::AppError::Internal(e.to_string()))?;

    let schedule = match schedule {
        Some(s) => s,
        None => return Ok(()),
    };

    // 약속 시작 전인지 확인 (이미 시작 시간 지났으면 스킵)
    if schedule.start_at <= chrono::Utc::now() {
        info!(
            "Schedule already started, skipping nudge: {}",
            task.schedule_id
        );
        return Ok(());
    }

    // FCM 넛지 알림은 notification_service를 통해 발송해야 하지만,
    // PushSender 실구현체가 아직 없으므로 로깅만 수행
    // TODO: FCM PushSender 구현 후 실제 발송
    let tracking = schedule.tracking_start_minutes_before.unwrap_or(30);
    info!(
        "Nudge: schedule={}, title='{}', tracking={}min, targets={} users",
        task.schedule_id,
        schedule.title,
        tracking,
        user_ids.len()
    );

    Ok(())
}
