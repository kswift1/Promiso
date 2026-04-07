-- LiveActivity 도메인: 스케줄 LA 상태 + 투표 LA 상태 + 예약 실행 테이블

-- schedules 테이블에 LiveActivity 관련 컬럼 추가
ALTER TABLE schedules
    ADD COLUMN la_scheduled       BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN la_started         BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN la_scheduled_at    TIMESTAMPTZ,
    ADD COLUMN la_schedule_version UUID,
    ADD COLUMN vote_channel_id    TEXT,
    ADD COLUMN vote_started_at    TIMESTAMPTZ,
    ADD COLUMN vote_ended_at      TIMESTAMPTZ,
    ADD COLUMN vote_finalized     BOOLEAN      NOT NULL DEFAULT FALSE;

-- 예약 실행 테이블 (Cloud Tasks 대체 — ADR-010)
CREATE TYPE task_status AS ENUM ('pending', 'processing', 'completed', 'failed');

CREATE TABLE scheduled_tasks (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    task_type     TEXT          NOT NULL,
    schedule_id   UUID          NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    execute_at    TIMESTAMPTZ   NOT NULL,
    payload       JSONB         NOT NULL DEFAULT '{}',
    status        task_status   NOT NULL DEFAULT 'pending',
    retry_count   SMALLINT      NOT NULL DEFAULT 0,
    max_retries   SMALLINT      NOT NULL DEFAULT 3,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- polling 성능을 위한 인덱스: pending 상태 + 실행 시각 순
CREATE INDEX idx_scheduled_tasks_pending
    ON scheduled_tasks (execute_at)
    WHERE status = 'pending';

-- schedule_id로 관련 task 조회 (재스케줄 시 기존 task 취소용)
CREATE INDEX idx_scheduled_tasks_schedule_id
    ON scheduled_tasks (schedule_id)
    WHERE status = 'pending';
