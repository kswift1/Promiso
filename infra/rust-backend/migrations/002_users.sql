CREATE TABLE users (
    id                   TEXT PRIMARY KEY,
    name                 TEXT NOT NULL,
    nickname             TEXT NOT NULL,
    provider_type        TEXT NOT NULL,
    provider_uid         TEXT NOT NULL,
    email                TEXT NOT NULL,
    profile_url          TEXT,
    notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_nickname_min CHECK (char_length(nickname) >= 2),
    CONSTRAINT chk_nickname_max CHECK (char_length(nickname) <= 12),
    CONSTRAINT chk_nickname_no_spaces CHECK (nickname !~ '\s'),
    UNIQUE (nickname)
);
