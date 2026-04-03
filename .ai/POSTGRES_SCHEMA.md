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

*마지막 업데이트: 2026-04-03*
