CREATE TABLE briefing_cache (
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date_key    DATE NOT NULL,
    prompt_key  CHAR(16) NOT NULL,
    summary     TEXT NOT NULL,
    detail      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, date_key)
);
