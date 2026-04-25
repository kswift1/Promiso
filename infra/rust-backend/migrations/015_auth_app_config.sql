CREATE TABLE auth_accounts (
    user_id           TEXT PRIMARY KEY,
    provider_type     TEXT NOT NULL,
    provider_uid      TEXT NOT NULL,
    email             TEXT,
    display_name      TEXT,
    profile_image_url TEXT,
    last_login_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_auth_provider_type CHECK (provider_type IN ('apple', 'google')),
    UNIQUE (provider_type, provider_uid)
);

INSERT INTO auth_accounts (
    user_id,
    provider_type,
    provider_uid,
    email,
    display_name,
    profile_image_url,
    last_login_at,
    created_at,
    updated_at
)
SELECT
    id,
    provider_type,
    provider_uid,
    email,
    name,
    profile_url,
    updated_at,
    created_at,
    updated_at
FROM users
ON CONFLICT (user_id) DO NOTHING;

CREATE TABLE auth_sessions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            TEXT NOT NULL REFERENCES auth_accounts(user_id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    device_id          TEXT NOT NULL,
    platform           TEXT NOT NULL DEFAULT 'ios',
    app_version        TEXT,
    user_agent         TEXT,
    last_used_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at         TIMESTAMPTZ NOT NULL,
    revoked_at         TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_sessions_user_id
ON auth_sessions (user_id);

CREATE INDEX idx_auth_sessions_active
ON auth_sessions (user_id, revoked_at, expires_at);

CREATE TABLE app_config (
    singleton              BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    force_update_version   TEXT NOT NULL DEFAULT '0.0.0',
    recommended_version    TEXT NOT NULL DEFAULT '0.0.0',
    app_store_url          TEXT NOT NULL,
    privacy_policy_url     TEXT NOT NULL,
    terms_of_service_url   TEXT NOT NULL,
    support_email          TEXT NOT NULL,
    notion_faq_database_id TEXT NOT NULL,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO app_config (
    singleton,
    force_update_version,
    recommended_version,
    app_store_url,
    privacy_policy_url,
    terms_of_service_url,
    support_email,
    notion_faq_database_id
)
VALUES (
    TRUE,
    '0.0.0',
    '0.0.0',
    'https://apps.apple.com/kr/app/id6757733720',
    'https://www.notion.so/3029e497067580beb0aaf485a0dd4a02',
    'https://www.notion.so/3029e4970675802ab781e282bb92d63b',
    'support@promiso.app',
    '3029e4970675812ca3d6c852867858a2'
)
ON CONFLICT (singleton) DO NOTHING;
