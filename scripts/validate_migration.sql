-- Firestore → PostgreSQL 마이그레이션 검증 쿼리 (정밀 버전)
-- 사용: psql $DATABASE_URL -f scripts/validate_migration.sql
--
-- 모든 "violations" 값은 0이어야 정상.
-- 타임존 관련 이상을 집중 감지하도록 강화.

\set KST '''Asia/Seoul'''

-- ============================================================
-- 1. 테이블 카운트
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
-- 2. 참조 무결성
-- ============================================================
SELECT '=== REFERENTIAL INTEGRITY ===' AS section;

SELECT 'orphan group_members (no group)' AS check_name, count(*) AS violations
FROM group_members gm WHERE NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = gm.group_id);

SELECT 'orphan group_members (no user)' AS check_name, count(*) AS violations
FROM group_members gm WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = gm.user_id);

SELECT 'orphan schedule_votes (no schedule)' AS check_name, count(*) AS violations
FROM schedule_votes sv WHERE NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = sv.schedule_id);

SELECT 'orphan schedule_votes (no user)' AS check_name, count(*) AS violations
FROM schedule_votes sv WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = sv.user_id);

SELECT 'orphan notifications (schedule missing)' AS check_name, count(*) AS violations
FROM notifications n WHERE n.schedule_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = n.schedule_id);

SELECT 'orphan notifications (group missing)' AS check_name, count(*) AS violations
FROM notifications n WHERE n.group_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = n.group_id);

SELECT 'orphan notifications (user missing)' AS check_name, count(*) AS violations
FROM notifications n WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = n.user_id);

SELECT 'orphan devices (no user)' AS check_name, count(*) AS violations
FROM devices d WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = d.user_id);

SELECT 'orphan schedules (group schedule, no group)' AS check_name, count(*) AS violations
FROM schedules s WHERE s.schedule_type = 'group' AND s.group_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id = s.group_id);

SELECT 'orphan schedules (no user)' AS check_name, count(*) AS violations
FROM schedules s WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = s.user_id);

SELECT 'orphan auth_accounts (no user)' AS check_name, count(*) AS violations
FROM auth_accounts aa WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = aa.user_id);

-- ============================================================
-- 3. CHECK 제약 위반
-- ============================================================
SELECT '=== SCHEMA CONSTRAINT VIOLATIONS ===' AS section;

SELECT 'group schedules without group_id' AS check_name, count(*) AS violations
FROM schedules WHERE schedule_type = 'group' AND group_id IS NULL;

SELECT 'personal schedules with group_id' AS check_name, count(*) AS violations
FROM schedules WHERE schedule_type = 'personal' AND group_id IS NOT NULL;

SELECT 'group schedules without minimum_participants' AS check_name, count(*) AS violations
FROM schedules WHERE schedule_type = 'group' AND minimum_participants IS NULL;

SELECT 'group schedules without is_confirmed flag' AS check_name, count(*) AS violations
FROM schedules WHERE schedule_type = 'group' AND is_confirmed IS NULL;

SELECT 'personal schedules with group-only fields' AS check_name, count(*) AS violations
FROM schedules WHERE schedule_type = 'personal'
  AND (minimum_participants IS NOT NULL
    OR is_confirmed IS NOT NULL
    OR vote_deadline IS NOT NULL
    OR tracking_start_minutes_before IS NOT NULL);

SELECT 'entitlements without source' AS check_name, count(*) AS violations
FROM entitlements e
WHERE NOT EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = e.user_id)
  AND NOT EXISTS (SELECT 1 FROM entitlement_overrides eo WHERE eo.user_id = e.user_id);

-- ============================================================
-- 4. 시간/날짜 이상치 (timezone 마이그레이션 버그 탐지)
-- ============================================================
SELECT '=== TIME/DATE ANOMALIES ===' AS section;

-- 4-1. end_at이 start_at보다 앞
SELECT 'schedules with end_at < start_at' AS check_name, count(*) AS violations
FROM schedules WHERE end_at IS NOT NULL AND end_at < start_at;

