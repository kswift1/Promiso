//! Data migration service tests
//!
//! Firebase JSONL export -> PostgreSQL import logic tests.
//! Each test validates one phase of the import in isolation using sqlx::test.

use promiso_backend::services::data_migration_service::{
    import_admin_audit_logs, import_admin_users, import_auth_accounts, import_briefing_subscriptions,
    import_groups, import_notifications, import_personal_events, import_promises,
    import_recurring_events, import_user_settings, import_users, MigrationSummary,
};
use sqlx::PgPool;

// ---------------------------------------------------------------------------
// Phase A: users
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_users_inserts_basic_row(pool: PgPool) {
    let jsonl = r#"{"_id":"user_a1","name":"Alice","nickname":"alice1","profile":{"url":"https://example.com/a.jpg","thumbUrl":"https://example.com/at.jpg"},"groups":{},"devices":{},"metaData":{"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}}"#;

    let summary = import_users(&pool, jsonl)
        .await
        .expect("import_users should succeed");

    assert_eq!(summary.users, 1);

    let row: (String, String, String) =
        sqlx::query_as("SELECT id, name, nickname FROM users WHERE id = $1")
            .bind("user_a1")
            .fetch_one(&pool)
            .await
            .expect("user row should exist");

    assert_eq!(row.0, "user_a1");
    assert_eq!(row.1, "Alice");
    assert_eq!(row.2, "alice1");
}

