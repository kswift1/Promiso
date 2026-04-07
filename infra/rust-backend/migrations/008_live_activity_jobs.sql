CREATE TYPE live_activity_job_type AS ENUM ('start', 'end', 'nudge');

CREATE TYPE live_activity_job_status AS ENUM (
  'pending',
  'succeeded',
  'failed',
  'cancelled'
);

ALTER TABLE schedules
  ADD COLUMN live_activity_channel_id TEXT,
  ADD COLUMN live_activity_started_at TIMESTAMPTZ,
  ADD COLUMN live_activity_nudge_sent_at TIMESTAMPTZ,
  ADD COLUMN live_activity_ended_at TIMESTAMPTZ;

CREATE TABLE live_activity_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  job_type live_activity_job_type NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  status live_activity_job_status NOT NULL DEFAULT 'pending',
  locked_until TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0,
  payload JSONB,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_live_activity_jobs_attempts_non_negative CHECK (attempts >= 0)
);

CREATE INDEX idx_live_activity_jobs_pending
  ON live_activity_jobs (scheduled_at)
  WHERE status = 'pending';

CREATE INDEX idx_live_activity_jobs_schedule
  ON live_activity_jobs (schedule_id, job_type, status);
