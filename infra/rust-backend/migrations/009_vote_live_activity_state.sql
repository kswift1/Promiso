ALTER TABLE schedules
  ADD COLUMN vote_live_activity_channel_id TEXT,
  ADD COLUMN vote_live_activity_started_at TIMESTAMPTZ,
  ADD COLUMN vote_live_activity_finalized_at TIMESTAMPTZ,
  ADD COLUMN vote_live_activity_ended_at TIMESTAMPTZ;