-- 4-2. 비정상적으로 미래/과거 (1900-2100 밖)
SELECT 'schedules with start_at outside 1900-2100' AS check_name, count(*) AS violations
FROM schedules
WHERE start_at < TIMESTAMPTZ '1900-01-01' OR start_at > TIMESTAMPTZ '2100-01-01';

-- 4-3. 반복 일정 series_start_date가 series_end_date보다 뒤
SELECT 'recurring: series_start_date > series_end_date' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE series_end_date IS NOT NULL AND series_start_date > series_end_date;

-- 4-4. 반복 일정 시간 필드 범위
SELECT 'recurring: start_time_hour out of range' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE start_time_hour < 0 OR start_time_hour >= 24;

SELECT 'recurring: start_time_minute out of range' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE start_time_minute < 0 OR start_time_minute >= 60;

-- 4-5. 매주 반복 일정에 days_of_week 누락
SELECT 'weekly recurring without days_of_week' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE frequency = 'weekly' AND (days_of_week IS NULL OR cardinality(days_of_week) = 0);

-- 4-6. 매월 반복 일정에 day_of_month 누락
SELECT 'monthly recurring without day_of_month' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE frequency = 'monthly' AND day_of_month IS NULL;

-- 4-7. days_of_week 값 범위 (0~6)
SELECT 'recurring: days_of_week out of range' AS check_name,
       COALESCE(sum(
         CASE WHEN EXISTS (
           SELECT 1 FROM unnest(days_of_week) AS dow(v) WHERE v < 0 OR v > 6
         ) THEN 1 ELSE 0 END
       ), 0) AS violations
FROM recurring_schedules
WHERE days_of_week IS NOT NULL;

-- 4-8. day_of_month 값 범위 (1~31)
SELECT 'recurring: day_of_month out of range' AS check_name, count(*) AS violations
FROM recurring_schedules
WHERE day_of_month IS NOT NULL AND (day_of_month < 1 OR day_of_month > 31);

-- 4-9. excluded_dates가 series 구간 밖
SELECT 'recurring: excluded_date outside series range' AS check_name,
       COALESCE(sum(
         CASE WHEN EXISTS (
           SELECT 1 FROM unnest(excluded_dates) AS ed(d)
           WHERE d < series_start_date
             OR (series_end_date IS NOT NULL AND d > series_end_date)
         ) THEN 1 ELSE 0 END
       ), 0) AS violations
FROM recurring_schedules
WHERE excluded_dates IS NOT NULL;

-- 4-10. 매월 반복: day_of_month vs series_start_date 일자 불일치 감지
-- "매월 15일" 반복인데 series_start_date가 2026-04-14 같은 경우
SELECT 'monthly recurring: day_of_month <> series_start_date day' AS check_name,
       count(*) AS violations
FROM recurring_schedules
WHERE frequency = 'monthly'
  AND day_of_month IS NOT NULL
  AND extract(DAY FROM series_start_date)::int <> day_of_month;

-- 4-11. 매주 반복: series_start_date 요일이 days_of_week에 포함되어야 함
-- PostgreSQL extract(DOW): Sunday=0, Monday=1, ..., Saturday=6
SELECT 'weekly recurring: series_start_date DOW not in days_of_week' AS check_name,
       count(*) AS violations
FROM recurring_schedules
WHERE frequency = 'weekly'
  AND days_of_week IS NOT NULL
  AND cardinality(days_of_week) > 0
  AND NOT (extract(DOW FROM series_start_date)::smallint = ANY(days_of_week));

-- ============================================================
-- 5. 일정 시간대 분포 (KST 기준 비정상 시간 탐지)
-- ============================================================
SELECT '=== SCHEDULE HOUR DISTRIBUTION (KST) ===' AS section;

SELECT
  extract(HOUR FROM start_at AT TIME ZONE :KST)::int AS kst_hour,
  count(*) AS schedules
FROM schedules
WHERE schedule_type IN ('group', 'personal')
GROUP BY 1
ORDER BY 1;

