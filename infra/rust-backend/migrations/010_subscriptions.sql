-- Subscription 도메인: App Store 검증 상태 + entitlement read model + admin audit 기반

CREATE TYPE subscription_status AS ENUM (
    'none',
    'subscribed',
    'lifetime',
    'expired',
    'grace_period',
    'revoked'
);

CREATE TYPE entitlement_source AS ENUM (
    'subscription',
    'override',
    'none'
);

CREATE TYPE admin_role AS ENUM (
    'owner',
    'support',
    'marketer'
);

CREATE TABLE subscriptions (
    user_id                       TEXT                PRIMARY KEY,
    status                        subscription_status NOT NULL,
    product_id                    TEXT,
    original_transaction_id       TEXT,
    expiration_date               TIMESTAMPTZ,
    purchase_date                 TIMESTAMPTZ,
    latest_app_store_signed_date  BIGINT,
    latest_transaction_id         TEXT,
    last_notification_type        TEXT,
    last_offer_type               INTEGER,
    last_offer_identifier         TEXT,
    created_at                    TIMESTAMPTZ         NOT NULL DEFAULT now(),
    updated_at                    TIMESTAMPTZ         NOT NULL DEFAULT now()
);

CREATE TABLE subscription_owners (
    original_transaction_id  TEXT        PRIMARY KEY,
    user_id                  TEXT        NOT NULL,
    product_id               TEXT        NOT NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE entitlement_overrides (
    user_id           TEXT        PRIMARY KEY,
    is_active         BOOLEAN     NOT NULL DEFAULT FALSE,
    override_type     TEXT        NOT NULL,
    reason            TEXT,
    expires_at        TIMESTAMPTZ,
    created_by        TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at        TIMESTAMPTZ,
    revoked_by        TEXT,
    revoked_reason    TEXT
);

CREATE TABLE entitlements (
    user_id                TEXT                PRIMARY KEY,
    has_pro                BOOLEAN             NOT NULL,
    source                 entitlement_source  NOT NULL,
    subscription_status    subscription_status,
    product_id             TEXT,
    expiration_date        TIMESTAMPTZ,
    override_active        BOOLEAN             NOT NULL,
    override_expires_at    TIMESTAMPTZ,
    override_type          TEXT,
    last_offer_type        INTEGER,
    last_offer_identifier  TEXT,
    updated_at             TIMESTAMPTZ         NOT NULL DEFAULT now()
);

CREATE TABLE admin_users (
    user_id      TEXT        PRIMARY KEY,
    email        TEXT,
    role         admin_role  NOT NULL,
    enabled      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE admin_audit_logs (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id     TEXT        NOT NULL,
    action       TEXT        NOT NULL,
    target_id    TEXT,
    target_type  TEXT,
    before_data  JSONB,
    after_data   JSONB,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_subscriptions_status
    ON subscriptions (status);

CREATE INDEX idx_subscriptions_offer_updated_at
    ON subscriptions (last_offer_type, updated_at DESC);

CREATE INDEX idx_subscription_owners_user_id
    ON subscription_owners (user_id);

CREATE INDEX idx_entitlements_has_pro
    ON entitlements (has_pro);

CREATE INDEX idx_entitlement_overrides_active
    ON entitlement_overrides (is_active);

CREATE INDEX idx_admin_audit_logs_target_created_at
    ON admin_audit_logs (target_id, created_at DESC);
