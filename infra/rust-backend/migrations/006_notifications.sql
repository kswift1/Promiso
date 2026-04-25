-- 006_notifications.sql

CREATE TYPE notification_type AS ENUM (
  'schedule_invitation',
  'schedule_reminder',
  'schedule_confirmed',
  'schedule_cancelled',
  'schedule_updated',
  'location_sharing_reminder',
  'group_invitation',
  'group_update',
  'attendance_response',
  'system'
);

CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  push_to_start_token TEXT,
  live_activity_push_token TEXT,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_devices_user_device UNIQUE (user_id, device_id),
  CONSTRAINT uq_devices_fcm_token UNIQUE (fcm_token),
  CONSTRAINT chk_device_platform CHECK (platform IN ('ios', 'android'))
);

CREATE INDEX idx_devices_user_id ON devices (user_id);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  schedule_id UUID REFERENCES schedules(id) ON DELETE SET NULL,
  group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
  related_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  is_delivered BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  data JSONB
);

CREATE INDEX idx_notifications_user_created
  ON notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread
  ON notifications (user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_schedule_id
  ON notifications (schedule_id) WHERE schedule_id IS NOT NULL;
CREATE INDEX idx_notifications_group_id
  ON notifications (group_id) WHERE group_id IS NOT NULL;