-- 진짜 새벽 시간대(00-05) 일정이 많으면 timezone 변환 버그 의심
SELECT 'schedules at KST 00-05 (potential tz-bug)' AS check_name,
       count(*) AS count_
FROM schedules
WHERE extract(HOUR FROM start_at AT TIME ZONE :KST)::int BETWEEN 0 AND 5;

-- ============================================================
-- 6. 투표 / 참가자 정합성
-- ============================================================
SELECT '=== VOTE CONSISTENCY ===' AS section;

-- 호스트는 항상 accepted (P16 규칙)
SELECT 'group schedule host not accepted' AS check_name,
       count(*) AS violations
FROM schedules s
WHERE s.schedule_type = 'group'
  AND NOT EXISTS (
    SELECT 1 FROM schedule_votes sv
    WHERE sv.schedule_id = s.id AND sv.user_id = s.user_id AND sv.status = 'accepted'
  );

-- 중복 투표 (같은 schedule+user 여러 row)
SELECT 'duplicate schedule_votes (same schedule+user)' AS check_name,
       count(*) AS violations
FROM (
  SELECT schedule_id, user_id, count(*) c
  FROM schedule_votes GROUP BY 1, 2 HAVING count(*) > 1
) d;

-- is_confirmed=true 인데 accepted 수가 minimum_participants 미만
SELECT 'confirmed schedule with accepted < minimum_participants' AS check_name,
       count(*) AS violations
FROM schedules s
WHERE s.schedule_type = 'group' AND s.is_confirmed = true
  AND (
    SELECT count(*) FROM schedule_votes sv
    WHERE sv.schedule_id = s.id AND sv.status = 'accepted'
  ) < s.minimum_participants;

-- ============================================================
-- 7. 중복 / 유일성
-- ============================================================
SELECT '=== UNIQUENESS ===' AS section;

-- 닉네임 중복 (경고성, 제약은 없지만 많으면 문제)
SELECT 'users sharing nickname' AS check_name,
       count(*) AS duplicated_count
FROM (
  SELECT nickname FROM users GROUP BY nickname HAVING count(*) > 1
) d;

-- group invite_code 중복
SELECT 'groups with duplicated invite_code' AS check_name,
       count(*) AS duplicated_count
FROM (
  SELECT invite_code FROM groups GROUP BY invite_code HAVING count(*) > 1
) d;

-- ============================================================
-- 8. 스팟체크 (랜덤 5명)
-- ============================================================
SELECT '=== SPOT CHECK (5 random users) ===' AS section;

SELECT u.id AS user_id,
       u.nickname,
       (SELECT count(*) FROM group_members gm WHERE gm.user_id = u.id) AS groups,
       (SELECT count(*) FROM schedules s WHERE s.user_id = u.id AND s.schedule_type = 'group') AS group_schedules,
       (SELECT count(*) FROM schedules s WHERE s.user_id = u.id AND s.schedule_type = 'personal') AS personal_schedules,
       (SELECT count(*) FROM recurring_schedules rs WHERE rs.user_id = u.id) AS recurring,
       (SELECT count(*) FROM devices d WHERE d.user_id = u.id) AS devices,
       (SELECT count(*) FROM notifications n WHERE n.user_id = u.id) AS notifications,
       EXISTS(SELECT 1 FROM auth_accounts aa WHERE aa.user_id = u.id) AS has_auth,
       EXISTS(SELECT 1 FROM user_settings us WHERE us.user_id = u.id) AS has_settings
FROM users u
ORDER BY random()
LIMIT 5;

-- ============================================================
-- 9. 반복 일정 스팟체크 (5건)
-- ============================================================
SELECT '=== RECURRING SCHEDULES SPOT CHECK ===' AS section;

SELECT id,
       title,
       frequency,
       start_time_hour || ':' || lpad(start_time_minute::text, 2, '0') AS start_time,
       days_of_week,
       day_of_month,
       series_start_date,
       series_end_date,
       cardinality(COALESCE(excluded_dates, ARRAY[]::date[])) AS excluded_count
FROM recurring_schedules
ORDER BY created_at DESC
LIMIT 5;
