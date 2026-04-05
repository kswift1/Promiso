CREATE TYPE group_member_role AS ENUM ('admin', 'member');

CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  max_members SMALLINT NOT NULL DEFAULT 10,
  invite_code CHAR(6) NOT NULL,
  -- badge/읽음 계산용
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_group_name_len CHECK (char_length(name) BETWEEN 2 AND 12),
  CONSTRAINT chk_group_desc_len CHECK (description IS NULL OR char_length(description) <= 50),
  CONSTRAINT chk_group_max_members CHECK (max_members BETWEEN 2 AND 10),
  CONSTRAINT chk_group_invite_code CHECK (invite_code ~ '^[A-Z0-9]{6}$')
);

CREATE UNIQUE INDEX uq_groups_invite_code ON groups (invite_code);

CREATE TABLE group_members (
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role group_member_role NOT NULL DEFAULT 'member',

  group_color TEXT NOT NULL DEFAULT '#AF52DE',

  -- 알림 설정은 JSONB 대신 명시적 컬럼
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_invitation BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_reminder BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_confirmed BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_cancelled BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_updated BOOLEAN NOT NULL DEFAULT TRUE,
  attendance_response BOOLEAN NOT NULL DEFAULT TRUE,
  group_update BOOLEAN NOT NULL DEFAULT TRUE,
  calendar_sync BOOLEAN NOT NULL DEFAULT TRUE,

  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (group_id, user_id),

  CONSTRAINT chk_group_color_palette CHECK (group_color IN (
    '#FF3B30', '#FF6F61', '#FF9500', '#FFCC00',
    '#84CC16', '#34C759', '#00C7BE', '#007AFF',
    '#1E3F8A', '#AF52DE', '#C4B5FD', '#E040FB',
    '#FF6B9D', '#C2185B', '#A0845C', '#8E8E93'
  )),
  CONSTRAINT chk_last_read_at_after_joined_at
    CHECK (last_read_at >= joined_at)
);

-- 그룹당 호스트는 정확히 1명
CREATE UNIQUE INDEX uq_group_members_single_admin
  ON group_members (group_id)
  WHERE role = 'admin';

CREATE INDEX idx_group_members_user_joined_at
  ON group_members (user_id, joined_at DESC);

