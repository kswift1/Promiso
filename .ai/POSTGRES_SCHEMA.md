# PostgreSQL 스키마

> SSOT는 `infra/rust-backend/migrations/*.sql`. 이 문서는 현재 전체 스키마의 사람용 요약.

## users

```sql
CREATE TABLE users (
    id                   TEXT PRIMARY KEY,       -- Firebase Auth UID
    name                 TEXT NOT NULL,
    nickname             TEXT NOT NULL,
    provider_type        TEXT NOT NULL,           -- 'apple' | 'google'
    provider_uid         TEXT NOT NULL,
    email                TEXT NOT NULL,
    profile_url          TEXT,                    -- NULL = 프로필 이미지 없음
    notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_nickname_min CHECK (char_length(nickname) >= 2),
    CONSTRAINT chk_nickname_max CHECK (char_length(nickname) <= 12),
    CONSTRAINT chk_nickname_no_spaces CHECK (nickname !~ '\s'),
    UNIQUE (nickname)
);
```

| 컬럼 | Firestore 원본 | 비고 |
|------|---------------|------|
| id | 문서 ID (`users/{userId}`) | Firebase Auth UID 유지 |
| name, nickname | 메인 문서 필드 | |
| provider_type, provider_uid, email | `auth/main` 서브컬렉션 | 단일 테이블로 합침 |
| profile_url | `profile.url` 필드 | thumbUrl, updatedAt 제거 |
| notification_enabled | `settings/main` 서브컬렉션 | 나머지 settings는 미마이그레이션 |

## groups

```sql
CREATE TABLE groups (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  description      TEXT,
  image_url        TEXT,
  max_members      SMALLINT NOT NULL DEFAULT 10,
  invite_code      CHAR(6) NOT NULL,
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_group_name_len    CHECK (char_length(name) BETWEEN 2 AND 12),
  CONSTRAINT chk_group_desc_len    CHECK (description IS NULL OR char_length(description) <= 50),
  CONSTRAINT chk_group_max_members CHECK (max_members BETWEEN 2 AND 10),
  CONSTRAINT chk_group_invite_code CHECK (invite_code ~ '^[A-Z0-9]{6}$')
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 자동 생성 UUID |
| name | TEXT | NOT NULL, 2-12자 | 그룹 이름 (수정 불가) |
| description | TEXT | nullable, 최대 50자 | 그룹 설명 |
| image_url | TEXT | nullable | 그룹 대표 이미지 URL |
| max_members | SMALLINT | NOT NULL, 2-10, default 10 | 최대 인원 |
| invite_code | CHAR(6) | NOT NULL, A-Z0-9 패턴, UNIQUE | 초대 코드 |
| last_activity_at | TIMESTAMPTZ | NOT NULL, default NOW() | 최근 활동 시각 (배지 계산용) |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | 생성 시각 |
| updated_at | TIMESTAMPTZ | NOT NULL, default NOW() | 수정 시각 |

| Firestore 원본 | 비고 |
|---------------|------|
| `groups/{groupId}` 문서 | 문서 ID는 UUID로 재생성 (Firestore는 자동 ID, PostgreSQL은 gen_random_uuid()) |
| `memberIds` 배열 | 비정규화 제거 — `group_members` 테이블로 분리 |
| `createdBy` | `group_members` 테이블의 `role = 'admin'`으로 표현 |

## group_members

```sql
CREATE TYPE group_member_role AS ENUM ('admin', 'member');

