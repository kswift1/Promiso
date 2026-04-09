-- Firestore → PostgreSQL 마이그레이션 검증 쿼리
-- 사용: psql $DATABASE_URL -f scripts/validate_migration.sql

-- ============================================================
-- 1. 카운트 검증 (manifest.json과 비교)
-- ============================================================
SELECT '=== TABLE COUNTS ===' AS section;

SELECT 'users' AS table_name, count(*) AS row_count FROM users
UNION ALL SELECT 'auth_accounts', count(*) FROM auth_accounts
UNION ALL SELECT 'user_settings', count(*) FROM user_settings
UNION ALL SELECT 'groups', count(*) FROM groups
UNION ALL SELECT 'group_members', count(*) FROM group_members
UNION ALL SELECT 'devices', count(*) FROM devices
UNION ALL SELECT 'notification_endpoints', count(*) FROM notification_endpoints
UNION ALL SELECT 'live_activity_endpoints', count(*) FROM live_activity_endpoints
UNION ALL SELECT 'schedules (group)', count(*) FROM schedules WHERE schedule_type = 'group'
UNION ALL SELECT 'schedules (personal)', count(*) FROM schedules WHERE schedule_type = 'personal'
UNION ALL SELECT 'schedule_votes', count(*) FROM schedule_votes
UNION ALL SELECT 'recurring_schedules', count(*) FROM recurring_schedules
UNION ALL SELECT 'notifications', count(*) FROM notifications
UNION ALL SELECT 'subscriptions', count(*) FROM subscriptions
UNION ALL SELECT 'subscription_owners', count(*) FROM subscription_owners
UNION ALL SELECT 'entitlement_overrides', count(*) FROM entitlement_overrides
UNION ALL SELECT 'entitlements', count(*) FROM entitlements
UNION ALL SELECT 'briefing_subscriptions', count(*) FROM briefing_subscriptions
UNION ALL SELECT 'admin_users', count(*) FROM admin_users
UNION ALL SELECT 'admin_audit_logs', count(*) FROM admin_audit_logs
ORDER BY table_name;

-- ============================================================
-- 2. 참조 무결성 검증 (모두 0이어야 함)
-- ============================================================
SELECT '=== REFERENTIAL INTEGRITY ===' AS section;

SELECT 'orphan group_members (no group)' AS check_name,
       count(*) AS violations
FROM group_members gm
WHERE NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = gm.group_id);

SELECT 'orphan group_members (no user)' AS check_name,
       count(*) AS violations
FROM group_members gm
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = gm.user_id);

SELECT 'orphan schedule_votes (no schedule)' AS check_name,
       count(*) AS violations
FROM schedule_votes sv
WHERE NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = sv.schedule_id);

SELECT 'orphan schedule_votes (no user)' AS check_name,
       count(*) AS violations
FROM schedule_votes sv
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = sv.user_id);

SELECT 'orphan notifications (schedule missing)' AS check_name,
       count(*) AS violations
FROM notifications n
WHERE n.schedule_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = n.schedule_id);

SELECT 'orphan notifications (group missing)' AS check_name,
       count(*) AS violations
FROM notifications n
WHERE n.group_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = n.group_id);

SELECT 'orphan notifications (user missing)' AS check_name,
       count(*) AS violations
FROM notifications n
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = n.user_id);

SELECT 'orphan devices (no user)' AS check_name,
       count(*) AS violations
FROM devices d
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = d.user_id);

SELECT 'orphan schedules (group schedule, no group)' AS check_name,
       count(*) AS violations
FROM schedules s
WHERE s.schedule_type = 'group'
  AND s.group_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = s.group_id);

SELECT 'orphan schedules (no user)' AS check_name,
       count(*) AS violations
FROM schedules s
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = s.user_id);

-- ============================================================
-- 3. 데이터 일관성 검증
-- ============================================================
SELECT '=== DATA CONSISTENCY ===' AS section;

-- group schedule은 반드시 group_id가 있어야 함
SELECT 'group schedules without group_id' AS check_name,
       count(*) AS violations
FROM schedules
WHERE schedule_type = 'group' AND group_id IS NULL;

-- personal schedule은 group_id가 없어야 함
SELECT 'personal schedules with group_id' AS check_name,
       count(*) AS violations
FROM schedules
WHERE schedule_type = 'personal' AND group_id IS NOT NULL;

-- entitlements는 subscription 또는 override가 있어야 함
SELECT 'entitlements without source' AS check_name,
       count(*) AS violations
FROM entitlements e
WHERE NOT EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = e.user_id)
  AND NOT EXISTS (SELECT 1 FROM entitlement_overrides eo WHERE eo.user_id = e.user_id);

-- auth_accounts는 반드시 users에 대응
SELECT 'auth_accounts without user' AS check_name,
       count(*) AS violations
FROM auth_accounts aa
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = aa.user_id);

-- ============================================================
-- 4. 스팟체크 (랜덤 유저 5명 상세)
-- ============================================================
SELECT '=== SPOT CHECK (5 random users) ===' AS section;

SELECT u.id AS user_id,
       u.nickname,
       (SELECT count(*) FROM group_members gm WHERE gm.user_id = u.id) AS groups_count,
       (SELECT count(*) FROM schedules s WHERE s.user_id = u.id AND s.schedule_type = 'group') AS group_schedules,
       (SELECT count(*) FROM schedules s WHERE s.user_id = u.id AND s.schedule_type = 'personal') AS personal_schedules,
       (SELECT count(*) FROM recurring_schedules rs WHERE rs.user_id = u.id) AS recurring_schedules,
       (SELECT count(*) FROM devices d WHERE d.user_id = u.id) AS devices_count,
       (SELECT count(*) FROM notifications n WHERE n.user_id = u.id) AS notifications_count,
       EXISTS(SELECT 1 FROM auth_accounts aa WHERE aa.user_id = u.id) AS has_auth,
       EXISTS(SELECT 1 FROM user_settings us WHERE us.user_id = u.id) AS has_settings
FROM users u
ORDER BY random()
LIMIT 5;
