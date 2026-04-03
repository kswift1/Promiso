CREATE TABLE groups (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT NOT NULL,
    description  TEXT,
    image_url    TEXT,
    max_members  INTEGER NOT NULL DEFAULT 10,
    invite_code  TEXT NOT NULL UNIQUE,
    created_by   TEXT NOT NULL REFERENCES users(id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_group_name_min     CHECK (char_length(name) >= 2),
    CONSTRAINT chk_group_name_max     CHECK (char_length(name) <= 12),
    CONSTRAINT chk_group_desc_max     CHECK (description IS NULL OR char_length(description) <= 50),
    CONSTRAINT chk_group_max_members_min  CHECK (max_members >= 2),
    CONSTRAINT chk_group_max_members_max  CHECK (max_members <= 10),
    CONSTRAINT chk_group_invite_code  CHECK (invite_code ~ '^[A-Z0-9]{6}$')
);

CREATE TABLE group_members (
    group_id               UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id                TEXT NOT NULL REFERENCES users(id),
    role                   TEXT NOT NULL DEFAULT 'member',
    group_color            TEXT NOT NULL DEFAULT 'purple',
    notification_settings  JSONB NOT NULL DEFAULT '{"enabled": true, "promise": true, "group": true, "calendar_sync": true}',
    calendar_sync          BOOLEAN NOT NULL DEFAULT TRUE,
    last_read_at           TIMESTAMPTZ,
    joined_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id),
    CONSTRAINT chk_member_role CHECK (role IN ('admin', 'member'))
);

CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE UNIQUE INDEX idx_groups_invite_code ON groups(invite_code);
