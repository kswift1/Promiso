use std::collections::{HashMap, HashSet};

use sqlx::PgPool;
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::notification::*;

// ============================================================
// 디바이스 관리
// ============================================================

pub async fn upsert_device(
    pool: &PgPool,
    user_uid: &str,
    req: UpsertDeviceRequest,
) -> Result<DeviceResponse, AppError> {
    // 유저 존재 확인
    let user_exists: Option<(String,)> =
        sqlx::query_as("SELECT id FROM users WHERE id = $1")
            .bind(user_uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

    if user_exists.is_none() {
        return Err(AppError::NotFound("사용자를 찾을 수 없습니다".to_string()));
    }

    // Risk 3: 같은 fcm_token을 가진 다른 유저의 row를 삭제 (소유권 이전)
    sqlx::query("DELETE FROM devices WHERE fcm_token = $1 AND user_id != $2")
        .bind(&req.fcm_token)
        .bind(user_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    let platform = req.platform.unwrap_or_else(|| "ios".to_string());

    let device = sqlx::query_as::<_, Device>(
        "INSERT INTO devices (user_id, device_id, fcm_token, platform, push_to_start_token, live_activity_push_token) \
         VALUES ($1, $2, $3, $4, $5, $6) \
         ON CONFLICT (user_id, device_id) DO UPDATE SET \
           fcm_token = EXCLUDED.fcm_token, \
           platform = EXCLUDED.platform, \
           push_to_start_token = EXCLUDED.push_to_start_token, \
           live_activity_push_token = EXCLUDED.live_activity_push_token, \
           updated_at = NOW(), \
           last_active_at = NOW() \
         RETURNING *",
    )
    .bind(user_uid)
    .bind(&req.device_id)
    .bind(&req.fcm_token)
    .bind(&platform)
    .bind(&req.push_to_start_token)
    .bind(&req.live_activity_push_token)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(DeviceResponse {
        device_id: device.device_id,
        fcm_token: device.fcm_token,
        platform: device.platform,
        last_active_at: device.last_active_at,
        created_at: device.created_at,
    })
}

pub async fn delete_device(
    pool: &PgPool,
    user_uid: &str,
    device_id: &str,
) -> Result<(), AppError> {
    let result = sqlx::query("DELETE FROM devices WHERE user_id = $1 AND device_id = $2")
        .bind(user_uid)
        .bind(device_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("디바이스를 찾을 수 없습니다".to_string()));
    }

    Ok(())
}

pub async fn delete_all_devices(pool: &PgPool, user_uid: &str) -> Result<(), AppError> {
    sqlx::query("DELETE FROM devices WHERE user_id = $1")
        .bind(user_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

// ============================================================
// 알림 CRUD
// ============================================================

pub async fn get_notifications(
    pool: &PgPool,
    user_uid: &str,
    query: GetNotificationsQuery,
) -> Result<Vec<NotificationResponse>, AppError> {
    let limit = query.limit.unwrap_or(20);

    let notifications = if let Some(before) = query.before {
        sqlx::query_as::<_, Notification>(
            "SELECT * FROM notifications WHERE user_id = $1 AND created_at < $2 \
             ORDER BY created_at DESC LIMIT $3",
        )
        .bind(user_uid)
        .bind(before)
        .bind(limit)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
    } else {
        sqlx::query_as::<_, Notification>(
            "SELECT * FROM notifications WHERE user_id = $1 \
             ORDER BY created_at DESC LIMIT $2",
        )
        .bind(user_uid)
        .bind(limit)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
    };

    let responses = notifications
        .into_iter()
        .map(|n| {
            let data = n.data.and_then(|v| {
                serde_json::from_value::<HashMap<String, String>>(v).ok()
            });
            NotificationResponse {
                id: n.id,
                notification_type: n.notification_type,
                title: n.title,
                body: n.body,
                schedule_id: n.schedule_id,
                group_id: n.group_id,
                related_user_id: n.related_user_id,
                is_read: n.is_read,
                created_at: n.created_at,
                read_at: n.read_at,
                data,
            }
        })
        .collect();

    Ok(responses)
}

pub async fn get_unread_count(
    pool: &PgPool,
    user_uid: &str,
) -> Result<UnreadCountResponse, AppError> {
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE",
    )
    .bind(user_uid)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(UnreadCountResponse { count: count.0 })
}

pub async fn mark_as_read(
    pool: &PgPool,
    user_uid: &str,
    notification_id: Uuid,
) -> Result<(), AppError> {
    // 소유권 확인
    let owner: Option<(String,)> =
        sqlx::query_as("SELECT user_id FROM notifications WHERE id = $1")
            .bind(notification_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

    match owner {
        None => return Err(AppError::NotFound("알림을 찾을 수 없습니다".to_string())),
        Some((uid,)) if uid != user_uid => {
            return Err(AppError::Forbidden(
                "다른 사용자의 알림입니다".to_string(),
            ));
        }
        _ => {}
    }

    sqlx::query("UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE id = $1")
        .bind(notification_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn mark_all_as_read(pool: &PgPool, user_uid: &str) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE notifications SET is_read = TRUE, read_at = NOW() \
         WHERE user_id = $1 AND is_read = FALSE",
    )
    .bind(user_uid)
    .execute(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn delete_notifications(
    pool: &PgPool,
    user_uid: &str,
    req: DeleteNotificationsRequest,
) -> Result<(), AppError> {
    if req.notification_ids.is_empty() {
        return Ok(());
    }

    // 소유권 확인: 모든 알림이 현재 유저의 것인지 확인
    let owners: Vec<(Uuid, String)> = sqlx::query_as(
        "SELECT id, user_id FROM notifications WHERE id = ANY($1)",
    )
    .bind(&req.notification_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    for (_, owner_id) in &owners {
        if owner_id != user_uid {
            return Err(AppError::Forbidden(
                "다른 사용자의 알림은 삭제할 수 없습니다".to_string(),
            ));
        }
    }

    sqlx::query("DELETE FROM notifications WHERE id = ANY($1) AND user_id = $2")
        .bind(&req.notification_ids)
        .bind(user_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

pub async fn delete_all_notifications(pool: &PgPool, user_uid: &str) -> Result<(), AppError> {
    sqlx::query("DELETE FROM notifications WHERE user_id = $1")
        .bind(user_uid)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

// ============================================================
// 푸시 전송 (내부)
// ============================================================

/// 알림 설정 확인용 내부 구조체
#[derive(sqlx::FromRow)]
struct NotificationSettings {
    user_id: String,
    notifications_enabled: bool,
    schedule_invitation: bool,
    schedule_reminder: bool,
    schedule_confirmed: bool,
    schedule_cancelled: bool,
    schedule_updated: bool,
    attendance_response: bool,
    group_update: bool,
}

/// 알림 타입에 따라 카테고리 설정이 활성화되어 있는지 확인
fn is_category_enabled(settings: &NotificationSettings, ntype: &NotificationType) -> bool {
    match ntype {
        // 항상 전송되는 타입 (설정 무시)
        NotificationType::LocationSharingReminder
        | NotificationType::System
        | NotificationType::GroupInvitation => true,
        // 카테고리별 설정 확인
        NotificationType::ScheduleInvitation => settings.schedule_invitation,
        NotificationType::ScheduleReminder => settings.schedule_reminder,
        NotificationType::ScheduleConfirmed => settings.schedule_confirmed,
        NotificationType::ScheduleCancelled => settings.schedule_cancelled,
        NotificationType::ScheduleUpdated => settings.schedule_updated,
        NotificationType::AttendanceResponse => settings.attendance_response,
        NotificationType::GroupUpdate => settings.group_update,
    }
}

/// 알림 타입이 설정을 무시하는 타입인지 확인
fn bypasses_settings(ntype: &NotificationType) -> bool {
    matches!(
        ntype,
        NotificationType::LocationSharingReminder
            | NotificationType::System
            | NotificationType::GroupInvitation
    )
}

pub async fn send_push_internal(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    params: SendPushRequest,
) -> Result<PushResult, AppError> {
    // 1. 검증
    if params.user_ids.is_empty() {
        return Err(AppError::BadRequest(
            "수신자가 비어있습니다".to_string(),
        ));
    }
    if params.title.trim().is_empty() {
        return Err(AppError::BadRequest(
            "제목은 비어있을 수 없습니다".to_string(),
        ));
    }
    if params.body.trim().is_empty() {
        return Err(AppError::BadRequest(
            "본문은 비어있을 수 없습니다".to_string(),
        ));
    }

    // 2. 권한: group_id가 있으면 sender와 각 recipient이 같은 그룹인지 확인
    if let Some(group_id) = params.group_id {
        // related_user_id가 sender
        let sender_id = params.related_user_id.as_deref();

        for user_id in &params.user_ids {
            // 자기 자신은 항상 허용
            if sender_id == Some(user_id.as_str()) {
                continue;
            }

            // 수신자가 그룹 멤버인지 확인
            let is_member: Option<(String,)> = sqlx::query_as(
                "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = $2",
            )
            .bind(group_id)
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;

            if is_member.is_none() {
                return Err(AppError::Forbidden(
                    "수신자가 같은 그룹에 속하지 않습니다".to_string(),
                ));
            }
        }
    }

    // 3. DB 저장 (N3 규칙): 각 recipient에 대해 notifications 테이블에 INSERT
    let data_json = params
        .data
        .as_ref()
        .map(serde_json::to_value)
        .transpose()
        .map_err(|e| AppError::Internal(e.to_string()))?;

    let mut notification_ids: Vec<(Uuid, String)> = Vec::new();

    for user_id in &params.user_ids {
        let row: (Uuid,) = sqlx::query_as(
            "INSERT INTO notifications (user_id, notification_type, title, body, \
             schedule_id, group_id, related_user_id, is_read, is_delivered, data) \
             VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, FALSE, $8) \
             RETURNING id",
        )
        .bind(user_id)
        .bind(&params.notification_type)
        .bind(&params.title)
        .bind(&params.body)
        .bind(params.schedule_id)
        .bind(params.group_id)
        .bind(&params.related_user_id)
        .bind(&data_json)
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        notification_ids.push((row.0, user_id.clone()));
    }

    // 4. 알림 설정 체크: 각 recipient의 group_members 알림 설정 확인
    let mut fcm_eligible_user_ids: Vec<String> = Vec::new();

    if bypasses_settings(&params.notification_type) {
        // 설정 무시 타입이면 모든 유저가 FCM 대상
        fcm_eligible_user_ids = params.user_ids.clone();
    } else if let Some(group_id) = params.group_id {
        // 그룹별 알림 설정 확인
        let settings: Vec<NotificationSettings> = sqlx::query_as(
            "SELECT user_id, notifications_enabled, \
             schedule_invitation, schedule_reminder, schedule_confirmed, \
             schedule_cancelled, schedule_updated, attendance_response, group_update \
             FROM group_members WHERE group_id = $1 AND user_id = ANY($2)",
        )
        .bind(group_id)
        .bind(&params.user_ids)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        for s in &settings {
            if s.notifications_enabled && is_category_enabled(s, &params.notification_type) {
                fcm_eligible_user_ids.push(s.user_id.clone());
            }
        }
    } else {
        // group_id가 없으면 모든 유저가 FCM 대상
        fcm_eligible_user_ids = params.user_ids.clone();
    }

    // 5. 디바이스 토큰 수집
    if fcm_eligible_user_ids.is_empty() {
        return Ok(PushResult {
            success: true,
            success_count: 0,
            failure_count: 0,
        });
    }

    let tokens: Vec<(String,)> = sqlx::query_as(
        "SELECT fcm_token FROM devices WHERE user_id = ANY($1)",
    )
    .bind(&fcm_eligible_user_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let token_list: Vec<String> = tokens.into_iter().map(|(t,)| t).collect();

    if token_list.is_empty() {
        return Ok(PushResult {
            success: true,
            success_count: 0,
            failure_count: 0,
        });
    }

    // 6. FCM 전송
    let message = FcmMessage {
        title: params.title,
        body: params.body,
        notification_type: params.notification_type,
        data: params.data,
        schedule_id: params.schedule_id,
        group_id: params.group_id,
        related_user_id: params.related_user_id,
    };

    let push_result = push_sender.send_multicast(&token_list, &message).await;

    // 7. delivered 업데이트: 전송 성공한 알림의 is_delivered=true
    if push_result.success_count > 0 {
        // fcm_eligible 유저들의 notification_id를 갱신
        let eligible_set: HashSet<&str> = fcm_eligible_user_ids.iter().map(|s| s.as_str()).collect();
        let delivered_ids: Vec<Uuid> = notification_ids
            .iter()
            .filter(|(_, uid)| eligible_set.contains(uid.as_str()))
            .map(|(id, _)| *id)
            .collect();

        if !delivered_ids.is_empty() {
            sqlx::query(
                "UPDATE notifications SET is_delivered = TRUE, delivered_at = NOW() \
                 WHERE id = ANY($1)",
            )
            .bind(&delivered_ids)
            .execute(pool)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
        }
    }

    Ok(push_result)
}

// ============================================================
// 이벤트 트리거 (내부)
// ============================================================

/// 일정 생성 시 그룹 멤버에게 알림 (호스트 제외)
pub async fn notify_schedule_created(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    schedule_id: Uuid,
    group_id: Uuid,
    creator_id: &str,
) -> Result<(), AppError> {
    // schedule 정보 조회
    let schedule: (String,) = sqlx::query_as(
        "SELECT title FROM schedules WHERE id = $1",
    )
    .bind(schedule_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;
    let schedule_title = schedule.0;

    // creator 닉네임 조회
    let creator: (String,) = sqlx::query_as(
        "SELECT nickname FROM users WHERE id = $1",
    )
    .bind(creator_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;
    let creator_nickname = creator.0;

    // 그룹 멤버 조회 (creator 제외)
    let members: Vec<(String,)> = sqlx::query_as(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2",
    )
    .bind(group_id)
    .bind(creator_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let member_ids: Vec<String> = members.into_iter().map(|(id,)| id).collect();

    if !member_ids.is_empty() {
        let req = SendPushRequest {
            user_ids: member_ids,
            notification_type: NotificationType::ScheduleInvitation,
            title: "새 약속 도착 \u{1F4E9}".to_string(),
            body: format!(
                "{}님이 {}을 제안했어요. 확인해주세요!",
                creator_nickname, schedule_title
            ),
            schedule_id: Some(schedule_id),
            group_id: Some(group_id),
            related_user_id: Some(creator_id.to_string()),
            data: None,
        };
        send_push_internal(pool, push_sender, req).await?;
    }

    // Badge: groups.last_activity_at 갱신
    sqlx::query("UPDATE groups SET last_activity_at = NOW() WHERE id = $1")
        .bind(group_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(())
}

/// 투표 상태 변경 시 알림 (confirmed/cancelled)
pub async fn notify_schedule_votes_updated(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    schedule_id: Uuid,
    old_votes: &[VoteInfo],
    new_votes: &[VoteInfo],
) -> Result<(), AppError> {
    // schedule 정보 조회
    let schedule: (String, Option<i16>, Option<Uuid>) = sqlx::query_as(
        "SELECT title, minimum_participants, group_id FROM schedules WHERE id = $1",
    )
    .bind(schedule_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let schedule_title = schedule.0;
    let minimum_participants = schedule.1.unwrap_or(2) as usize;
    let group_id = schedule.2;

    // old/new vote maps
    let old_map: HashMap<&str, &str> = old_votes
        .iter()
        .map(|v| (v.user_id.as_str(), v.status.as_str()))
        .collect();
    // old accepted count
    let old_accepted_count = old_votes
        .iter()
        .filter(|v| v.status == "accepted")
        .count();

    // new accepted count
    let new_accepted_count = new_votes
        .iter()
        .filter(|v| v.status == "accepted")
        .count();

    // new accepted users
    let new_accepted_users: Vec<String> = new_votes
        .iter()
        .filter(|v| v.status == "accepted")
        .map(|v| v.user_id.clone())
        .collect();

    // Confirmed: 이전에 min 미달 -> 현재 min 이상 달성
    if old_accepted_count < minimum_participants
        && new_accepted_count >= minimum_participants
        && !new_accepted_users.is_empty()
    {
        let req = SendPushRequest {
            user_ids: new_accepted_users.clone(),
            notification_type: NotificationType::ScheduleConfirmed,
            title: "약속 확정!".to_string(),
            body: format!("{}이 확정되었어요!", schedule_title),
            schedule_id: Some(schedule_id),
            group_id,
            related_user_id: None,
            data: None,
        };
        send_push_internal(pool, push_sender, req).await?;
    }

    // Cancelled: 새로운 decline이 있고, remaining possible < min
    let has_new_decline = new_votes.iter().any(|v| {
        v.status == "declined"
            && old_map.get(v.user_id.as_str()) != Some(&"declined")
    });

    if has_new_decline {
        // N10: remaining possible = 전체 그룹 멤버 수 - 거절 수
        let total_members: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM group_members WHERE group_id = $1",
        )
        .bind(group_id.unwrap())
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        let declined_count = new_votes
            .iter()
            .filter(|v| v.status == "declined")
            .count();
        let remaining_possible = total_members.0 as usize - declined_count;

        if remaining_possible < minimum_participants {
            // accepted 유저에게 cancelled 알림
            if !new_accepted_users.is_empty() {
                let req = SendPushRequest {
                    user_ids: new_accepted_users,
                    notification_type: NotificationType::ScheduleCancelled,
                    title: "약속 취소".to_string(),
                    body: format!("{}이 최소 인원 미달로 취소되었어요.", schedule_title),
                    schedule_id: Some(schedule_id),
                    group_id,
                    related_user_id: None,
                    data: None,
                };
                send_push_internal(pool, push_sender, req).await?;
            }
        }
    }

    Ok(())
}

/// 일정 정보 변경 시 알림 (필드 diff 포함)
pub async fn notify_schedule_info_updated(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    schedule_id: Uuid,
    changes: &[FieldChange],
) -> Result<(), AppError> {
    // 감지 대상 필드만 필터 (endAt은 무시 - 결정 1-B)
    let monitored_fields = ["title", "start_at", "location", "description", "minimum_participants"];
    let relevant_changes: Vec<&FieldChange> = changes
        .iter()
        .filter(|c| monitored_fields.contains(&c.field.as_str()))
        .collect();

    if relevant_changes.is_empty() {
        return Ok(());
    }

    // schedule 정보 조회
    let schedule: (String, Option<Uuid>) = sqlx::query_as(
        "SELECT title, group_id FROM schedules WHERE id = $1",
    )
    .bind(schedule_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let schedule_title = schedule.0;
    let group_id = schedule.1;

    // N6: ScheduleUpdated 수신 대상은 accepted 유저만 (fallback 없음)
    let user_ids: Vec<String> = {
        let accepted_users: Vec<(String,)> = sqlx::query_as(
            "SELECT user_id FROM schedule_votes WHERE schedule_id = $1 AND status = 'accepted'",
        )
        .bind(schedule_id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?;

        accepted_users.into_iter().map(|(id,)| id).collect()
    };

    if user_ids.is_empty() {
        return Ok(());
    }

    // changes를 data에 포함
    let changes_data: Vec<HashMap<String, String>> = relevant_changes
        .iter()
        .map(|c| {
            let mut map = HashMap::new();
            map.insert("field".to_string(), c.field.clone());
            if let Some(ref old) = c.old_value {
                map.insert("old_value".to_string(), old.clone());
            }
            if let Some(ref new) = c.new_value {
                map.insert("new_value".to_string(), new.clone());
            }
            map
        })
        .collect();

    let mut data = HashMap::new();
    data.insert(
        "changes".to_string(),
        serde_json::to_string(&changes_data).unwrap_or_default(),
    );

    let req = SendPushRequest {
        user_ids,
        notification_type: NotificationType::ScheduleUpdated,
        title: "약속 변경".to_string(),
        body: format!("{}의 정보가 변경되었어요.", schedule_title),
        schedule_id: Some(schedule_id),
        group_id,
        related_user_id: None,
        data: Some(data),
    };
    send_push_internal(pool, push_sender, req).await?;

    Ok(())
}

/// 새 멤버 가입 시 기존 멤버에게 알림
pub async fn notify_group_member_joined(
    pool: &PgPool,
    push_sender: &dyn PushSender,
    group_id: Uuid,
    new_member_id: &str,
) -> Result<(), AppError> {
    // new_member 닉네임 조회
    let member: (String,) = sqlx::query_as(
        "SELECT nickname FROM users WHERE id = $1",
    )
    .bind(new_member_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;
    let new_member_nickname = member.0;

    // 그룹 이름 조회
    let group: (String,) = sqlx::query_as(
        "SELECT name FROM groups WHERE id = $1",
    )
    .bind(group_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;
    let group_name = group.0;

    // 기존 멤버 조회 (new_member 제외)
    let existing_members: Vec<(String,)> = sqlx::query_as(
        "SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2",
    )
    .bind(group_id)
    .bind(new_member_id)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::Internal(e.to_string()))?;

    let member_ids: Vec<String> = existing_members.into_iter().map(|(id,)| id).collect();

    if member_ids.is_empty() {
        return Ok(());
    }

    let req = SendPushRequest {
        user_ids: member_ids,
        notification_type: NotificationType::GroupUpdate,
        title: "새 멤버 가입".to_string(),
        body: format!(
            "{}님이 {}에 참여했어요!",
            new_member_nickname, group_name
        ),
        schedule_id: None,
        group_id: Some(group_id),
        related_user_id: Some(new_member_id.to_string()),
        data: None,
    };
    send_push_internal(pool, push_sender, req).await?;

    Ok(())
}
