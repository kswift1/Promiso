-- user_settings 테이블 확장: 그룹 정렬, 충돌 감지, 교통수단, 주소 추가

ALTER TABLE user_settings
  ADD COLUMN group_sort_type                TEXT NOT NULL DEFAULT 'joinedRecent',
  ADD COLUMN group_sort_order               TEXT[],
  ADD COLUMN conflict_threshold_min         SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN briefing_available_transports  TEXT[] NOT NULL DEFAULT '{transit,car}',
  ADD COLUMN briefing_location_address      TEXT;

ALTER TABLE user_settings
  ADD CONSTRAINT chk_group_sort_type CHECK (
    group_sort_type IN ('joinedRecent', 'joinedOldest', 'nameAscending', 'nameDescending', 'custom')
  ),
  ADD CONSTRAINT chk_conflict_threshold CHECK (conflict_threshold_min >= 0),
  ADD CONSTRAINT chk_briefing_hour CHECK (
    briefing_notification_hour IS NULL OR briefing_notification_hour BETWEEN 0 AND 23
  ),
  ADD CONSTRAINT chk_briefing_style CHECK (
    briefing_style IS NULL OR briefing_style IN ('friendly', 'humorous', 'concise', 'motivational', 'calm')
  ),
  ADD CONSTRAINT chk_briefing_transports_not_empty CHECK (
    cardinality(briefing_available_transports) >= 1
  );
