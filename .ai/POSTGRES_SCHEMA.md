# PostgreSQL 스키마

> SSOT는 `infra/rust-backend/migrations/*.sql`. 이 문서는 현재 전체 스키마의 사람용 요약.

## users

```sql
CREATE TABLE users (
    id                   TEXT PRIMARY KEY,       -- Firebase Auth UID
    name                 TEXT NOT NULL,
    nickname             TEXT NOT NULL,
    provider_type        TEXT NOT NULL,           -- 'apple' | 'google'
    provider_uid         TEXT NOT NULL,
    email                TEXT NOT NULL,
    profile_url          TEXT,                    -- NULL = 프로필 이미지 없음
    notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_nickname_min CHECK (char_length(nickname) >= 2),
    CONSTRAINT chk_nickname_max CHECK (char_length(nickname) <= 12),
    CONSTRAINT chk_nickname_no_spaces CHECK (nickname !~ '\s'),
    UNIQUE (nickname)
);
```

| 컬럼 | Firestore 원본 | 비고 |
|------|---------------|------|
| id | 문서 ID (`users/{userId}`) | Firebase Auth UID 유지 |
| name, nickname | 메인 문서 필드 | |
| provider_type, provider_uid, email | `auth/main` 서브컬렉션 | 단일 테이블로 합침 |
| profile_url | `profile.url` 필드 | thumbUrl, updatedAt 제거 |
| notification_enabled | `settings/main` 서브컬렉션 | 나머지 settings는 미마이그레이션 |

## groups

```sql
CREATE TABLE groups (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  description      TEXT,
  image_url        TEXT,
  max_members      SMALLINT NOT NULL DEFAULT 10,
  invite_code      CHAR(6) NOT NULL,
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_group_name_len    CHECK (char_length(name) BETWEEN 2 AND 12),
  CONSTRAINT chk_group_desc_len    CHECK (description IS NULL OR char_length(description) <= 50),
  CONSTRAINT chk_group_max_members CHECK (max_members BETWEEN 2 AND 10),
  CONSTRAINT chk_group_invite_code CHECK (invite_code ~ '^[A-Z0-9]{6}$')
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 자동 생성 UUID |
| name | TEXT | NOT NULL, 2-12자 | 그룹 이름 (수정 불가) |
| description | TEXT | nullable, 최대 50자 | 그룹 설명 |
| image_url | TEXT | nullable | 그룹 대표 이미지 URL |
| max_members | SMALLINT | NOT NULL, 2-10, default 10 | 최대 인원 |
| invite_code | CHAR(6) | NOT NULL, A-Z0-9 패턴, UNIQUE | 초대 코드 |
| last_activity_at | TIMESTAMPTZ | NOT NULL, default NOW() | 최근 활동 시각 (배지 계산용) |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | 생성 시각 |
| updated_at | TIMESTAMPTZ | NOT NULL, default NOW() | 수정 시각 |

| Firestore 원본 | 비고 |
|---------------|------|
| `groups/{groupId}` 문서 | 문서 ID는 UUID로 재생성 (Firestore는 자동 ID, PostgreSQL은 gen_random_uuid()) |
| `memberIds` 배열 | 비정규화 제거 — `group_members` 테이블로 분리 |
| `createdBy` | `group_members` 테이블의 `role = 'admin'`으로 표현 |

## group_members

```sql
CREATE TYPE group_member_role AS ENUM ('admin', 'member');

CREATE TABLE group_members (
  group_id                UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role                    group_member_role NOT NULL DEFAULT 'member',
  group_color             TEXT NOT NULL DEFAULT '#AF52DE',

  -- 알림 설정 (JSONB 대신 명시적 컬럼)
  notifications_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_invitation     BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_reminder       BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_confirmed      BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_cancelled      BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_updated        BOOLEAN NOT NULL DEFAULT TRUE,
  attendance_response     BOOLEAN NOT NULL DEFAULT TRUE,
  group_update            BOOLEAN NOT NULL DEFAULT TRUE,
  calendar_sync           BOOLEAN NOT NULL DEFAULT TRUE,

  joined_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (group_id, user_id),

  CONSTRAINT chk_group_color_palette CHECK (group_color IN (
    '#FF3B30', '#FF6F61', '#FF9500', '#FFCC00',
    '#84CC16', '#34C759', '#00C7BE', '#007AFF',
    '#1E3F8A', '#AF52DE', '#C4B5FD', '#E040FB',
    '#FF6B9D', '#C2185B', '#A0845C', '#8E8E93'
  )),
  CONSTRAINT chk_last_read_at_after_joined_at CHECK (last_read_at >= joined_at)
);
```

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| group_id | UUID | PK, FK → groups.id CASCADE | 그룹 ID |
| user_id | TEXT | PK, FK → users.id CASCADE | 유저 ID (Firebase UID) |
| role | group_member_role | NOT NULL, default 'member' | 역할 (admin / member) |
| group_color | TEXT | NOT NULL, default '#AF52DE', 16가지 팔레트 | 개인별 그룹 색상 |
| notifications_enabled | BOOLEAN | NOT NULL, default TRUE | 전체 알림 ON/OFF |
| schedule_invitation | BOOLEAN | NOT NULL, default TRUE | 일정 초대 알림 |
| schedule_reminder | BOOLEAN | NOT NULL, default TRUE | 일정 리마인더 알림 |
| schedule_confirmed | BOOLEAN | NOT NULL, default TRUE | 일정 확정 알림 |
| schedule_cancelled | BOOLEAN | NOT NULL, default TRUE | 일정 취소 알림 |
| schedule_updated | BOOLEAN | NOT NULL, default TRUE | 일정 수정 알림 |
| attendance_response | BOOLEAN | NOT NULL, default TRUE | 참석 응답 알림 |
| group_update | BOOLEAN | NOT NULL, default TRUE | 그룹 정보 변경 알림 |
| calendar_sync | BOOLEAN | NOT NULL, default TRUE | 캘린더 동기화 여부 |
| joined_at | TIMESTAMPTZ | NOT NULL, default NOW() | 가입 시각 |
| last_read_at | TIMESTAMPTZ | NOT NULL, default NOW(), >= joined_at | 마지막 읽음 시각 |

| Firestore 원본 | 비고 |
|---------------|------|
| `users/{uid}.groups` Map | 비정규화 Map을 정규화된 조인 테이블로 전환 |
| `groups/{id}.memberIds` 배열 | 동일, group_members로 흡수 |
| 알림 설정 (`groups` Map의 notifications) | JSONB 없이 명시적 컬럼으로 관리 |

## 인덱스

| 인덱스명 | 대상 테이블 | 컬럼 | 종류 | 목적 |
|---------|-----------|------|------|------|
| uq_users_nickname | users | nickname | UNIQUE | 닉네임 중복 방지 (constraint name으로 에러 분기) |
| uq_groups_invite_code | groups | invite_code | UNIQUE | 초대 코드 충돌 방지 |
| uq_group_members_single_admin | group_members | group_id WHERE role='admin' | PARTIAL UNIQUE | 그룹당 admin 1명 강제 |
| idx_group_members_user_joined_at | group_members | (user_id, joined_at DESC) | INDEX | 내 그룹 목록 최신순 조회 최적화 |

## 타입

| 타입명 | 종류 | 값 | 설명 |
|--------|------|-----|------|
| group_member_role | ENUM | 'admin', 'member' | 그룹 내 역할 |

*마지막 업데이트: 2026-04-05*
