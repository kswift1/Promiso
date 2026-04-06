-- 005_schedules.sql
-- 일정 도메인: 그룹일정 + 개인일정 통합 테이블, 투표, 반복일정

-- ============================================================
-- 타입 정의
-- ============================================================
CREATE TYPE schedule_type AS ENUM ('group', 'personal');
CREATE TYPE vote_status   AS ENUM ('accepted', 'declined');
CREATE TYPE recurrence_frequency AS ENUM ('daily', 'weekly', 'monthly');

-- ============================================================
-- schedules (그룹일정 + 개인일정 통합)
-- ============================================================
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

-- ============================================================
-- schedule_votes (그룹일정 투표)
-- ============================================================
CREATE TABLE schedule_votes (
  schedule_id  UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       vote_status NOT NULL,
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (schedule_id, user_id)
);

-- ============================================================
-- recurring_schedules (반복일정 규칙)
-- ============================================================
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
  days_of_week            SMALLINT[],
  day_of_month            SMALLINT,
  series_start_date       DATE NOT NULL,
  series_end_date         DATE,
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

-- ============================================================
-- 인덱스
-- ============================================================

-- 그룹일정 시간순 조회
CREATE INDEX idx_schedules_group_start
  ON schedules (group_id, start_at)
  WHERE schedule_type = 'group';

-- 개인일정 시간순 조회
CREATE INDEX idx_schedules_personal_start
  ON schedules (user_id, start_at)
  WHERE schedule_type = 'personal';

-- 캘린더 동기화 (확정된 미래 일정)
CREATE INDEX idx_schedules_confirmed
  ON schedules (start_at)
  WHERE schedule_type = 'group' AND is_confirmed = TRUE;

-- 유저의 투표 상태별 일정 조회
CREATE INDEX idx_schedule_votes_user
  ON schedule_votes (user_id, status);

-- 유저의 반복일정 조회
CREATE INDEX idx_recurring_user
  ON recurring_schedules (user_id);
