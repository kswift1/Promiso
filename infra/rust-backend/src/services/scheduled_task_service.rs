use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::live_activity::ScheduledTask;

/// `scheduled_tasks` 테이블에 새 태스크를 INSERT하고 생성된 행을 반환한다.
pub async fn create_task(
    pool: &PgPool,
    task_type: &str,
    schedule_id: Uuid,
    execute_at: DateTime<Utc>,
    payload: serde_json::Value,
) -> Result<ScheduledTask, AppError> {
    let task = sqlx::query_as::<_, ScheduledTask>(
        "INSERT INTO scheduled_tasks (task_type, schedule_id, execute_at, payload) \
         VALUES ($1, $2, $3, $4) \
         RETURNING id, task_type, schedule_id, execute_at, payload, \
                   status::TEXT, retry_count, max_retries, created_at, updated_at",
    )
    .bind(task_type)
    .bind(schedule_id)
    .bind(execute_at)
    .bind(payload)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(task)
}

/// 특정 schedule_id에 연결된 pending 상태의 태스크를 failed로 변경한다.
/// `task_type`이 지정되면 해당 타입만 취소한다.
/// 변경된 행 수를 반환한다.
pub async fn cancel_pending_tasks(
    pool: &PgPool,
    schedule_id: Uuid,
    task_type: Option<&str>,
) -> Result<i64, AppError> {
    let result = match task_type {
        Some(tt) => {
            sqlx::query(
                "UPDATE scheduled_tasks \
                 SET status = 'failed'::task_status, updated_at = now() \
                 WHERE schedule_id = $1 \
                   AND task_type = $2 \
                   AND status = 'pending'::task_status",
            )
            .bind(schedule_id)
            .bind(tt)
            .execute(pool)
            .await
        }
        None => {
            sqlx::query(
                "UPDATE scheduled_tasks \
                 SET status = 'failed'::task_status, updated_at = now() \
                 WHERE schedule_id = $1 \
                   AND status = 'pending'::task_status",
            )
            .bind(schedule_id)
            .execute(pool)
            .await
        }
    }
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(result.rows_affected() as i64)
}

/// `execute_at <= NOW()` 이면서 `status = 'pending'`인 태스크를 조회하고,
/// 동시에 status를 'processing'으로 변경한다.
/// `SELECT FOR UPDATE SKIP LOCKED`로 동시 실행을 방지한다.
pub async fn poll_pending_tasks(pool: &PgPool) -> Result<Vec<ScheduledTask>, AppError> {
    let tasks = sqlx::query_as::<_, ScheduledTask>(
        "UPDATE scheduled_tasks \
         SET status = 'processing'::task_status, updated_at = now() \
         WHERE id IN ( \
             SELECT id FROM scheduled_tasks \
             WHERE execute_at <= now() \
               AND status = 'pending'::task_status \
             FOR UPDATE SKIP LOCKED \
         ) \
         RETURNING id, task_type, schedule_id, execute_at, payload, \
                   status::TEXT, retry_count, max_retries, created_at, updated_at",
    )
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(tasks)
}

/// 태스크의 status를 'completed'로 변경한다.
pub async fn mark_task_completed(pool: &PgPool, task_id: Uuid) -> Result<(), AppError> {
    let result = sqlx::query(
        "UPDATE scheduled_tasks \
         SET status = 'completed'::task_status, updated_at = now() \
         WHERE id = $1",
    )
    .bind(task_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound(format!(
            "Scheduled task {} not found",
            task_id
        )));
    }

    Ok(())
}

/// 태스크의 status를 'failed'로 변경하고, retry_count를 1 증가시킨다.
pub async fn mark_task_failed(pool: &PgPool, task_id: Uuid) -> Result<(), AppError> {
    let result = sqlx::query(
        "UPDATE scheduled_tasks \
         SET status = 'failed'::task_status, \
             retry_count = retry_count + 1, \
             updated_at = now() \
         WHERE id = $1",
    )
    .bind(task_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound(format!(
            "Scheduled task {} not found",
            task_id
        )));
    }

    Ok(())
}
