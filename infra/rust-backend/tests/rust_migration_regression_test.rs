use axum::body::Body;
use axum::http::{Request, StatusCode};
use chrono::{Duration, NaiveDate, TimeZone, Utc};
use promiso_backend::config::Config;
use promiso_backend::routes;
use promiso_backend::services::{briefing_service, widget_service};
use sqlx::PgPool;
use tower::ServiceExt;

fn test_config() -> Config {
    Config {
        database_url: "postgresql://localhost/promiso_test".to_string(),
        database_pool_url: "postgresql://localhost/promiso_test".to_string(),
        port: 8080,
        firebase_project_id: "promiso-dev".to_string(),
        gcs_upload_bucket: None,
        gcs_signed_url_ttl_seconds: 900,
        auth_jwt_secret: Some("test-auth-secret".to_string()),
        auth_jwt_issuer: "promiso-test".to_string(),
        auth_access_token_ttl_seconds: 900,
        app_store_apple_id: None,
        google_application_credentials: None,
        firebase_service_account_json: None,
        apns_key_id: None,
        apns_team_id: None,
        apns_auth_key: None,
        apns_auth_key_path: None,
        apns_bundle_id: None,
        apns_environment: "development".to_string(),
        widget_jwt_secret: Some("test-secret".to_string()),
    }
}

async fn insert_test_user(pool: &PgPool, id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) \
         VALUES ($1, $2, $3, 'google', $4, $5)",
    )
    .bind(id)
    .bind(nickname)
    .bind(nickname)
    .bind(format!("uid-{id}"))
    .bind(format!("{id}@test.com"))
    .execute(pool)
    .await
    .expect("insert user");
}

async fn create_test_group(pool: &PgPool, creator_id: &str, name: &str) -> uuid::Uuid {
    let row: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO groups (name, invite_code, max_members, last_activity_at) \
         VALUES ($1, UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6)), 10, NOW()) \
         RETURNING id",
    )
    .bind(name)
    .fetch_one(pool)
    .await
    .expect("insert group");

    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')")
        .bind(row.0)
        .bind(creator_id)
        .execute(pool)
        .await
        .expect("insert group host");

    row.0
}

#[sqlx::test(migrations = "./migrations")]
async fn widget_snapshot_rejects_revoked_widget_token(pool: PgPool) {
    insert_test_user(&pool, "widget_revoked", "위젯리보크").await;

    let token = widget_service::generate_widget_token(
        &pool,
        "widget_revoked",
        "device-a",
        "test-secret",
    )
    .await
    .expect("issue widget token")
    .widget_token;

    widget_service::revoke_widget_tokens(&pool, "widget_revoked")
        .await
        .expect("revoke widget token");

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .uri("/api/v1/widget/snapshot")
                .header("authorization", format!("Bearer {token}"))
                .header("x-device-id", "device-a")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn widget_snapshot_rejects_mismatched_device_id(pool: PgPool) {
    insert_test_user(&pool, "widget_device", "위젯디바이스").await;

    let token = widget_service::generate_widget_token(
        &pool,
        "widget_device",
        "device-a",
        "test-secret",
    )
    .await
    .expect("issue widget token")
    .widget_token;

    let response = routes::create_router(pool, &test_config())
        .oneshot(
            Request::builder()
                .uri("/api/v1/widget/snapshot")
                .header("authorization", format!("Bearer {token}"))
                .header("x-device-id", "device-b")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn widget_snapshot_includes_recently_ended_schedule(pool: PgPool) {
    insert_test_user(&pool, "widget_recent", "최근종료").await;

    let now = Utc::now();
    sqlx::query(
        "INSERT INTO schedules (id, schedule_type, user_id, title, start_at, end_at) \
         VALUES (gen_random_uuid(), 'personal', $1, '방금 끝난 일정', $2, $3)",
    )
    .bind("widget_recent")
    .bind(now - Duration::minutes(90))
    .bind(now - Duration::minutes(30))
    .execute(&pool)
    .await
    .expect("insert recent schedule");

    let snapshot = widget_service::get_widget_snapshot(&pool, "widget_recent")
        .await
        .expect("fetch snapshot");

    assert!(
        snapshot.today.iter().any(|item| item.title == "방금 끝난 일정"),
        "종료 후 1시간 이내 일정이 today에 포함되어야 함"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn fetch_today_schedules_respects_timezone_boundaries(pool: PgPool) {
    insert_test_user(&pool, "briefing_tz", "타임존유저").await;

    let local_date = NaiveDate::from_ymd_opt(2026, 4, 9).unwrap();
    let start_at_utc = Utc.with_ymd_and_hms(2026, 4, 8, 16, 0, 0).unwrap();

    sqlx::query(
        "INSERT INTO schedules (id, schedule_type, user_id, title, start_at) \
         VALUES (gen_random_uuid(), 'personal', $1, 'KST 새벽 일정', $2)",
    )
    .bind("briefing_tz")
    .bind(start_at_utc)
    .execute(&pool)
    .await
    .expect("insert timezone schedule");

    let items =
        briefing_service::fetch_today_schedules(&pool, "briefing_tz", local_date, "Asia/Seoul")
            .await
            .expect("fetch today schedules");

    assert!(
        items.iter().any(|item| item.title == "KST 새벽 일정"),
        "timezone 기준 오늘 일정이 포함되어야 함"
    );
}

#[sqlx::test(migrations = "./migrations")]
async fn fetch_upcoming_schedules_includes_group_schedule_for_member(pool: PgPool) {
    insert_test_user(&pool, "upcoming_host", "호스트").await;
    insert_test_user(&pool, "upcoming_member", "멤버").await;
    let group_id = create_test_group(&pool, "upcoming_host", "업커밍그룹").await;

    sqlx::query("INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')")
        .bind(group_id)
        .bind("upcoming_member")
        .execute(&pool)
        .await
        .expect("insert group member");

    let schedule_id: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO schedules \
            (id, schedule_type, user_id, group_id, title, start_at, is_confirmed, minimum_participants, vote_deadline) \
         VALUES (gen_random_uuid(), 'group', $1, $2, '멤버 업커밍 일정', $3, TRUE, 2, $4) \
         RETURNING id",
    )
    .bind("upcoming_host")
    .bind(group_id)
    .bind(Utc.with_ymd_and_hms(2026, 4, 9, 10, 0, 0).unwrap())
    .bind(Utc.with_ymd_and_hms(2026, 4, 9, 9, 0, 0).unwrap())
    .fetch_one(&pool)
    .await
    .expect("insert upcoming group schedule");

    sqlx::query(
        "INSERT INTO schedule_votes (schedule_id, user_id, status) VALUES ($1, $2, 'accepted')",
    )
    .bind(schedule_id.0)
    .bind("upcoming_member")
    .execute(&pool)
    .await
    .expect("insert accepted vote");

    let upcoming = briefing_service::fetch_upcoming_schedules(
        &pool,
        "upcoming_member",
        NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
    )
    .await
    .expect("fetch upcoming schedules");

    let (_, items) = upcoming.expect("accepted group upcoming schedule should exist");
    assert!(
        items.iter().any(|item| item.title == "멤버 업커밍 일정"),
        "멤버가 accepted한 그룹 일정이 upcoming에 포함되어야 함"
    );
}