#[sqlx::test(migrations = "./migrations")]
async fn import_users_is_idempotent(pool: PgPool) {
    let jsonl = r#"{"_id":"user_idem1","name":"Bob","nickname":"bobby1","profile":{"url":null,"thumbUrl":null},"groups":{},"devices":{},"metaData":{"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}}"#;

    import_users(&pool, jsonl)
        .await
        .expect("first import should succeed");
    import_users(&pool, jsonl)
        .await
        .expect("second import (idempotent) should succeed");

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE id = $1")
        .bind("user_idem1")
        .fetch_one(&pool)
        .await
        .expect("count query should succeed");

    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn import_users_inserts_devices_from_devices_map(pool: PgPool) {
    let jsonl = r#"{"_id":"user_dev1","name":"Carol","nickname":"carol1","profile":{"url":null,"thumbUrl":null},"groups":{},"devices":{"dev-uuid-001":{"fcmToken":"fcm-abc","platform":"ios","lastActiveAt":"2024-06-01T00:00:00Z","pushToStartToken":null,"liveActivityPushToken":null}},"metaData":{"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}}"#;

    let summary = import_users(&pool, jsonl)
        .await
        .expect("import_users should succeed");

    assert_eq!(summary.devices, 1);
    assert_eq!(summary.notification_endpoints, 1);

    let count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM devices WHERE user_id = $1")
            .bind("user_dev1")
            .fetch_one(&pool)
            .await
            .expect("count query should succeed");

    assert_eq!(count.0, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn import_users_inserts_live_activity_endpoints(pool: PgPool) {
    let jsonl = r#"{"_id":"user_la1","name":"Dave","nickname":"davey1","profile":{"url":null,"thumbUrl":null},"groups":{},"devices":{"dev-la-001":{"fcmToken":"fcm-la","platform":"ios","lastActiveAt":"2024-06-01T00:00:00Z","pushToStartToken":"pts-token-1","liveActivityPushToken":"lap-token-1"}},"metaData":{"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}}"#;

    let summary = import_users(&pool, jsonl)
        .await
        .expect("import_users should succeed");

    assert_eq!(summary.live_activity_endpoints, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn import_users_inserts_group_members_from_groups_map(pool: PgPool) {
    // Insert a group first so FK is satisfied
    let group_id =
        uuid::Uuid::new_v5(&uuid::Uuid::NAMESPACE_DNS, b"promiso.app/migration/groups")
            .hyphenated()
            .to_string();
    let ns_groups = uuid::Uuid::new_v5(&uuid::Uuid::NAMESPACE_DNS, b"promiso.app/migration/groups");
    let firestore_group_id = "grp-fk-001";
    let pg_group_id = uuid::Uuid::new_v5(&ns_groups, firestore_group_id.as_bytes());

    sqlx::query(
        "INSERT INTO groups (id, name, max_members, invite_code, last_activity_at) VALUES ($1, $2, 10, 'ABCDEF', NOW())",
    )
    .bind(pg_group_id)
    .bind("Test Group")
    .execute(&pool)
    .await
    .expect("group insert should succeed");

    let jsonl = format!(
        r#"{{"_id":"user_gm1","name":"Eve","nickname":"evvie1","profile":{{"url":null,"thumbUrl":null}},"groups":{{"{}":{{"role":"admin","joinedAt":"2024-01-01T00:00:00Z","notifications":{{"enabled":true,"promise":{{"invitation":true,"reminder":true,"confirmed":true,"cancelled":true,"updated":true,"attendanceResponse":true}},"group":{{"update":true}}}}}}}},"devices":{{}},"metaData":{{"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}}}}"#,
        firestore_group_id
    );

    let summary = import_users(&pool, &jsonl)
        .await
        .expect("import_users should succeed");

    assert_eq!(summary.group_members, 1);
}

// ---------------------------------------------------------------------------
// Phase A: auth_accounts
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_auth_accounts_inserts_row_and_updates_user(pool: PgPool) {
    // Insert a base user first
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_auth1")
    .bind("Frank")
    .bind("frank1")
    .bind("apple")
    .bind("apple.uid.1")
    .bind("frank@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"user_auth1","_userId":"user_auth1","provider":{"type":"google","uid":"google.uid.1","email":"frank@gmail.com"}}"#;

    let summary = import_auth_accounts(&pool, jsonl)
        .await
        .expect("import_auth_accounts should succeed");

    assert_eq!(summary.auth_accounts, 1);

    let row: (String, String, String) = sqlx::query_as(
        "SELECT provider_type, provider_uid, email FROM auth_accounts WHERE user_id = $1",
    )
    .bind("user_auth1")
    .fetch_one(&pool)
    .await
    .expect("auth_account row should exist");

    assert_eq!(row.0, "google");
    assert_eq!(row.1, "google.uid.1");
    assert_eq!(row.2.as_str(), "frank@gmail.com");
}

// ---------------------------------------------------------------------------
// Phase B: user_settings
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_user_settings_inserts_row(pool: PgPool) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_settings1")
    .bind("Grace")
    .bind("grace11")
    .bind("apple")
    .bind("apple.uid.settings1")
    .bind("grace@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"main","_userId":"user_settings1","notificationEnabled":false,"groupSortOption":{"type":"nameAscending","order":[]},"proSettings":{"briefing":{"notificationHour":8,"timezone":"Asia/Seoul","language":"ko","style":"friendly"},"conflictDetectionThresholdMinute":30}}"#;

    let summary = import_user_settings(&pool, jsonl)
        .await
        .expect("import_user_settings should succeed");

    assert_eq!(summary.user_settings, 1);

    let row: (i16,) =
        sqlx::query_as("SELECT briefing_notification_hour FROM user_settings WHERE user_id = $1")
            .bind("user_settings1")
            .fetch_one(&pool)
            .await
            .expect("user_settings row should exist");

    assert_eq!(row.0, 8);
}

// ---------------------------------------------------------------------------
// Phase B: groups
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_groups_inserts_group(pool: PgPool) {
    let jsonl = r#"{"_id":"grp-test-001","name":"TestGrp","description":"desc","imageUrl":null,"memberIds":[],"maxMembers":5,"inviteCode":"XYZ123","createdBy":"user_x","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}"#;

    let summary = import_groups(&pool, jsonl)
        .await
        .expect("import_groups should succeed");

    assert_eq!(summary.groups, 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn import_groups_is_idempotent(pool: PgPool) {
    let jsonl = r#"{"_id":"grp-idem-001","name":"IdemGrp","description":null,"imageUrl":null,"memberIds":[],"maxMembers":10,"inviteCode":"AAAAAA","createdBy":"user_x","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-06-01T00:00:00Z"}"#;

    import_groups(&pool, jsonl)
        .await
        .expect("first import should succeed");
    import_groups(&pool, jsonl)
        .await
        .expect("second import (idempotent) should succeed");
}

// ---------------------------------------------------------------------------
// Phase D: promises -> schedules (group)
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_promises_inserts_schedule_and_votes(pool: PgPool) {
    // Need user + group
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("host_user1")
    .bind("Host")
    .bind("hosty1")
    .bind("apple")
    .bind("apple.host1")
    .bind("host@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("voter_user1")
    .bind("Voter")
    .bind("votey1")
    .bind("apple")
    .bind("apple.voter1")
    .bind("voter@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let ns_groups = uuid::Uuid::new_v5(&uuid::Uuid::NAMESPACE_DNS, b"promiso.app/migration/groups");
    let pg_group_id = uuid::Uuid::new_v5(&ns_groups, b"grp-promise-001");

    sqlx::query(
        "INSERT INTO groups (id, name, max_members, invite_code, last_activity_at) VALUES ($1, $2, 10, 'BBBBBB', NOW())",
    )
    .bind(pg_group_id)
    .bind("PromiseGrp")
    .execute(&pool)
    .await
    .expect("group insert should succeed");

    let jsonl = r#"{"_id":"promise-001","title":"Meet up","emoji":"🎉","description":"Fun","descriptionBlocks":null,"hostId":"host_user1","groupId":"grp-promise-001","minimumParticipants":2,"isConfirmed":true,"votes":{"accepted":["host_user1","voter_user1"],"declined":[],"until":"2025-01-15T00:00:00Z"},"startAt":"2025-01-20T10:00:00Z","endAt":"2025-01-20T12:00:00Z","location":{"name":"Seoul","address":"Seoul, Korea","latitude":37.5,"longitude":127.0},"trackingStartMinutesBefore":30,"imageUrls":[],"createdAt":"2024-12-01T00:00:00Z","updatedAt":"2024-12-15T00:00:00Z"}"#;

    let summary = import_promises(&pool, jsonl)
        .await
        .expect("import_promises should succeed");

    assert_eq!(summary.schedules, 1);
    assert_eq!(summary.schedule_votes, 2);
}

// ---------------------------------------------------------------------------
// Phase D: personal_events -> schedules (personal)
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_personal_events_inserts_personal_schedule(pool: PgPool) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_pe1")
    .bind("Personal")
    .bind("persy1")
    .bind("apple")
    .bind("apple.pe1")
    .bind("pe@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"pe-001","_userId":"user_pe1","title":"Dentist","emoji":"🦷","description":null,"descriptionBlocks":null,"startAt":"2025-02-01T09:00:00Z","endAt":"2025-02-01T10:00:00Z","location":null,"reminderMinutesBefore":30,"createdAt":"2025-01-01T00:00:00Z","updatedAt":"2025-01-01T00:00:00Z"}"#;

    let summary = import_personal_events(&pool, jsonl)
        .await
        .expect("import_personal_events should succeed");

    assert_eq!(summary.schedules, 1);
}

// ---------------------------------------------------------------------------
// Phase E: recurring_events
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_recurring_events_inserts_row(pool: PgPool) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_re1")
    .bind("Recurring")
    .bind("recurr1")
    .bind("apple")
    .bind("apple.re1")
    .bind("re@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"re-001","_userId":"user_re1","title":"Weekly standup","startTime":{"hour":9,"minute":0},"endTime":{"hour":10,"minute":0},"recurrence":{"frequency":"weekly","daysOfWeek":[1,3,5],"dayOfMonth":null,"seriesEndDate":null},"seriesStartDate":"2025-01-06","excludedDates":[],"overrides":{},"createdAt":"2025-01-01T00:00:00Z","updatedAt":"2025-01-01T00:00:00Z"}"#;

    let summary = import_recurring_events(&pool, jsonl)
        .await
        .expect("import_recurring_events should succeed");

    assert_eq!(summary.recurring_schedules, 1);
}

// ---------------------------------------------------------------------------
// Phase E: notifications
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_notifications_maps_type_promise_to_schedule(pool: PgPool) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_notif1")
    .bind("Notify")
    .bind("notiff1")
    .bind("apple")
    .bind("apple.notif1")
    .bind("notif@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"notif-001","userId":"user_notif1","type":"promise_invitation","title":"You're invited","body":"Join us!","promiseId":null,"groupId":null,"relatedUserId":null,"isRead":false,"isDelivered":true,"createdAt":"2025-01-01T00:00:00Z","readAt":null,"deliveredAt":"2025-01-01T00:01:00Z","data":{}}"#;

    let summary = import_notifications(&pool, jsonl)
        .await
        .expect("import_notifications should succeed");

    assert_eq!(summary.notifications, 1);

    let row: (String,) =
        sqlx::query_as("SELECT notification_type::text FROM notifications WHERE user_id = $1")
            .bind("user_notif1")
            .fetch_one(&pool)
            .await
            .expect("notification row should exist");

    assert_eq!(row.0, "schedule_invitation");
}

// ---------------------------------------------------------------------------
// Phase G: briefing_subscriptions
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_briefing_subscriptions_inserts_row(pool: PgPool) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email) VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind("user_bs1")
    .bind("Briefer")
    .bind("brief1")
    .bind("apple")
    .bind("apple.bs1")
    .bind("bs@example.com")
    .execute(&pool)
    .await
    .expect("user insert should succeed");

    let jsonl = r#"{"_id":"user_bs1","notificationHour":8,"timezone":"Asia/Seoul","language":"ko","style":"friendly","nextDispatchAt":"2025-01-02T23:00:00Z","defaultLocation":{"title":"Home","latitude":37.5,"longitude":127.0}}"#;

    let summary = import_briefing_subscriptions(&pool, jsonl)
        .await
        .expect("import_briefing_subscriptions should succeed");

    assert_eq!(summary.briefing_subscriptions, 1);
}

// ---------------------------------------------------------------------------
// Phase G: admin_users
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_admin_users_inserts_row(pool: PgPool) {
    let jsonl = r#"{"_id":"admin_u1","role":"owner","email":"admin@promiso.app","enabled":true}"#;

    let summary = import_admin_users(&pool, jsonl)
        .await
        .expect("import_admin_users should succeed");

    assert_eq!(summary.admin_users, 1);

    let row: (String, bool) =
        sqlx::query_as("SELECT role::text, enabled FROM admin_users WHERE user_id = $1")
            .bind("admin_u1")
            .fetch_one(&pool)
            .await
            .expect("admin_users row should exist");

    assert_eq!(row.0, "owner");
    assert!(row.1);
}

// ---------------------------------------------------------------------------
// Phase G: admin_audit_logs
// ---------------------------------------------------------------------------

#[sqlx::test(migrations = "./migrations")]
async fn import_admin_audit_logs_inserts_row(pool: PgPool) {
    let jsonl = r#"{"_id":"log-001","actorId":"admin_u1","action":"subscription.override.grant","targetId":"user_x","targetType":"user","before":null,"after":{"isActive":true},"createdAt":"2025-01-01T00:00:00Z"}"#;

    let summary = import_admin_audit_logs(&pool, jsonl)
        .await
        .expect("import_admin_audit_logs should succeed");

    assert_eq!(summary.admin_audit_logs, 1);
}

// ---------------------------------------------------------------------------
// MigrationSummary: addition
// ---------------------------------------------------------------------------

#[test]
fn migration_summary_accumulates_correctly() {
    let a = MigrationSummary {
        users: 1,
        auth_accounts: 2,
        devices: 3,
        notification_endpoints: 4,
        live_activity_endpoints: 5,
        group_members: 6,
        user_settings: 7,
        groups: 8,
        schedules: 9,
        schedule_votes: 10,
        recurring_schedules: 11,
        notifications: 12,
        briefing_subscriptions: 13,
        admin_users: 14,
        admin_audit_logs: 15,
    };

    let b = MigrationSummary {
        users: 10,
        auth_accounts: 0,
        devices: 0,
        notification_endpoints: 0,
        live_activity_endpoints: 0,
        group_members: 0,
        user_settings: 0,
        groups: 0,
        schedules: 0,
        schedule_votes: 0,
        recurring_schedules: 0,
        notifications: 0,
        briefing_subscriptions: 0,
        admin_users: 0,
        admin_audit_logs: 0,
    };

    let c = a + b;
    assert_eq!(c.users, 11);
    assert_eq!(c.auth_accounts, 2);
    assert_eq!(c.admin_audit_logs, 15);
}