CREATE TABLE group_members (
  group_id                UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role                    group_member_role NOT NULL DEFAULT 'member',
  group_color             TEXT NOT NULL DEFAULT '#AF52DE',

  -- 알림 설정 (JSONB 대신 명시적 컬럼)
  notifications_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_invitation     BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_reminder       BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_confirmed      BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_cancelled      BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_updated        BOOLEAN NOT NULL DEFAULT TRUE,
  attendance_response     BOOLEAN NOT NULL DEFAULT TRUE,
  group_update            BOOLEAN NOT NULL DEFAULT TRUE,
  calendar_sync           BOOLEAN NOT NULL DEFAULT TRUE,

  joined_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (group_id, user_id),

  CONSTRAINT chk_group_color_palette CHECK (group_color IN (
    '#FF3B30', '#FF6F61', '#FF9500', '#FFCC00',
    '#84CC16', '#34C759', '#00C7BE', '#007AFF',
    '#1E3F8A', '#AF52DE', '#C4B5FD', '#E040FB',
    '#FF6B9D', '#C2185B', '#A0845C', '#8E8E93'
  )),
  CONSTRAINT chk_last_read_at_after_joined_at CHECK (last_read_at >= joined_at)
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| group_id | UUID | PK, FK → groups.id CASCADE | 그룹 ID |
| user_id | TEXT | PK, FK → users.id CASCADE | 유저 ID (Firebase UID) |
| role | group_member_role | NOT NULL, default 'member' | 역할 (admin / member) |
| group_color | TEXT | NOT NULL, default '#AF52DE', 16가지 팔레트 | 개인별 그룹 색상 |
| notifications_enabled | BOOLEAN | NOT NULL, default TRUE | 전체 알림 ON/OFF |
| schedule_invitation | BOOLEAN | NOT NULL, default TRUE | 일정 초대 알림 |
| schedule_reminder | BOOLEAN | NOT NULL, default TRUE | 일정 리마인더 알림 |
| schedule_confirmed | BOOLEAN | NOT NULL, default TRUE | 일정 확정 알림 |
| schedule_cancelled | BOOLEAN | NOT NULL, default TRUE | 일정 취소 알림 |
| schedule_updated | BOOLEAN | NOT NULL, default TRUE | 일정 수정 알림 |
| attendance_response | BOOLEAN | NOT NULL, default TRUE | 참석 응답 알림 |
| group_update | BOOLEAN | NOT NULL, default TRUE | 그룹 정보 변경 알림 |
| calendar_sync | BOOLEAN | NOT NULL, default TRUE | 캘린더 동기화 여부 |
| joined_at | TIMESTAMPTZ | NOT NULL, default NOW() | 가입 시각 |
| last_read_at | TIMESTAMPTZ | NOT NULL, default NOW(), >= joined_at | 마지막 읽음 시각 |

| Firestore 원본 | 비고 |
|---------------|------|
| `users/{uid}.groups` Map | 비정규화 Map을 정규화된 조인 테이블로 전환 |
| `groups/{id}.memberIds` 배열 | 동일, group_members로 흡수 |
| 알림 설정 (`groups` Map의 notifications) | JSONB 없이 명시적 컬럼으로 관리 |

## schedules

그룹일정과 개인일정을 단일 테이블로 통합. `schedule_type`으로 구분하고, CHECK 제약으로 타입별 필드 정합성 보장.

```sql
CREATE TYPE schedule_type AS ENUM ('group', 'personal');

CREATE TABLE schedules (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_type                 schedule_type NOT NULL,
  user_id                       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                                -- personal: 소유자, group: 호스트

  -- 공통 필드
  title                         TEXT NOT NULL,
  emoji                         TEXT,
  description                   TEXT,
  description_blocks            JSONB,
  start_at                      TIMESTAMPTZ NOT NULL,
  end_at                        TIMESTAMPTZ,
  location_name                 TEXT,
  location_address              TEXT,
  location_latitude             DOUBLE PRECISION,
  location_longitude            DOUBLE PRECISION,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 그룹일정 전용 (personal이면 NULL)
  group_id                      UUID REFERENCES groups(id) ON DELETE CASCADE,
  minimum_participants          SMALLINT,
  is_confirmed                  BOOLEAN,
  vote_deadline                 TIMESTAMPTZ,
  tracking_start_minutes_before SMALLINT,
  image_urls                    TEXT[],

  -- 개인일정 전용 (group이면 NULL)
  reminder_minutes_before       SMALLINT,

  -- 제약 조건
  CONSTRAINT chk_title_not_empty   CHECK (char_length(trim(title)) > 0),
  CONSTRAINT chk_title_max_len     CHECK (char_length(title) <= 30),
  CONSTRAINT chk_desc_max_len      CHECK (description IS NULL OR char_length(description) <= 500),
  CONSTRAINT chk_end_after_start   CHECK (end_at IS NULL OR end_at > start_at),
  CONSTRAINT chk_min_participants  CHECK (minimum_participants IS NULL OR minimum_participants >= 1),
  CONSTRAINT chk_desc_blocks_max   CHECK (description_blocks IS NULL OR jsonb_array_length(description_blocks) <= 20),
  CONSTRAINT chk_image_urls_max    CHECK (image_urls IS NULL OR array_length(image_urls, 1) <= 3),

  -- 타입별 필드 정합성
  CONSTRAINT chk_schedule_type_fields CHECK (
    (schedule_type = 'group'
      AND group_id IS NOT NULL
      AND minimum_participants IS NOT NULL
      AND is_confirmed IS NOT NULL
      AND vote_deadline IS NOT NULL)
    OR
    (schedule_type = 'personal'
      AND group_id IS NULL
      AND minimum_participants IS NULL
      AND is_confirmed IS NULL
      AND vote_deadline IS NULL
      AND tracking_start_minutes_before IS NULL
      AND image_urls IS NULL)
  )
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 자동 생성 UUID |
| schedule_type | schedule_type | NOT NULL | `group` / `personal` |
| user_id | TEXT | NOT NULL, FK → users.id CASCADE | personal: 소유자, group: 호스트 |
| title | TEXT | NOT NULL, 1~30자 | 일정 제목 |
| emoji | TEXT | nullable | 대표 이모지 |
| description | TEXT | nullable, 최대 500자 | 일정 설명 |
| description_blocks | JSONB | nullable, 최대 20개 | 구조화된 설명 블록 |
| start_at | TIMESTAMPTZ | NOT NULL | 시작 시각 |
| end_at | TIMESTAMPTZ | nullable, > start_at | 종료 시각 |
| location_* | TEXT/DOUBLE | nullable | 장소 정보 (name, address, lat, lng) |
| group_id | UUID | FK → groups.id CASCADE | 그룹일정 전용 |
| minimum_participants | SMALLINT | >= 1 | 최소 확정 인원 |
| is_confirmed | BOOLEAN | | accepted >= minimum_participants |
| vote_deadline | TIMESTAMPTZ | | 투표 마감 시각 (기본 = start_at) |
| tracking_start_minutes_before | SMALLINT | nullable | LiveActivity 시작 시간 (분) |
| image_urls | TEXT[] | 최대 3개 | 첨부 이미지 URL |
| reminder_minutes_before | SMALLINT | nullable | 개인일정 알림 (분) |

| Firestore 원본 | 비고 |
|---------------|------|
| `promises/{id}` | schedule_type = 'group'으로 통합 |
| `users/{uid}/personalEvents/{id}` | schedule_type = 'personal'로 통합 |
| `votes` Map (accepted/declined) | schedule_votes 테이블로 분리 |
| `isConfirmed` 비정규화 | 유지 (캘린더 쿼리 성능) |
| `votes.until` | vote_deadline 컬럼으로 매핑 |
| `liveActivitySchedule`, `badgesCleared` | 제거 (#7, #5에서 별도 마이그레이션) |
| `users/{uid}/scheduleSlots/{date}` | 제거 (SQL 인덱스 쿼리로 대체, 비정규화 불필요) |

## schedule_votes

그룹일정 투표. pending 상태는 group_members에서 schedule_votes를 빼서 계산.

```sql
CREATE TYPE vote_status AS ENUM ('accepted', 'declined');

CREATE TABLE schedule_votes (
  schedule_id  UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       vote_status NOT NULL,
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (schedule_id, user_id)
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| schedule_id | UUID | PK, FK → schedules.id CASCADE | 일정 ID |
| user_id | TEXT | PK, FK → users.id CASCADE | 투표자 ID |
| status | vote_status | NOT NULL | `accepted` / `declined` |
| responded_at | TIMESTAMPTZ | NOT NULL, default NOW() | 응답 시각 |

> pending = group_members - schedule_votes (저장하지 않고 계산)

| Firestore 원본 | 비고 |
|---------------|------|
| `promises/{id}.votes.accepted[]` | status = 'accepted' |
| `promises/{id}.votes.declined[]` | status = 'declined' |
| pending (memberIds - accepted - declined) | 테이블 부재로 계산 |

## recurring_schedules

반복일정 규칙. 인스턴스는 저장하지 않고 클라이언트/서버에서 규칙 기반 계산.

```sql
CREATE TYPE recurrence_frequency AS ENUM ('daily', 'weekly', 'monthly');

CREATE TABLE recurring_schedules (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                   TEXT NOT NULL,
  emoji                   TEXT,
  description             TEXT,
  start_time_hour         SMALLINT NOT NULL,
  start_time_minute       SMALLINT NOT NULL,
  end_time_hour           SMALLINT,
  end_time_minute         SMALLINT,
  location_name           TEXT,
  location_address        TEXT,
  location_latitude       DOUBLE PRECISION,
  location_longitude      DOUBLE PRECISION,
  reminder_minutes_before SMALLINT,
  frequency               recurrence_frequency NOT NULL,
  days_of_week            SMALLINT[],        -- weekly: [1=일..7=토]
  day_of_month            SMALLINT,           -- monthly: 1~31
  series_start_date       DATE NOT NULL,
  series_end_date         DATE,               -- NULL = 무기한
  excluded_dates          DATE[],
  overrides               JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_rec_title_not_empty    CHECK (char_length(trim(title)) > 0),
  CONSTRAINT chk_start_hour             CHECK (start_time_hour BETWEEN 0 AND 23),
  CONSTRAINT chk_start_minute           CHECK (start_time_minute BETWEEN 0 AND 59),
  CONSTRAINT chk_end_hour               CHECK (end_time_hour IS NULL OR end_time_hour BETWEEN 0 AND 23),
  CONSTRAINT chk_end_minute             CHECK (end_time_minute IS NULL OR end_time_minute BETWEEN 0 AND 59),
  CONSTRAINT chk_end_time_pair          CHECK (
    (end_time_hour IS NULL AND end_time_minute IS NULL) OR
    (end_time_hour IS NOT NULL AND end_time_minute IS NOT NULL)
  ),
  -- frequency별 상호배타 필드 정합성
  CONSTRAINT chk_recurrence_fields CHECK (
    (frequency = 'daily'
      AND days_of_week IS NULL
      AND day_of_month IS NULL)
    OR
    (frequency = 'weekly'
      AND days_of_week IS NOT NULL
      AND array_length(days_of_week, 1) > 0
      AND day_of_month IS NULL)
    OR
    (frequency = 'monthly'
      AND days_of_week IS NULL
      AND day_of_month IS NOT NULL
      AND day_of_month BETWEEN 1 AND 31)
  ),
  CONSTRAINT chk_series_end_after_start CHECK (series_end_date IS NULL OR series_end_date >= series_start_date)
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 자동 생성 UUID |
| user_id | TEXT | FK → users.id CASCADE | 소유자 |
| title | TEXT | NOT NULL, 비어있지 않음 | 일정 제목 |
| emoji | TEXT | nullable | 대표 이모지 |
| description | TEXT | nullable | 일정 설명 |
| start_time_hour/minute | SMALLINT | NOT NULL, 0~23/0~59 | 시작 시각 |
| end_time_hour/minute | SMALLINT | nullable, 쌍으로 존재 | 종료 시각 |
| location_* | TEXT/DOUBLE | nullable | 장소 정보 |
| reminder_minutes_before | SMALLINT | nullable | 알림 시간 (분) |
| frequency | recurrence_frequency | NOT NULL | `daily` / `weekly` / `monthly` |
| days_of_week | SMALLINT[] | weekly 필수 | 반복 요일 [1=일..7=토] |
| day_of_month | SMALLINT | monthly 필수, 1~31 | 반복 일자 |
| series_start_date | DATE | NOT NULL | 반복 시작일 |
| series_end_date | DATE | nullable, >= start | 반복 종료일 (NULL=무기한) |
| excluded_dates | DATE[] | nullable | 취소된 날짜 |
| overrides | JSONB | nullable | 날짜별 수정 `{"2026-03-24": {...}}` |

| Firestore 원본 | 비고 |
|---------------|------|
| `users/{uid}/recurringEvents/{id}` | 별도 테이블 유지 (규칙 vs 인스턴스) |
| `recurrence` Map | frequency + days_of_week + day_of_month로 분해 |
| `startTime`/`endTime` Map | hour/minute 개별 컬럼으로 분해 |

## 인덱스

| 인덱스명 | 대상 테이블 | 컬럼 | 종류 | 목적 |
|---------|-----------|------|------|------|
| uq_users_nickname | users | nickname | UNIQUE | 닉네임 중복 방지 (constraint name으로 에러 분기) |
| uq_groups_invite_code | groups | invite_code | UNIQUE | 초대 코드 충돌 방지 |
| uq_group_members_single_admin | group_members | group_id WHERE role='admin' | PARTIAL UNIQUE | 그룹당 admin 1명 강제 |
| idx_group_members_user_joined_at | group_members | (user_id, joined_at DESC) | INDEX | 내 그룹 목록 최신순 조회 최적화 |
| idx_schedules_group_start | schedules | (group_id, start_at) WHERE type='group' | PARTIAL INDEX | 그룹일정 시간순 조회 |
| idx_schedules_personal_start | schedules | (user_id, start_at) WHERE type='personal' | PARTIAL INDEX | 개인일정 시간순 조회 |
| idx_schedules_confirmed | schedules | (start_at) WHERE type='group' AND is_confirmed | PARTIAL INDEX | 캘린더 동기화 (확정 미래 일정) |
| idx_schedule_votes_user | schedule_votes | (user_id, status) | INDEX | 유저의 accepted 일정 조회 |
| idx_recurring_user | recurring_schedules | (user_id) | INDEX | 유저의 반복일정 조회 |

## 타입

| 타입명 | 종류 | 값 | 설명 |
|--------|------|-----|------|
| group_member_role | ENUM | 'admin', 'member' | 그룹 내 역할 |
| schedule_type | ENUM | 'group', 'personal' | 일정 구분 |
| vote_status | ENUM | 'accepted', 'declined' | 투표 상태 (pending = 부재) |
| recurrence_frequency | ENUM | 'daily', 'weekly', 'monthly' | 반복 주기 |

## scheduleSlots 제거 근거

Firestore에서는 `users/{uid}/scheduleSlots/{YYYY-MM-DD}` 비정규화 컬렉션으로 O(1) 충돌 체크를 구현하고, 7개 트리거로 동기화를 유지했다.

PostgreSQL에서는 SQL 인덱스 쿼리로 동일한 성능을 달성할 수 있어 비정규화가 불필요하다:

```sql
-- 충돌 감지: 유저의 모든 일정을 시간 범위로 조회
SELECT s.id, s.title, s.start_at, s.end_at FROM schedules s
JOIN schedule_votes sv ON sv.schedule_id = s.id
WHERE sv.user_id = $1 AND sv.status = 'accepted'
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL)
UNION ALL
SELECT s.id, s.title, s.start_at, s.end_at FROM schedules s
WHERE s.schedule_type = 'personal' AND s.user_id = $1
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL);
-- + recurring_schedules는 앱 레벨에서 규칙 기반 확장
```

*마지막 업데이트: 2026-04-06*
