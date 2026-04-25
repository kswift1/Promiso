-- 개인 일정도 image_urls를 가질 수 있도록 CHECK 제약 수정
ALTER TABLE schedules DROP CONSTRAINT chk_schedule_type_fields;

ALTER TABLE schedules ADD CONSTRAINT chk_schedule_type_fields CHECK (
  (schedule_type = 'group'
    AND group_id IS NOT NULL
    AND minimum_participants IS NOT NULL
    AND is_confirmed IS NOT NULL
    AND vote_deadline IS NOT NULL)
  OR
  (schedule_type = 'personal'
    AND group_id IS NULL
    AND minimum_participants IS NULL
    AND is_confirmed IS NULL
    AND vote_deadline IS NULL
    AND tracking_start_minutes_before IS NULL)
);
