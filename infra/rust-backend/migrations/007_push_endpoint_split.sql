CREATE TYPE notification_provider AS ENUM ('fcm');

ALTER TABLE devices DROP CONSTRAINT uq_devices_fcm_token;

ALTER TABLE devices
  DROP COLUMN fcm_token,
  DROP COLUMN push_to_start_token,
  DROP COLUMN live_activity_push_token;

CREATE TABLE notification_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  provider notification_provider NOT NULL,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_notification_endpoints_provider_token UNIQUE (provider, token),
  CONSTRAINT uq_notification_endpoints_device_provider UNIQUE (device_id, provider)
);

CREATE TABLE live_activity_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  push_to_start_token TEXT,
  live_activity_push_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_live_activity_endpoints_device UNIQUE (device_id),
  CONSTRAINT uq_live_activity_endpoints_push_to_start UNIQUE (push_to_start_token),
  CONSTRAINT uq_live_activity_endpoints_live_activity_push UNIQUE (live_activity_push_token),
  CONSTRAINT chk_live_activity_endpoints_has_token CHECK (
    push_to_start_token IS NOT NULL OR live_activity_push_token IS NOT NULL
  )
);
