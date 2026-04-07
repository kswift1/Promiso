-- Briefing cutover 최소 스키마
-- subscription authority는 Rust로 이동하지만, briefing은 settings + entitlement 조합이 필요하다.

CREATE TABLE user_settings (
    user_id                           TEXT PRIMARY KEY,
    briefing_notification_hour        SMALLINT,
    briefing_timezone                 TEXT,
    briefing_language                 TEXT,
    briefing_style                    TEXT,
    briefing_default_location_title   TEXT,
    briefing_default_location_latitude DOUBLE PRECISION,
    briefing_default_location_longitude DOUBLE PRECISION,
    created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE briefing_subscriptions (
    user_id                    TEXT PRIMARY KEY,
    notification_hour          SMALLINT    NOT NULL,
    timezone                   TEXT        NOT NULL,
    language                   TEXT        NOT NULL,
    style                      TEXT        NOT NULL,
    next_dispatch_at           TIMESTAMPTZ NOT NULL,
    default_location_title     TEXT,
    default_location_latitude  DOUBLE PRECISION,
    default_location_longitude DOUBLE PRECISION,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_briefing_subscriptions_next_dispatch_at
    ON briefing_subscriptions (next_dispatch_at);
