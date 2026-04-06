use chrono::{DateTime, Datelike, Duration, LocalResult, NaiveDate, NaiveDateTime, TimeZone, Utc};
use chrono_tz::Tz;
use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::schedule::*;

// ============================================================
// 헬퍼
// ============================================================

/// 제목 유효성 검증: trim, 비어있지 않음, 최대 30자
fn validate_title(title: &str) -> Result<String, AppError> {
    let trimmed = title.trim().to_string();
    if trimmed.is_empty() {
        return Err(AppError::BadRequest(
            "제목은 비어있을 수 없습니다".to_string(),
        ));
    }
    if trimmed.chars().count() > 30 {
        return Err(AppError::BadRequest(
            "제목은 30자 이하여야 합니다".to_string(),
        ));
    }
    Ok(trimmed)
}

/// 설명 유효성 검증: 최대 500자
fn validate_description(description: &Option<String>) -> Result<(), AppError> {
    if let Some(desc) = description {
        if desc.chars().count() > 500 {
            return Err(AppError::BadRequest(
                "설명은 500자 이하여야 합니다".to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_start_at(start_at: DateTime<Utc>) -> Result<(), AppError> {
    if start_at <= Utc::now() {
        return Err(AppError::BadRequest(
            "시작 시간은 현재보다 미래여야 합니다".to_string(),
        ));
    }

    Ok(())
}

fn validate_end_at(start_at: DateTime<Utc>, end_at: Option<DateTime<Utc>>) -> Result<(), AppError> {
    if let Some(end_at) = end_at {
        if end_at <= start_at {
            return Err(AppError::BadRequest(
                "종료 시간은 시작 시간 이후여야 합니다".to_string(),
            ));
        }
    }

    Ok(())
}

fn validate_description_blocks(
    description_blocks: &Option<serde_json::Value>,
) -> Result<(), AppError> {
    if let Some(blocks) = description_blocks {
        if let Some(arr) = blocks.as_array() {
            if arr.len() > 20 {
                return Err(AppError::BadRequest(
                    "설명 블록은 최대 20개까지 허용됩니다".to_string(),
                ));
            }
        }
    }

    Ok(())
}

fn validate_image_urls(image_urls: &Option<Vec<String>>) -> Result<(), AppError> {
    if let Some(urls) = image_urls {
        if urls.len() > 3 {
            return Err(AppError::BadRequest(
                "이미지는 최대 3개까지 허용됩니다".to_string(),
            ));
        }
    }

    Ok(())
}

async fn get_group_member_count(pool: &PgPool, group_id: Uuid) -> Result<i64, AppError> {
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM group_members WHERE group_id = $1")
        .bind(group_id)
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(count.0)
}

fn validate_group_minimum_participants(
    minimum_participants: i16,
    member_count: i64,
) -> Result<(), AppError> {
    if minimum_participants < 1 {
        return Err(AppError::BadRequest(
            "최소 참여 인원은 1명 이상이어야 합니다".to_string(),
        ));
    }

    if minimum_participants == 1 && member_count > 1 {
        return Err(AppError::BadRequest(
            "최소 참여 인원 1명은 1인 그룹에서만 허용됩니다".to_string(),
        ));
    }

    if minimum_participants < 2 && member_count <= 0 {
        return Err(AppError::BadRequest(
            "그룹 멤버 수가 유효하지 않습니다".to_string(),
        ));
    }

    if minimum_participants < 2 && member_count == 1 {
        return Ok(());
    }

    if minimum_participants < 2 {
        return Err(AppError::BadRequest(
            "최소 참여 인원은 2명 이상이어야 합니다".to_string(),
        ));
    }

    Ok(())
}

fn effective_end_at(start_at: DateTime<Utc>, end_at: Option<DateTime<Utc>>) -> DateTime<Utc> {
    end_at.unwrap_or(start_at)
}

fn parse_timezone(timezone: Option<&str>) -> Result<Tz, AppError> {
    timezone
        .unwrap_or("UTC")
        .parse::<Tz>()
        .map_err(|_| AppError::BadRequest("유효하지 않은 timezone입니다".to_string()))
}

fn resolve_local_datetime(
    timezone: Tz,
    date: NaiveDate,
    time: &TimeComponents,
) -> Result<DateTime<Utc>, AppError> {
    let local = NaiveDateTime::new(
        date,
        chrono::NaiveTime::from_hms_opt(time.hour as u32, time.minute as u32, 0).ok_or_else(
            || AppError::Internal("반복 일정 시간 값이 유효하지 않습니다".to_string()),
        )?,
    );

    let zoned = match timezone.from_local_datetime(&local) {
        LocalResult::Single(dt) => dt,
        LocalResult::Ambiguous(dt, _) => dt,
        LocalResult::None => {
            return Err(AppError::BadRequest(
                "timezone 기준으로 반복 일정을 해석할 수 없습니다".to_string(),
            ));
        }
    };

    Ok(zoned.with_timezone(&Utc))
}

fn json_get<'a>(value: &'a serde_json::Value, keys: &[&str]) -> Option<&'a serde_json::Value> {
    keys.iter().find_map(|key| value.get(*key))
}

fn parse_override_time(
    override_entry: Option<&serde_json::Value>,
    keys: &[&str],
) -> Option<TimeComponents> {
    let value = override_entry.and_then(|entry| json_get(entry, keys))?;
    let hour = value.get("hour")?.as_i64()? as i16;
    let minute = value.get("minute")?.as_i64()? as i16;

    Some(TimeComponents { hour, minute })
}

fn parse_override_location(override_entry: Option<&serde_json::Value>) -> Option<LocationResponse> {
    let value = override_entry.and_then(|entry| entry.get("location"))?;
    let name = value.get("name")?.as_str()?.to_string();

    Some(LocationResponse {
        name,
        address: value
            .get("address")
            .and_then(|v| v.as_str())
            .map(|v| v.to_string()),
        latitude: value.get("latitude").and_then(|v| v.as_f64()),
        longitude: value.get("longitude").and_then(|v| v.as_f64()),
    })
}

/// Schedule DB 행 + votes로 ScheduleResponse 빌드
fn build_schedule_response(schedule: &Schedule, votes: Vec<ScheduleVote>) -> ScheduleResponse {
    let location = schedule
        .location_name
        .as_ref()
        .map(|name| LocationResponse {
            name: name.clone(),
            address: schedule.location_address.clone(),
            latitude: schedule.location_latitude,
            longitude: schedule.location_longitude,
        });

    let is_group = schedule.schedule_type == ScheduleType::Group;

    let votes_response = if is_group {
        let accepted: Vec<String> = votes
            .iter()
            .filter(|v| v.status == VoteStatus::Accepted)
            .map(|v| v.user_id.clone())
            .collect();
        let declined: Vec<String> = votes
            .iter()
            .filter(|v| v.status == VoteStatus::Declined)
            .map(|v| v.user_id.clone())
            .collect();
        Some(VotesResponse { accepted, declined })
    } else {
        None
    };

    ScheduleResponse {
        id: schedule.id,
        schedule_type: schedule.schedule_type.clone(),
        user_id: schedule.user_id.clone(),
        title: schedule.title.clone(),
        emoji: schedule.emoji.clone(),
        description: schedule.description.clone(),
        description_blocks: schedule.description_blocks.clone(),
        start_at: schedule.start_at,
        end_at: schedule.end_at,
        location,
        created_at: schedule.created_at,
        updated_at: schedule.updated_at,
        // 그룹일정 전용
        group_id: if is_group { schedule.group_id } else { None },
        host_id: if is_group {
            Some(schedule.user_id.clone())
        } else {
            None
        },
        minimum_participants: if is_group {
            schedule.minimum_participants
        } else {
            None
        },
        is_confirmed: if is_group {
            schedule.is_confirmed
        } else {
            None
        },
        vote_deadline: if is_group {
            schedule.vote_deadline
        } else {
            None
        },
        tracking_start_minutes_before: if is_group {
            schedule.tracking_start_minutes_before
        } else {
            None
        },
        image_urls: if is_group {
            schedule.image_urls.clone()
        } else {
            None
        },
        votes: votes_response,
        // 개인일정 전용
        reminder_minutes_before: if !is_group {
            schedule.reminder_minutes_before
        } else {
            None
        },
    }
}

// ============================================================
// 그룹/개인 일정 CRUD
// ============================================================

pub async fn create_schedule(
    pool: &PgPool,
    user_id: &str,
    req: CreateScheduleRequest,
) -> Result<CreateScheduleResponse, AppError> {
    // 공통 검증
    let title = validate_title(&req.title)?;
    validate_description(&req.description)?;
    validate_start_at(req.start_at)?;
    validate_end_at(req.start_at, req.end_at)?;
    validate_description_blocks(&req.description_blocks)?;

    // P20: 기본 이모지
    let emoji = req.emoji.unwrap_or_else(|| "\u{1F4C5}".to_string());

    match req.schedule_type {
        ScheduleType::Group => {
            // 그룹일정 전용 검증
            let group_id = req.group_id.ok_or_else(|| {
                AppError::BadRequest("그룹 일정에는 group_id가 필요합니다".to_string())
            })?;

            let minimum_participants = req.minimum_participants.ok_or_else(|| {
                AppError::BadRequest("그룹 일정에는 minimum_participants가 필요합니다".to_string())
            })?;

            if req.reminder_minutes_before.is_some() {
                return Err(AppError::BadRequest(
                    "그룹 일정에는 reminder_minutes_before를 설정할 수 없습니다".to_string(),
                ));
            }
            validate_image_urls(&req.image_urls)?;

            // 그룹 존재 확인
            let group_exists = sqlx::query_as::<_, (Uuid,)>("SELECT id FROM groups WHERE id = $1")
                .bind(group_id)
                .fetch_optional(pool)
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

            if group_exists.is_none() {
                return Err(AppError::NotFound("그룹을 찾을 수 없습니다".to_string()));
            }

            // 멤버십 확인
            let membership = sqlx::query_as::<_, (String,)>(
                "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
            )
            .bind(group_id)
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            if membership.is_none() {
                return Err(AppError::Forbidden("그룹 멤버가 아닙니다".to_string()));
            }

            let member_count = get_group_member_count(pool, group_id).await?;
            validate_group_minimum_participants(minimum_participants, member_count)?;

            // is_confirmed: minimum_participants <= 1 이면 호스트 자동수락으로 즉시 확정
            let is_confirmed = minimum_participants <= 1;
            let vote_deadline = req.start_at;

            // 트랜잭션: INSERT schedule + INSERT host vote
            let mut tx = pool
                .begin()
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

            let location_name = req.location.as_ref().map(|l| l.name.clone());
            let location_address = req.location.as_ref().and_then(|l| l.address.clone());
            let location_latitude = req.location.as_ref().and_then(|l| l.latitude);
            let location_longitude = req.location.as_ref().and_then(|l| l.longitude);

            let schedule = sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (schedule_type, user_id, title, emoji, description, \
                 description_blocks, start_at, end_at, location_name, location_address, \
                 location_latitude, location_longitude, group_id, minimum_participants, \
                 is_confirmed, vote_deadline, tracking_start_minutes_before, image_urls) \
                 VALUES ('group'::schedule_type, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, \
                         $12, $13, $14, $15, $16, $17) \
                 RETURNING *",
            )
            .bind(user_id)
            .bind(&title)
            .bind(Some(&emoji))
            .bind(&req.description)
            .bind(&req.description_blocks)
            .bind(req.start_at)
            .bind(req.end_at)
            .bind(&location_name)
            .bind(&location_address)
            .bind(location_latitude)
            .bind(location_longitude)
            .bind(group_id)
            .bind(minimum_participants)
            .bind(is_confirmed)
            .bind(vote_deadline)
            .bind(req.tracking_start_minutes_before)
            .bind(&req.image_urls)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            // P16: 호스트를 accepted로 schedule_votes에 등록
            sqlx::query(
                "INSERT INTO schedule_votes (schedule_id, user_id, status) \
                 VALUES ($1, $2, 'accepted'::vote_status)",
            )
            .bind(schedule.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            tx.commit()
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

            Ok(CreateScheduleResponse {
                schedule_id: schedule.id,
                title: schedule.title,
                group_id: schedule.group_id,
                start_at: schedule.start_at,
                is_confirmed: schedule.is_confirmed,
            })
        }
        ScheduleType::Personal => {
            // 개인일정: group_id가 있으면 에러
            if req.group_id.is_some() {
                return Err(AppError::BadRequest(
                    "개인 일정에는 group_id를 설정할 수 없습니다".to_string(),
                ));
            }

            if req.minimum_participants.is_some()
                || req.tracking_start_minutes_before.is_some()
                || req.image_urls.is_some()
            {
                return Err(AppError::BadRequest(
                    "개인 일정에는 그룹 일정 전용 필드를 설정할 수 없습니다".to_string(),
                ));
            }

            let location_name = req.location.as_ref().map(|l| l.name.clone());
            let location_address = req.location.as_ref().and_then(|l| l.address.clone());
            let location_latitude = req.location.as_ref().and_then(|l| l.latitude);
            let location_longitude = req.location.as_ref().and_then(|l| l.longitude);

            let schedule = sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (schedule_type, user_id, title, emoji, description, \
                 description_blocks, start_at, end_at, location_name, location_address, \
                 location_latitude, location_longitude, reminder_minutes_before) \
                 VALUES ('personal'::schedule_type, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, \
                         $11, $12) \
                 RETURNING *",
            )
            .bind(user_id)
            .bind(&title)
            .bind(Some(&emoji))
            .bind(&req.description)
            .bind(&req.description_blocks)
            .bind(req.start_at)
            .bind(req.end_at)
            .bind(&location_name)
            .bind(&location_address)
            .bind(location_latitude)
            .bind(location_longitude)
            .bind(req.reminder_minutes_before)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            Ok(CreateScheduleResponse {
                schedule_id: schedule.id,
                title: schedule.title,
                group_id: None,
                start_at: schedule.start_at,
                is_confirmed: None,
            })
        }
    }
}

pub async fn get_schedule(
    pool: &PgPool,
    user_id: &str,
    schedule_id: Uuid,
) -> Result<ScheduleResponse, AppError> {
    // 일정 조회
    let schedule = sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))?;

    // 권한 확인
    match schedule.schedule_type {
        ScheduleType::Group => {
            let group_id = schedule
                .group_id
                .ok_or_else(|| AppError::Internal("그룹 일정에 group_id가 없습니다".to_string()))?;

            let membership = sqlx::query_as::<_, (String,)>(
                "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
            )
            .bind(group_id)
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            if membership.is_none() {
                return Err(AppError::Forbidden("그룹 멤버가 아닙니다".to_string()));
            }
        }
        ScheduleType::Personal => {
            if schedule.user_id != user_id {
                return Err(AppError::Forbidden(
                    "본인의 일정만 조회할 수 있습니다".to_string(),
                ));
            }
        }
    }

    // 투표 조회
    let votes = sqlx::query_as::<_, ScheduleVote>(
        "SELECT schedule_id, user_id, status, responded_at \
         FROM schedule_votes WHERE schedule_id = $1",
    )
    .bind(schedule_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(build_schedule_response(&schedule, votes))
}

pub async fn update_schedule(
    pool: &PgPool,
    user_id: &str,
    schedule_id: Uuid,
    req: UpdateScheduleRequest,
) -> Result<(), AppError> {
    // 일정 조회
    let schedule = sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))?;

    // 권한 확인
    match schedule.schedule_type {
        ScheduleType::Group => {
            // P10: 일정 호스트 OR 그룹 관리자
            if schedule.user_id != user_id {
                let group_id = schedule.group_id.ok_or_else(|| {
                    AppError::Internal("그룹 일정에 group_id가 없습니다".to_string())
                })?;

                let role_row = sqlx::query_as::<_, (String,)>(
                    "SELECT role::TEXT FROM group_members WHERE group_id = $1 AND user_id = $2",
                )
                .bind(group_id)
                .bind(user_id)
                .fetch_optional(pool)
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

                match role_row {
                    Some((role,)) if role == "admin" => { /* OK: 그룹 관리자 */ }
                    _ => {
                        return Err(AppError::Forbidden(
                            "일정 호스트 또는 그룹 관리자만 수정할 수 있습니다".to_string(),
                        ));
                    }
                }
            }
        }
        ScheduleType::Personal => {
            if schedule.user_id != user_id {
                return Err(AppError::Forbidden(
                    "본인의 일정만 수정할 수 있습니다".to_string(),
                ));
            }
        }
    }

    // P12: start_at이 미래여야 함
    if schedule.start_at <= Utc::now() {
        return Err(AppError::PreconditionFailed(
            "이미 시작된 일정은 수정할 수 없습니다".to_string(),
        ));
    }

    // 제목 검증
    if let Some(ref title) = req.title {
        validate_title(title)?;
    }

    if let Some(description) = &req.description {
        validate_description(description)?;
    }

    if let Some(description_blocks) = &req.description_blocks {
        validate_description_blocks(description_blocks)?;
    }

    if let Some(image_urls) = &req.image_urls {
        validate_image_urls(image_urls)?;
    }

    let next_start_at = req.start_at.unwrap_or(schedule.start_at);
    let next_end_at = match req.end_at {
        Some(end_at) => end_at,
        None => schedule.end_at,
    };

    validate_start_at(next_start_at)?;
    validate_end_at(next_start_at, next_end_at)?;

    match schedule.schedule_type {
        ScheduleType::Group => {
            if req.reminder_minutes_before.is_some() {
                return Err(AppError::BadRequest(
                    "그룹 일정에는 reminder_minutes_before를 설정할 수 없습니다".to_string(),
                ));
            }
        }
        ScheduleType::Personal => {
            if req.minimum_participants.is_some()
                || req.tracking_start_minutes_before.is_some()
                || req.image_urls.is_some()
            {
                return Err(AppError::BadRequest(
                    "개인 일정에는 그룹 일정 전용 필드를 설정할 수 없습니다".to_string(),
                ));
            }
        }
    }

    if let Some(minimum_participants) = req.minimum_participants {
        let group_id = schedule.group_id.ok_or_else(|| {
            AppError::BadRequest(
                "개인 일정에는 minimum_participants를 설정할 수 없습니다".to_string(),
            )
        })?;
        let member_count = get_group_member_count(pool, group_id).await?;
        validate_group_minimum_participants(minimum_participants, member_count)?;
    }

    // 동적 UPDATE 쿼리 빌드
    let mut set_clauses: Vec<String> = Vec::new();
    let mut param_index = 1u32;

    if req.title.is_some() {
        set_clauses.push(format!("title = ${param_index}"));
        param_index += 1;
    }
    if req.emoji.is_some() {
        set_clauses.push(format!("emoji = ${param_index}"));
        param_index += 1;
    }
    if req.description.is_some() {
        set_clauses.push(format!("description = ${param_index}"));
        param_index += 1;
    }
    if req.description_blocks.is_some() {
        set_clauses.push(format!("description_blocks = ${param_index}"));
        param_index += 1;
    }
    if req.start_at.is_some() {
        set_clauses.push(format!("start_at = ${param_index}"));
        param_index += 1;
        // P30: start_at 변경 시 vote_deadline도 동기화
        if schedule.schedule_type == ScheduleType::Group {
            set_clauses.push(format!("vote_deadline = ${param_index}"));
            param_index += 1;
        }
    }
    if req.end_at.is_some() {
        set_clauses.push(format!("end_at = ${param_index}"));
        param_index += 1;
    }
    if req.location.is_some() {
        set_clauses.push(format!("location_name = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_address = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_latitude = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_longitude = ${param_index}"));
        param_index += 1;
    }
    if req.minimum_participants.is_some() {
        set_clauses.push(format!("minimum_participants = ${param_index}"));
        param_index += 1;
    }
    if req.tracking_start_minutes_before.is_some() {
        set_clauses.push(format!("tracking_start_minutes_before = ${param_index}"));
        param_index += 1;
    }
    if req.image_urls.is_some() {
        set_clauses.push(format!("image_urls = ${param_index}"));
        param_index += 1;
    }
    if req.reminder_minutes_before.is_some() {
        set_clauses.push(format!("reminder_minutes_before = ${param_index}"));
        param_index += 1;
    }

    if set_clauses.is_empty() {
        return Ok(());
    }

    set_clauses.push("updated_at = NOW()".to_string());

    let sql = format!(
        "UPDATE schedules SET {} WHERE id = ${param_index}",
        set_clauses.join(", "),
    );

    let mut query = sqlx::query(&sql);

    // 바인딩 순서: set_clauses 추가 순서와 동일
    if let Some(ref title) = req.title {
        query = query.bind(title.trim().to_string());
    }
    if let Some(ref inner) = req.emoji {
        match inner {
            None => query = query.bind(None::<String>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(ref inner) = req.description {
        match inner {
            None => query = query.bind(None::<String>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(ref inner) = req.description_blocks {
        match inner {
            None => query = query.bind(None::<serde_json::Value>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(start_at) = req.start_at {
        query = query.bind(start_at);
        // P30: vote_deadline도 같은 값으로 바인딩
        if schedule.schedule_type == ScheduleType::Group {
            query = query.bind(start_at);
        }
    }
    if let Some(ref inner) = req.end_at {
        match inner {
            None => query = query.bind(None::<chrono::DateTime<Utc>>),
            Some(v) => query = query.bind(Some(*v)),
        }
    }
    if let Some(ref inner) = req.location {
        match inner {
            None => {
                query = query.bind(None::<String>);
                query = query.bind(None::<String>);
                query = query.bind(None::<f64>);
                query = query.bind(None::<f64>);
            }
            Some(loc) => {
                query = query.bind(Some(loc.name.clone()));
                query = query.bind(loc.address.clone());
                query = query.bind(loc.latitude);
                query = query.bind(loc.longitude);
            }
        }
    }
    if let Some(min_p) = req.minimum_participants {
        query = query.bind(min_p);
    }
    if let Some(ref inner) = req.tracking_start_minutes_before {
        match inner {
            None => query = query.bind(None::<i16>),
            Some(v) => query = query.bind(Some(*v)),
        }
    }
    if let Some(ref inner) = req.image_urls {
        match inner {
            None => query = query.bind(None::<Vec<String>>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(ref inner) = req.reminder_minutes_before {
        match inner {
            None => query = query.bind(None::<i16>),
            Some(v) => query = query.bind(Some(*v)),
        }
    }

    // WHERE id = $N
    query = query.bind(schedule_id);

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    query
        .execute(&mut *tx)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if let Some(minimum_participants) = req.minimum_participants {
        let accepted_count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM schedule_votes \
             WHERE schedule_id = $1 AND status = 'accepted'::vote_status",
        )
        .bind(schedule_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        let is_confirmed = accepted_count.0 >= minimum_participants as i64;
        sqlx::query("UPDATE schedules SET is_confirmed = $1 WHERE id = $2")
            .bind(is_confirmed)
            .bind(schedule_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    }

    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn delete_schedule(
    pool: &PgPool,
    user_id: &str,
    schedule_id: Uuid,
) -> Result<(), AppError> {
    // 일정 조회
    let schedule = sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))?;

    // P11: 권한 확인 (update와 동일)
    match schedule.schedule_type {
        ScheduleType::Group => {
            if schedule.user_id != user_id {
                let group_id = schedule.group_id.ok_or_else(|| {
                    AppError::Internal("그룹 일정에 group_id가 없습니다".to_string())
                })?;

                let role_row = sqlx::query_as::<_, (String,)>(
                    "SELECT role::TEXT FROM group_members WHERE group_id = $1 AND user_id = $2",
                )
                .bind(group_id)
                .bind(user_id)
                .fetch_optional(pool)
                .await
                .map_err(|e| AppError::Internal(e.to_string()))?;

                match role_row {
                    Some((role,)) if role == "admin" => { /* OK: 그룹 관리자 */ }
                    _ => {
                        return Err(AppError::Forbidden(
                            "일정 호스트 또는 그룹 관리자만 삭제할 수 있습니다".to_string(),
                        ));
                    }
                }
            }
        }
        ScheduleType::Personal => {
            if schedule.user_id != user_id {
                return Err(AppError::Forbidden(
                    "본인의 일정만 삭제할 수 있습니다".to_string(),
                ));
            }
        }
    }

    // P13: start_at이 미래여야 함
    if schedule.start_at <= Utc::now() {
        return Err(AppError::PreconditionFailed(
            "이미 시작된 일정은 삭제할 수 없습니다".to_string(),
        ));
    }

    // DELETE (CASCADE removes schedule_votes)
    sqlx::query("DELETE FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn respond_schedule(
    pool: &PgPool,
    user_id: &str,
    schedule_id: Uuid,
    req: RespondScheduleRequest,
) -> Result<RespondScheduleResponse, AppError> {
    // status 검증
    let status = req.status.trim().to_lowercase();
    if status != "accepted" && status != "declined" && status != "pending" {
        return Err(AppError::BadRequest(
            "상태는 accepted, declined, pending 중 하나여야 합니다".to_string(),
        ));
    }

    // 일정 조회
    let schedule = sqlx::query_as::<_, Schedule>("SELECT * FROM schedules WHERE id = $1")
        .bind(schedule_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
        .ok_or_else(|| AppError::NotFound("일정을 찾을 수 없습니다".to_string()))?;

    // 그룹 일정만 응답 가능
    if schedule.schedule_type != ScheduleType::Group {
        return Err(AppError::BadRequest(
            "개인 일정에는 응답할 수 없습니다".to_string(),
        ));
    }

    let group_id = schedule
        .group_id
        .ok_or_else(|| AppError::Internal("그룹 일정에 group_id가 없습니다".to_string()))?;

    // 멤버십 확인
    let membership = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if membership.is_none() {
        return Err(AppError::Forbidden("그룹 멤버가 아닙니다".to_string()));
    }

    // 전환 감지: 이전 확정 상태 캡처
    let was_confirmed = schedule.is_confirmed.unwrap_or(false);

    // 트랜잭션
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if status == "pending" {
        // P28: pending이면 투표 삭제
        sqlx::query("DELETE FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2")
            .bind(schedule_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
    } else {
        // P27: 이미 같은 상태면 no-op
        let current_vote = sqlx::query_as::<_, (String,)>(
            "SELECT status::TEXT FROM schedule_votes WHERE schedule_id = $1 AND user_id = $2",
        )
        .bind(schedule_id)
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        let already_same = current_vote.as_ref().is_some_and(|(s,)| s == &status);

        if !already_same {
            // UPSERT: INSERT ON CONFLICT UPDATE
            sqlx::query(
                "INSERT INTO schedule_votes (schedule_id, user_id, status, responded_at) \
                 VALUES ($1, $2, $3::vote_status, NOW()) \
                 ON CONFLICT (schedule_id, user_id) \
                 DO UPDATE SET status = $3::vote_status, responded_at = NOW()",
            )
            .bind(schedule_id)
            .bind(user_id)
            .bind(&status)
            .execute(&mut *tx)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
        }
    }

    // P29: is_confirmed 재계산
    let minimum_participants = schedule.minimum_participants.unwrap_or(1);
    let accepted_count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM schedule_votes \
         WHERE schedule_id = $1 AND status = 'accepted'::vote_status",
    )
    .bind(schedule_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let new_is_confirmed = accepted_count.0 >= minimum_participants as i64;

    sqlx::query("UPDATE schedules SET is_confirmed = $1 WHERE id = $2")
        .bind(new_is_confirmed)
        .bind(schedule_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    // confirmed_schedule 빌드 (미확정 → 확정 전환 시에만)
    let confirmed_schedule = if !was_confirmed && new_is_confirmed && status == "accepted" {
        Some(CalendarSyncSchedule {
            id: schedule.id,
            title: schedule.title.clone(),
            emoji: schedule.emoji.clone(),
            start_at: schedule.start_at,
            end_at: schedule.end_at,
            location: schedule.location_name.clone(),
            group_id,
        })
    } else {
        None
    };

    Ok(RespondScheduleResponse {
        schedule_id,
        status,
        is_confirmed: new_is_confirmed,
        confirmed_schedule,
    })
}

// ============================================================
// 목록/조회
// ============================================================

pub async fn get_group_schedules(
    pool: &PgPool,
    user_id: &str,
    group_id: Uuid,
    query: GroupScheduleQuery,
) -> Result<PaginatedScheduleResponse, AppError> {
    // 그룹 존재 확인
    let group_exists = sqlx::query_as::<_, (Uuid,)>("SELECT id FROM groups WHERE id = $1")
        .bind(group_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if group_exists.is_none() {
        return Err(AppError::NotFound("그룹을 찾을 수 없습니다".to_string()));
    }

    // 멤버십 확인
    let membership = sqlx::query_as::<_, (String,)>(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
    )
    .bind(group_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    if membership.is_none() {
        return Err(AppError::Forbidden("그룹 멤버가 아닙니다".to_string()));
    }

    let status = query.status.as_deref().unwrap_or("active");
    let limit = query.limit.unwrap_or(20);
    let now = Utc::now();

    let schedules = match status {
        "past" => match query.cursor {
            Some(cursor) => sqlx::query_as::<_, Schedule>(
                "SELECT * FROM schedules \
                         WHERE group_id = $1 AND schedule_type = 'group' \
                           AND start_at < $2 AND start_at < $3 \
                         ORDER BY start_at DESC \
                         LIMIT $4",
            )
            .bind(group_id)
            .bind(now)
            .bind(cursor)
            .bind(limit)
            .fetch_all(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?,
            None => sqlx::query_as::<_, Schedule>(
                "SELECT * FROM schedules \
                         WHERE group_id = $1 AND schedule_type = 'group' \
                           AND start_at < $2 \
                         ORDER BY start_at DESC \
                         LIMIT $3",
            )
            .bind(group_id)
            .bind(now)
            .bind(limit)
            .fetch_all(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?,
        },
        _ => {
            // "active": start_at >= NOW(), ASC
            sqlx::query_as::<_, Schedule>(
                "SELECT * FROM schedules \
                 WHERE group_id = $1 AND schedule_type = 'group' \
                   AND start_at >= $2 \
                 ORDER BY start_at ASC \
                 LIMIT $3",
            )
            .bind(group_id)
            .bind(now)
            .bind(limit)
            .fetch_all(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
        }
    };

    // 각 일정의 투표 정보 조회
    let mut data: Vec<ScheduleResponse> = Vec::with_capacity(schedules.len());
    for schedule in &schedules {
        let votes = sqlx::query_as::<_, ScheduleVote>(
            "SELECT schedule_id, user_id, status, responded_at \
             FROM schedule_votes WHERE schedule_id = $1",
        )
        .bind(schedule.id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        data.push(build_schedule_response(schedule, votes));
    }

    // 커서: 반환된 항목이 limit개이면 마지막 항목의 start_at
    let cursor = if schedules.len() as i64 >= limit {
        schedules.last().map(|s| s.start_at)
    } else {
        None
    };

    Ok(PaginatedScheduleResponse { data, cursor })
}

pub async fn get_home_schedules(
    pool: &PgPool,
    user_id: &str,
    query: HomeQuery,
) -> Result<Vec<ScheduleResponse>, AppError> {
    let limit = query.limit.unwrap_or(20);
    let now = Utc::now();

    // 유저가 속한 그룹 ID 목록
    let group_ids: Vec<Uuid> =
        sqlx::query_as::<_, (Uuid,)>("SELECT group_id FROM group_members WHERE user_id = $1")
            .bind(user_id)
            .fetch_all(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
            .into_iter()
            .map(|(id,)| id)
            .collect();

    if group_ids.is_empty() {
        return Ok(Vec::new());
    }

    // 그룹일정 중 미래 일정 조회
    let schedules = sqlx::query_as::<_, Schedule>(
        "SELECT * FROM schedules \
         WHERE schedule_type = 'group' \
           AND group_id = ANY($1) \
           AND start_at >= $2 \
         ORDER BY start_at ASC \
         LIMIT $3",
    )
    .bind(&group_ids)
    .bind(now)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let mut result: Vec<ScheduleResponse> = Vec::with_capacity(schedules.len());
    for schedule in &schedules {
        let votes = sqlx::query_as::<_, ScheduleVote>(
            "SELECT schedule_id, user_id, status, responded_at \
             FROM schedule_votes WHERE schedule_id = $1",
        )
        .bind(schedule.id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        result.push(build_schedule_response(schedule, votes));
    }

    Ok(result)
}

pub async fn get_calendar_schedules(
    pool: &PgPool,
    user_id: &str,
    query: CalendarQuery,
) -> Result<CalendarResponse, AppError> {
    let accepted_only = query.accepted_only.unwrap_or(false);
    let timezone = parse_timezone(query.timezone.as_deref())?;

    // 유저가 속한 그룹 ID 목록
    let group_ids: Vec<Uuid> =
        sqlx::query_as::<_, (Uuid,)>("SELECT group_id FROM group_members WHERE user_id = $1")
            .bind(user_id)
            .fetch_all(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
            .into_iter()
            .map(|(id,)| id)
            .collect();

    // 그룹일정 조회 (date range)
    let group_schedules = if group_ids.is_empty() {
        Vec::new()
    } else if accepted_only {
        // 유저가 accepted한 일정만
        sqlx::query_as::<_, Schedule>(
            "SELECT s.* FROM schedules s \
             JOIN schedule_votes sv ON s.id = sv.schedule_id \
             WHERE s.schedule_type = 'group' \
               AND s.group_id = ANY($1) \
               AND s.start_at < $2 \
               AND COALESCE(s.end_at, s.start_at) >= $3 \
               AND sv.user_id = $4 \
               AND sv.status = 'accepted' \
             ORDER BY s.start_at ASC",
        )
        .bind(&group_ids)
        .bind(query.end)
        .bind(query.start)
        .bind(user_id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
    } else {
        sqlx::query_as::<_, Schedule>(
            "SELECT * FROM schedules \
             WHERE schedule_type = 'group' \
               AND group_id = ANY($1) \
               AND start_at < $2 \
               AND COALESCE(end_at, start_at) >= $3 \
             ORDER BY start_at ASC",
        )
        .bind(&group_ids)
        .bind(query.end)
        .bind(query.start)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
    };

    // 개인일정 조회 (date range)
    let personal_schedules = sqlx::query_as::<_, Schedule>(
        "SELECT * FROM schedules \
         WHERE schedule_type = 'personal' \
           AND user_id = $1 \
           AND start_at < $2 \
           AND COALESCE(end_at, start_at) >= $3 \
         ORDER BY start_at ASC",
    )
    .bind(user_id)
    .bind(query.end)
    .bind(query.start)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // ScheduleResponse 빌드
    let mut schedules_response: Vec<ScheduleResponse> = Vec::new();

    for schedule in &group_schedules {
        let votes = sqlx::query_as::<_, ScheduleVote>(
            "SELECT schedule_id, user_id, status, responded_at \
             FROM schedule_votes WHERE schedule_id = $1",
        )
        .bind(schedule.id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        schedules_response.push(build_schedule_response(schedule, votes));
    }

    for schedule in &personal_schedules {
        schedules_response.push(build_schedule_response(schedule, Vec::new()));
    }

    // 반복일정 확장
    let recurring_schedules = sqlx::query_as::<_, RecurringSchedule>(
        "SELECT id, user_id, title, emoji, description, \
         start_time_hour, start_time_minute, end_time_hour, end_time_minute, \
         location_name, location_address, location_latitude, location_longitude, \
         reminder_minutes_before, frequency AS \"frequency: RecurrenceFrequency\", \
         days_of_week, day_of_month, \
         series_start_date, series_end_date, excluded_dates, overrides, \
         created_at, updated_at \
         FROM recurring_schedules WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let range_start = query.start.with_timezone(&timezone).date_naive();
    let range_end = query.end.with_timezone(&timezone).date_naive();

    let mut recurring_instances: Vec<RecurringInstance> = Vec::new();
    for rs in &recurring_schedules {
        let mut instances = expand_recurring_in_range(rs, range_start, range_end, timezone);
        recurring_instances.append(&mut instances);
    }

    recurring_instances.sort_by(|a, b| {
        a.date
            .cmp(&b.date)
            .then(a.start_time.hour.cmp(&b.start_time.hour))
            .then(a.start_time.minute.cmp(&b.start_time.minute))
    });

    Ok(CalendarResponse {
        schedules: schedules_response,
        recurring_instances,
    })
}

pub async fn get_calendar_sync(
    pool: &PgPool,
    user_id: &str,
) -> Result<Vec<CalendarSyncSchedule>, AppError> {
    let now = Utc::now();

    // 확정된 미래 그룹일정 중 유저가 accepted한 것만
    let rows = sqlx::query_as::<_, Schedule>(
        "SELECT s.* FROM schedules s \
         JOIN schedule_votes sv ON s.id = sv.schedule_id \
         WHERE s.schedule_type = 'group' \
           AND s.is_confirmed = TRUE \
           AND sv.user_id = $1 \
           AND sv.status = 'accepted' \
           AND s.start_at >= $2 \
         ORDER BY s.start_at ASC \
         LIMIT 50",
    )
    .bind(user_id)
    .bind(now)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let result: Vec<CalendarSyncSchedule> = rows
        .into_iter()
        .map(|s| {
            let group_id = s.group_id.unwrap_or_default();
            CalendarSyncSchedule {
                id: s.id,
                title: s.title,
                emoji: s.emoji,
                start_at: s.start_at,
                end_at: s.end_at,
                location: s.location_name,
                group_id,
            }
        })
        .collect();

    Ok(result)
}

pub async fn check_conflicts(
    pool: &PgPool,
    user_id: &str,
    req: CheckConflictsRequest,
) -> Result<Vec<ScheduleConflict>, AppError> {
    let min_gap = Duration::minutes(req.min_gap_minutes.unwrap_or(0) as i64);
    let timezone = parse_timezone(req.timezone.as_deref())?;
    let exclude_ids = req.exclude_ids.unwrap_or_default();
    let proposed_end = effective_end_at(req.start_at, req.end_at);

    // 검색 범위를 min_gap만큼 확장
    let search_start = req.start_at - min_gap;
    let search_end = proposed_end + min_gap;

    // 유저의 accepted 그룹일정 조회
    let group_schedules = sqlx::query_as::<_, Schedule>(
        "SELECT s.* FROM schedules s \
         JOIN schedule_votes sv ON s.id = sv.schedule_id \
         WHERE sv.user_id = $1 \
           AND sv.status = 'accepted' \
           AND s.schedule_type = 'group' \
           AND s.start_at <= $2 \
           AND COALESCE(s.end_at, s.start_at) >= $3 \
         ORDER BY s.start_at ASC",
    )
    .bind(user_id)
    .bind(search_end)
    .bind(search_start)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    // 유저의 개인일정 조회
    let personal_schedules = sqlx::query_as::<_, Schedule>(
        "SELECT * FROM schedules \
         WHERE user_id = $1 \
           AND schedule_type = 'personal' \
           AND start_at <= $2 \
           AND COALESCE(end_at, start_at) >= $3 \
         ORDER BY start_at ASC",
    )
    .bind(user_id)
    .bind(search_end)
    .bind(search_start)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let all_schedules: Vec<&Schedule> = group_schedules
        .iter()
        .chain(personal_schedules.iter())
        .filter(|s| !exclude_ids.contains(&s.id))
        .collect();

    let mut conflicts: Vec<ScheduleConflict> = Vec::new();

    for existing in &all_schedules {
        let is_overlapping = ranges_overlap(
            req.start_at,
            Some(proposed_end),
            existing.start_at,
            Some(effective_end_at(existing.start_at, existing.end_at)),
        );
        // overlap 계산
        let overlap_minutes = calculate_overlap_minutes(
            req.start_at,
            Some(proposed_end),
            existing.start_at,
            Some(effective_end_at(existing.start_at, existing.end_at)),
        );

        // gap 계산 (겹치지 않는 경우)
        let gap_minutes = if is_overlapping {
            0
        } else {
            calculate_gap_minutes(
                req.start_at,
                Some(proposed_end),
                existing.start_at,
                Some(effective_end_at(existing.start_at, existing.end_at)),
            )
        };

        let min_gap_minutes_val = req.min_gap_minutes.unwrap_or(0) as i64;

        // 겹치거나, gap이 min_gap 미만이면 충돌
        if is_overlapping || gap_minutes < min_gap_minutes_val {
            let conflict_type = match existing.schedule_type {
                ScheduleType::Group => "group",
                ScheduleType::Personal => "personal",
            };

            conflicts.push(ScheduleConflict {
                id: existing.id.to_string(),
                conflict_type: conflict_type.to_string(),
                title: existing.title.clone(),
                emoji: existing.emoji.clone(),
                start_at: existing.start_at,
                end_at: existing.end_at,
                overlap_minutes,
                gap_minutes,
            });
        }
    }

    let recurring_schedules = sqlx::query_as::<_, RecurringSchedule>(
        "SELECT id, user_id, title, emoji, description, \
         start_time_hour, start_time_minute, end_time_hour, end_time_minute, \
         location_name, location_address, location_latitude, location_longitude, \
         reminder_minutes_before, frequency AS \"frequency: RecurrenceFrequency\", \
         days_of_week, day_of_month, \
         series_start_date, series_end_date, excluded_dates, overrides, \
         created_at, updated_at \
         FROM recurring_schedules WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let recurring_range_start = search_start.with_timezone(&timezone).date_naive();
    let recurring_range_end = search_end.with_timezone(&timezone).date_naive();

    for recurring_schedule in &recurring_schedules {
        for instance in expand_recurring_in_range(
            recurring_schedule,
            recurring_range_start,
            recurring_range_end,
            timezone,
        ) {
            let instance_start =
                resolve_local_datetime(timezone, instance.date, &instance.start_time)?;
            let instance_end = match instance.end_time.as_ref() {
                Some(end_time) => {
                    let end_at = resolve_local_datetime(timezone, instance.date, end_time)?;
                    Some(if end_at <= instance_start {
                        end_at + Duration::days(1)
                    } else {
                        end_at
                    })
                }
                None => None,
            };
            let is_overlapping = ranges_overlap(
                req.start_at,
                Some(proposed_end),
                instance_start,
                Some(effective_end_at(instance_start, instance_end)),
            );
            let overlap_minutes = calculate_overlap_minutes(
                req.start_at,
                Some(proposed_end),
                instance_start,
                Some(effective_end_at(instance_start, instance_end)),
            );
            let gap_minutes = if is_overlapping {
                0
            } else {
                calculate_gap_minutes(
                    req.start_at,
                    Some(proposed_end),
                    instance_start,
                    Some(effective_end_at(instance_start, instance_end)),
                )
            };
            let min_gap_minutes_val = req.min_gap_minutes.unwrap_or(0) as i64;

            if is_overlapping || gap_minutes < min_gap_minutes_val {
                conflicts.push(ScheduleConflict {
                    id: format!("{}:{}", instance.recurring_schedule_id, instance.date),
                    conflict_type: "recurring".to_string(),
                    title: instance.title,
                    emoji: instance.emoji,
                    start_at: instance_start,
                    end_at: instance_end,
                    overlap_minutes,
                    gap_minutes,
                });
            }
        }
    }

    // overlap 내림차순, gap 오름차순 정렬
    conflicts.sort_by(|a, b| {
        b.overlap_minutes
            .cmp(&a.overlap_minutes)
            .then(a.gap_minutes.cmp(&b.gap_minutes))
    });

    Ok(conflicts)
}

// ============================================================
// 충돌 계산 헬퍼
// ============================================================

fn ranges_overlap(
    start_a: chrono::DateTime<Utc>,
    end_a: Option<chrono::DateTime<Utc>>,
    start_b: chrono::DateTime<Utc>,
    end_b: Option<chrono::DateTime<Utc>>,
) -> bool {
    let end_a = effective_end_at(start_a, end_a);
    let end_b = effective_end_at(start_b, end_b);

    if start_a == end_a && start_b == end_b {
        start_a == start_b
    } else if start_a == end_a {
        start_a >= start_b && start_a < end_b
    } else if start_b == end_b {
        start_b >= start_a && start_b < end_a
    } else {
        start_a < end_b && end_a > start_b
    }
}

/// 두 시간 범위의 겹침 시간(분)을 계산
fn calculate_overlap_minutes(
    start_a: chrono::DateTime<Utc>,
    end_a: Option<chrono::DateTime<Utc>>,
    start_b: chrono::DateTime<Utc>,
    end_b: Option<chrono::DateTime<Utc>>,
) -> i64 {
    let end_a = effective_end_at(start_a, end_a);
    let end_b = effective_end_at(start_b, end_b);

    let overlap_start = start_a.max(start_b);
    let overlap_end = end_a.min(end_b);

    if overlap_end > overlap_start {
        (overlap_end - overlap_start).num_minutes()
    } else {
        0
    }
}

/// 두 시간 범위 사이의 간격(분)을 계산 (겹치지 않는 경우)
fn calculate_gap_minutes(
    start_a: chrono::DateTime<Utc>,
    end_a: Option<chrono::DateTime<Utc>>,
    start_b: chrono::DateTime<Utc>,
    end_b: Option<chrono::DateTime<Utc>>,
) -> i64 {
    let end_a = effective_end_at(start_a, end_a);
    let end_b = effective_end_at(start_b, end_b);

    if end_a <= start_b {
        (start_b - end_a).num_minutes()
    } else if end_b <= start_a {
        (start_a - end_b).num_minutes()
    } else {
        0
    }
}

// ============================================================
// 반복일정 확장 헬퍼
// ============================================================

/// 반복일정을 지정된 날짜 범위 내의 인스턴스로 확장
fn expand_recurring_in_range(
    schedule: &RecurringSchedule,
    range_start: NaiveDate,
    range_end: NaiveDate,
    _timezone: Tz,
) -> Vec<RecurringInstance> {
    let mut instances = Vec::new();

    // 시리즈 시작일과 범위 시작일 중 더 늦은 날짜부터
    let effective_start = schedule.series_start_date.max(range_start);
    // 시리즈 종료일과 범위 종료일 중 더 이른 날짜까지
    let effective_end = match schedule.series_end_date {
        Some(series_end) => series_end.min(range_end),
        None => range_end,
    };

    if effective_start > effective_end {
        return instances;
    }

    let excluded_dates: Vec<NaiveDate> = schedule.excluded_dates.clone().unwrap_or_default();

    // 오버라이드 파싱: current app payload uses camelCase, legacy/service payload may use snake_case.
    let overrides_map: serde_json::Map<String, serde_json::Value> = schedule
        .overrides
        .as_ref()
        .and_then(|v| v.as_object().cloned())
        .unwrap_or_default();

    let mut current = effective_start;
    while current <= effective_end {
        let should_include = match schedule.frequency {
            RecurrenceFrequency::Daily => true,
            RecurrenceFrequency::Weekly => {
                if let Some(ref days) = schedule.days_of_week {
                    let weekday = current.weekday().number_from_sunday() as i16;
                    days.contains(&weekday)
                } else {
                    false
                }
            }
            RecurrenceFrequency::Monthly => {
                if let Some(day_of_month) = schedule.day_of_month {
                    current.day() as i16 == day_of_month
                } else {
                    false
                }
            }
        };

        if should_include && !excluded_dates.contains(&current) {
            let date_str = current.format("%Y-%m-%d").to_string();
            let override_entry = overrides_map.get(&date_str);

            // 오버라이드에서 cancelled 확인
            let is_cancelled = override_entry
                .and_then(|v| json_get(v, &["isCancelled", "cancelled"]))
                .and_then(|v| v.as_bool())
                .unwrap_or(false);

            if !is_cancelled {
                // 오버라이드된 시간 또는 기본 시간
                let start_time = parse_override_time(override_entry, &["startTime", "start_time"])
                    .unwrap_or(TimeComponents {
                        hour: schedule.start_time_hour,
                        minute: schedule.start_time_minute,
                    });

                let end_time = parse_override_time(override_entry, &["endTime", "end_time"])
                    .or_else(|| {
                        schedule.end_time_hour.map(|h| TimeComponents {
                            hour: h,
                            minute: schedule.end_time_minute.unwrap_or(0),
                        })
                    });

                let location = parse_override_location(override_entry).or_else(|| {
                    schedule
                        .location_name
                        .as_ref()
                        .map(|name| LocationResponse {
                            name: name.clone(),
                            address: schedule.location_address.clone(),
                            latitude: schedule.location_latitude,
                            longitude: schedule.location_longitude,
                        })
                });

                let title = override_entry
                    .and_then(|v| v.get("title"))
                    .and_then(|v| v.as_str())
                    .map(|v| v.to_string())
                    .unwrap_or_else(|| schedule.title.clone());

                instances.push(RecurringInstance {
                    recurring_schedule_id: schedule.id,
                    title,
                    emoji: schedule.emoji.clone(),
                    date: current,
                    start_time,
                    end_time,
                    location,
                });
            }
        }

        // 다음 날로 이동 (overflow-safe)
        match current.succ_opt() {
            Some(next) => current = next,
            None => break,
        }
    }

    instances
}

// ============================================================
// 반복일정
// ============================================================

pub async fn create_recurring_schedule(
    pool: &PgPool,
    user_id: &str,
    req: CreateRecurringScheduleRequest,
) -> Result<CreateRecurringScheduleResponse, AppError> {
    // 제목 검증: trim 후 빈 문자열이면 400
    let title = req.title.trim().to_string();
    if title.is_empty() {
        return Err(AppError::BadRequest(
            "제목은 비어있을 수 없습니다".to_string(),
        ));
    }

    // frequency별 상호배타 필드 검증
    match req.frequency {
        RecurrenceFrequency::Daily => {
            if req.days_of_week.is_some() {
                return Err(AppError::BadRequest(
                    "daily 빈도에서는 days_of_week를 설정할 수 없습니다".to_string(),
                ));
            }
            if req.day_of_month.is_some() {
                return Err(AppError::BadRequest(
                    "daily 빈도에서는 day_of_month를 설정할 수 없습니다".to_string(),
                ));
            }
        }
        RecurrenceFrequency::Weekly => {
            match &req.days_of_week {
                None => {
                    return Err(AppError::BadRequest(
                        "weekly 빈도에서는 days_of_week가 필요합니다".to_string(),
                    ));
                }
                Some(days) => {
                    if days.is_empty() {
                        return Err(AppError::BadRequest(
                            "days_of_week는 비어있을 수 없습니다".to_string(),
                        ));
                    }
                    // 서비스 레벨 검증: 1-7 범위
                    if days.iter().any(|&d| !(1..=7).contains(&d)) {
                        return Err(AppError::BadRequest(
                            "days_of_week 값은 1-7 범위여야 합니다".to_string(),
                        ));
                    }
                }
            }
            if req.day_of_month.is_some() {
                return Err(AppError::BadRequest(
                    "weekly 빈도에서는 day_of_month를 설정할 수 없습니다".to_string(),
                ));
            }
        }
        RecurrenceFrequency::Monthly => {
            if req.days_of_week.is_some() {
                return Err(AppError::BadRequest(
                    "monthly 빈도에서는 days_of_week를 설정할 수 없습니다".to_string(),
                ));
            }
            match req.day_of_month {
                None => {
                    return Err(AppError::BadRequest(
                        "monthly 빈도에서는 day_of_month가 필요합니다".to_string(),
                    ));
                }
                Some(day) => {
                    if !(1..=31).contains(&day) {
                        return Err(AppError::BadRequest(
                            "day_of_month는 1-31 범위여야 합니다".to_string(),
                        ));
                    }
                }
            }
        }
    }

    // start_time 검증
    if !(0..=23).contains(&req.start_time.hour) || !(0..=59).contains(&req.start_time.minute) {
        return Err(AppError::BadRequest(
            "start_time이 유효하지 않습니다".to_string(),
        ));
    }

    // end_time 검증 (있는 경우)
    if let Some(ref end_time) = req.end_time {
        if !(0..=23).contains(&end_time.hour) || !(0..=59).contains(&end_time.minute) {
            return Err(AppError::BadRequest(
                "end_time이 유효하지 않습니다".to_string(),
            ));
        }
    }

    // series_end_date >= series_start_date 검증
    if let Some(end_date) = req.series_end_date {
        if end_date < req.series_start_date {
            return Err(AppError::BadRequest(
                "series_end_date는 series_start_date 이후여야 합니다".to_string(),
            ));
        }
    }

    // location 분해
    let (loc_name, loc_address, loc_lat, loc_lng) = match &req.location {
        Some(loc) => (
            Some(loc.name.clone()),
            loc.address.clone(),
            loc.latitude,
            loc.longitude,
        ),
        None => (None, None, None, None),
    };

    // end_time 분해
    let (end_hour, end_minute) = match &req.end_time {
        Some(t) => (Some(t.hour), Some(t.minute)),
        None => (None, None),
    };

    // days_of_week를 &[i16]로 변환
    let days_of_week_vec = req.days_of_week.unwrap_or_default();
    let days_of_week_slice: Option<&[i16]> = if days_of_week_vec.is_empty() {
        None
    } else {
        Some(&days_of_week_vec)
    };

    let row = sqlx::query_as::<_, (Uuid, chrono::DateTime<chrono::Utc>)>(
        "INSERT INTO recurring_schedules \
         (user_id, title, emoji, description, \
          start_time_hour, start_time_minute, end_time_hour, end_time_minute, \
          location_name, location_address, location_latitude, location_longitude, \
          reminder_minutes_before, frequency, days_of_week, day_of_month, \
          series_start_date, series_end_date) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, \
                 $14::recurrence_frequency, $15, $16, $17, $18) \
         RETURNING id, created_at",
    )
    .bind(user_id)
    .bind(&title)
    .bind(&req.emoji)
    .bind(&req.description)
    .bind(req.start_time.hour)
    .bind(req.start_time.minute)
    .bind(end_hour)
    .bind(end_minute)
    .bind(&loc_name)
    .bind(&loc_address)
    .bind(loc_lat)
    .bind(loc_lng)
    .bind(req.reminder_minutes_before)
    .bind(&req.frequency)
    .bind(days_of_week_slice)
    .bind(req.day_of_month)
    .bind(req.series_start_date)
    .bind(req.series_end_date)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(CreateRecurringScheduleResponse {
        id: row.0,
        created_at: row.1,
    })
}

pub async fn get_recurring_schedules(
    pool: &PgPool,
    user_id: &str,
) -> Result<Vec<RecurringSchedule>, AppError> {
    let rows = sqlx::query_as::<_, RecurringSchedule>(
        "SELECT id, user_id, title, emoji, description, \
         start_time_hour, start_time_minute, end_time_hour, end_time_minute, \
         location_name, location_address, location_latitude, location_longitude, \
         reminder_minutes_before, frequency AS \"frequency: RecurrenceFrequency\", \
         days_of_week, day_of_month, \
         series_start_date, series_end_date, excluded_dates, overrides, \
         created_at, updated_at \
         FROM recurring_schedules WHERE user_id = $1 \
         ORDER BY created_at DESC",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(rows)
}

pub async fn update_recurring_schedule(
    pool: &PgPool,
    user_id: &str,
    id: Uuid,
    req: UpdateRecurringScheduleRequest,
) -> Result<(), AppError> {
    // 존재 확인
    let existing =
        sqlx::query_as::<_, (String,)>("SELECT user_id FROM recurring_schedules WHERE id = $1")
            .bind(id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
            .ok_or_else(|| AppError::NotFound("반복일정을 찾을 수 없습니다".to_string()))?;

    // 소유권 확인
    if existing.0 != user_id {
        return Err(AppError::Forbidden(
            "본인의 반복일정만 수정할 수 있습니다".to_string(),
        ));
    }

    // 필드 검증
    if let Some(ref title) = req.title {
        let trimmed = title.trim();
        if trimmed.is_empty() {
            return Err(AppError::BadRequest(
                "제목은 비어있을 수 없습니다".to_string(),
            ));
        }
    }

    if let Some(ref start_time) = req.start_time {
        if !(0..=23).contains(&start_time.hour) || !(0..=59).contains(&start_time.minute) {
            return Err(AppError::BadRequest(
                "start_time이 유효하지 않습니다".to_string(),
            ));
        }
    }

    if let Some(Some(ref end_time)) = req.end_time {
        if !(0..=23).contains(&end_time.hour) || !(0..=59).contains(&end_time.minute) {
            return Err(AppError::BadRequest(
                "end_time이 유효하지 않습니다".to_string(),
            ));
        }
    }

    if let Some(ref frequency) = req.frequency {
        match frequency {
            RecurrenceFrequency::Daily => {
                // days_of_week가 업데이트에 포함되어 있고 값이 있으면 에러
                if let Some(Some(ref _days)) = req.days_of_week {
                    return Err(AppError::BadRequest(
                        "daily 빈도에서는 days_of_week를 설정할 수 없습니다".to_string(),
                    ));
                }
                if let Some(Some(_)) = req.day_of_month {
                    return Err(AppError::BadRequest(
                        "daily 빈도에서는 day_of_month를 설정할 수 없습니다".to_string(),
                    ));
                }
            }
            RecurrenceFrequency::Weekly => {
                if let Some(ref inner) = req.days_of_week {
                    match inner {
                        None => {
                            return Err(AppError::BadRequest(
                                "weekly 빈도에서는 days_of_week가 필요합니다".to_string(),
                            ));
                        }
                        Some(days) => {
                            if days.is_empty() {
                                return Err(AppError::BadRequest(
                                    "days_of_week는 비어있을 수 없습니다".to_string(),
                                ));
                            }
                            if days.iter().any(|&d| !(1..=7).contains(&d)) {
                                return Err(AppError::BadRequest(
                                    "days_of_week 값은 1-7 범위여야 합니다".to_string(),
                                ));
                            }
                        }
                    }
                }
                if let Some(Some(_)) = req.day_of_month {
                    return Err(AppError::BadRequest(
                        "weekly 빈도에서는 day_of_month를 설정할 수 없습니다".to_string(),
                    ));
                }
            }
            RecurrenceFrequency::Monthly => {
                if let Some(Some(ref _days)) = req.days_of_week {
                    return Err(AppError::BadRequest(
                        "monthly 빈도에서는 days_of_week를 설정할 수 없습니다".to_string(),
                    ));
                }
                if let Some(ref inner) = req.day_of_month {
                    match inner {
                        None => {
                            return Err(AppError::BadRequest(
                                "monthly 빈도에서는 day_of_month가 필요합니다".to_string(),
                            ));
                        }
                        Some(day) => {
                            if !(1..=31).contains(day) {
                                return Err(AppError::BadRequest(
                                    "day_of_month는 1-31 범위여야 합니다".to_string(),
                                ));
                            }
                        }
                    }
                }
            }
        }
    }

    // 동적 UPDATE 빌드
    let mut set_clauses: Vec<String> = Vec::new();
    let mut param_index = 1u32;

    if req.title.is_some() {
        set_clauses.push(format!("title = ${param_index}"));
        param_index += 1;
    }
    if req.emoji.is_some() {
        set_clauses.push(format!("emoji = ${param_index}"));
        param_index += 1;
    }
    if req.description.is_some() {
        set_clauses.push(format!("description = ${param_index}"));
        param_index += 1;
    }
    if req.start_time.is_some() {
        set_clauses.push(format!("start_time_hour = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("start_time_minute = ${param_index}"));
        param_index += 1;
    }
    if req.end_time.is_some() {
        set_clauses.push(format!("end_time_hour = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("end_time_minute = ${param_index}"));
        param_index += 1;
    }
    if req.location.is_some() {
        set_clauses.push(format!("location_name = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_address = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_latitude = ${param_index}"));
        param_index += 1;
        set_clauses.push(format!("location_longitude = ${param_index}"));
        param_index += 1;
    }
    if req.reminder_minutes_before.is_some() {
        set_clauses.push(format!("reminder_minutes_before = ${param_index}"));
        param_index += 1;
    }
    if req.frequency.is_some() {
        set_clauses.push(format!("frequency = ${param_index}::recurrence_frequency"));
        param_index += 1;
    }
    if req.days_of_week.is_some() {
        set_clauses.push(format!("days_of_week = ${param_index}"));
        param_index += 1;
    }
    if req.day_of_month.is_some() {
        set_clauses.push(format!("day_of_month = ${param_index}"));
        param_index += 1;
    }
    if req.series_start_date.is_some() {
        set_clauses.push(format!("series_start_date = ${param_index}"));
        param_index += 1;
    }
    if req.series_end_date.is_some() {
        set_clauses.push(format!("series_end_date = ${param_index}"));
        param_index += 1;
    }
    if req.excluded_dates.is_some() {
        set_clauses.push(format!("excluded_dates = ${param_index}"));
        param_index += 1;
    }
    if req.overrides.is_some() {
        set_clauses.push(format!("overrides = ${param_index}"));
        param_index += 1;
    }

    if set_clauses.is_empty() {
        return Ok(());
    }

    set_clauses.push("updated_at = NOW()".to_string());

    let sql = format!(
        "UPDATE recurring_schedules SET {} WHERE id = ${param_index}",
        set_clauses.join(", "),
    );

    let mut query = sqlx::query(&sql);

    // 바인딩 순서대로
    if let Some(ref title) = req.title {
        query = query.bind(title.trim().to_string());
    }
    if let Some(ref inner) = req.emoji {
        match inner {
            None => query = query.bind(None::<String>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(ref inner) = req.description {
        match inner {
            None => query = query.bind(None::<String>),
            Some(v) => query = query.bind(Some(v.clone())),
        }
    }
    if let Some(ref start_time) = req.start_time {
        query = query.bind(start_time.hour);
        query = query.bind(start_time.minute);
    }
    if let Some(ref inner) = req.end_time {
        match inner {
            None => {
                query = query.bind(None::<i16>);
                query = query.bind(None::<i16>);
            }
            Some(t) => {
                query = query.bind(Some(t.hour));
                query = query.bind(Some(t.minute));
            }
        }
    }
    if let Some(ref inner) = req.location {
        match inner {
            None => {
                query = query.bind(None::<String>);
                query = query.bind(None::<String>);
                query = query.bind(None::<f64>);
                query = query.bind(None::<f64>);
            }
            Some(loc) => {
                query = query.bind(Some(loc.name.clone()));
                query = query.bind(loc.address.clone());
                query = query.bind(loc.latitude);
                query = query.bind(loc.longitude);
            }
        }
    }
    if let Some(ref inner) = req.reminder_minutes_before {
        match inner {
            None => query = query.bind(None::<i16>),
            Some(v) => query = query.bind(Some(*v)),
        }
    }
    if let Some(ref frequency) = req.frequency {
        query = query.bind(frequency);
    }
    if let Some(ref inner) = req.days_of_week {
        match inner {
            None => query = query.bind(None::<Vec<i16>>),
            Some(days) => query = query.bind(Some(days.clone())),
        }
    }
    if let Some(ref inner) = req.day_of_month {
        match inner {
            None => query = query.bind(None::<i16>),
            Some(v) => query = query.bind(Some(*v)),
        }
    }
    if let Some(ref date) = req.series_start_date {
        query = query.bind(*date);
    }
    if let Some(ref inner) = req.series_end_date {
        match inner {
            None => query = query.bind(None::<chrono::NaiveDate>),
            Some(d) => query = query.bind(Some(*d)),
        }
    }
    if let Some(ref dates) = req.excluded_dates {
        query = query.bind(dates.clone());
    }
    if let Some(ref overrides_val) = req.overrides {
        query = query.bind(overrides_val.clone());
    }

    query = query.bind(id);

    query
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn delete_recurring_schedule(
    pool: &PgPool,
    user_id: &str,
    id: Uuid,
) -> Result<(), AppError> {
    // 존재 확인
    let existing =
        sqlx::query_as::<_, (String,)>("SELECT user_id FROM recurring_schedules WHERE id = $1")
            .bind(id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?
            .ok_or_else(|| AppError::NotFound("반복일정을 찾을 수 없습니다".to_string()))?;

    // 소유권 확인
    if existing.0 != user_id {
        return Err(AppError::Forbidden(
            "본인의 반복일정만 삭제할 수 있습니다".to_string(),
        ));
    }

    sqlx::query("DELETE FROM recurring_schedules WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

// ============================================================
// AI 일정 추출
// ============================================================

pub async fn extract_schedule(
    _pool: &PgPool,
    _user_id: &str,
    req: ExtractScheduleRequest,
) -> Result<ExtractScheduleResponse, AppError> {
    if req.text.is_none() && req.image_base64.is_none() {
        return Err(AppError::BadRequest(
            "text 또는 image_base64 중 하나는 필요합니다".to_string(),
        ));
    }

    if let Some(text) = &req.text {
        if text.chars().count() > 2000 {
            return Err(AppError::BadRequest(
                "text는 2000자 이하여야 합니다".to_string(),
            ));
        }
    }

    parse_timezone(req.timezone.as_deref())?;

    Err(AppError::BadRequest(
        "일정 추출 기능은 아직 지원되지 않습니다".to_string(),
    ))
}
