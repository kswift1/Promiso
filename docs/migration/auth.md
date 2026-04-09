# Auth Big-bang Cutover 설계

> 기준 ADR: [ADR-010](../adr/010-auth-provider-jwt-sessions.md), [ADR-011](../adr/011-storage-gcs-direct-upload.md), [ADR-012](../adr/012-app-config-postgres.md)

## 1. 범위

이번 tranche는 아래 Firebase backend 의존을 제거한다.

- Firebase Auth
- Firestore
- Cloud Functions
- Firebase Storage
- Firebase Remote Config

유지 범위:

- Firebase Messaging (FCM)
- Firebase Analytics
- Firebase Crashlytics

## 2. 스키마 재설계

### 2-1. Before / After

| 영역 | Before | After |
|------|--------|-------|
| 인증 주체 | Firebase Auth UID | Rust `auth_accounts.user_id` |
| 사용자 프로필 | `users` 테이블 | `users` 테이블 유지 |
| provider/email | `users.provider_*`, `users.email` | `auth_accounts`가 source of truth |
| 세션 | Firebase persisted session | `auth_sessions` + refresh rotation |
| 앱 운영 설정 | Firebase Remote Config | PostgreSQL `app_config` |
| 이미지 업로드 | Firebase Storage 직접 업로드 | GCS presigned upload |

### 2-2. 설계 원칙

- `users.id`는 계속 canonical user id로 사용한다.
- 기존 유저는 현재 `users.id`를 그대로 유지한다.
- 신규 유저는 auth 단계에서 `user_id`를 먼저 발급받고, 프로필 생성 시 같은 id로 `users` row를 만든다.
- 따라서 "인증은 됐지만 프로필이 없는 상태"를 별도 auth table로 표현할 수 있다.
- 이미지 메타데이터는 기존처럼 각 도메인 row의 URL 컬럼에 저장한다. 이번 tranche에서는 별도 media 테이블을 만들지 않는다.

### 2-3. 신규 테이블

#### `auth_accounts`

목적:

- provider identity와 canonical `user_id` 매핑
- 프로필 생성 전에도 인증 주체를 표현
- provider/email을 `users` lifecycle과 분리

초안:

```sql
CREATE TABLE auth_accounts (
    user_id              TEXT PRIMARY KEY,
    provider_type        TEXT NOT NULL,
    provider_uid         TEXT NOT NULL,
    email                TEXT,
    display_name         TEXT,
    profile_image_url    TEXT,
    last_login_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_auth_provider_type
      CHECK (provider_type IN ('apple', 'google')),
    UNIQUE (provider_type, provider_uid)
);
```

메모:

- 기존 `users.provider_type`, `users.provider_uid`, `users.email`는 구현 초기에는 backfill 검증용으로 남길 수 있다.
- source of truth는 `auth_accounts`로 이동한다.

#### `auth_sessions`

목적:

- refresh token 세션 저장
- 기기별 로그아웃 / 전체 로그아웃 / 세션 폐기
- access JWT는 stateless, refresh만 DB 관리

초안:

```sql
CREATE TABLE auth_sessions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              TEXT NOT NULL REFERENCES auth_accounts(user_id) ON DELETE CASCADE,
    refresh_token_hash   TEXT NOT NULL UNIQUE,
    device_id            TEXT NOT NULL,
    platform             TEXT NOT NULL DEFAULT 'ios',
    app_version          TEXT,
    user_agent           TEXT,
    last_used_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at           TIMESTAMPTZ NOT NULL,
    revoked_at           TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_sessions_user_id
ON auth_sessions (user_id);

CREATE INDEX idx_auth_sessions_active
ON auth_sessions (user_id, revoked_at, expires_at);
```

메모:

- refresh token은 평문 저장하지 않고 hash만 저장한다.
- refresh 시 같은 row의 `refresh_token_hash`를 원자적으로 교체한다.
- old refresh token 재사용은 lookup 실패로 거부한다.

#### `app_config`

목적:

- force/recommended update를 배포 없이 변경
- Remote Config 대체

초안:

```sql
CREATE TABLE app_config (
    singleton               BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    force_update_version    TEXT NOT NULL DEFAULT '0.0.0',
    recommended_version     TEXT NOT NULL DEFAULT '0.0.0',
    app_store_url           TEXT NOT NULL,
    privacy_policy_url      TEXT NOT NULL,
    terms_of_service_url    TEXT NOT NULL,
    support_email           TEXT NOT NULL,
    notion_faq_database_id  TEXT NOT NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

메모:

- single-row 테이블로 시작한다.
- admin API 없이도 SQL update로 운영 가능하다.

### 2-4. 테이블 분리 근거

#### `auth_accounts`를 `users`에서 분리하는 이유

- 인증은 되었지만 `users` 프로필이 아직 없는 상태를 표현해야 한다.
- provider/email lifecycle은 프로필 lifecycle과 다르다.
- PostgreSQL에서 "auth principal"과 "profile"은 독립 생명주기다.

#### `auth_sessions`가 별도 테이블인 이유

- 세션은 다중 기기 N:1 관계다.
- refresh token 회전/폐기라는 독립 생명주기가 있다.
- `users` 또는 `auth_accounts` 한 row에 묻으면 multi-device 제어가 깨진다.

#### upload metadata 테이블을 이번에 만들지 않는 이유

- 현재 도메인 모델이 `profile_url`, `image_url`, `image_urls` 문자열을 직접 사용한다.
- 이번 tranche 목표는 Firebase backend 제거이지 media domain 재설계가 아니다.
- object key prefix를 entity/owner 기준으로 통제하면 별도 upload table 없이도 소유권 검증이 가능하다.

## 3. GCS Object Key 규칙

도메인별 소유 주체가 다르므로 prefix를 entity/owner 기준으로 고정한다.

| 용도 | Prefix |
|------|--------|
| 프로필 이미지 | `profile_images/{user_id}/{upload_id}.jpg` |
| 그룹 이미지 | `group_images/{group_id}/{upload_id}.jpg` |
| 그룹 일정 이미지 | `schedule_images/{group_id}/{schedule_id}/{upload_id}.jpg` |
| 개인 일정 이미지 | `personal_event_images/{user_id}/{event_id}/{upload_id}.jpg` |

검증 규칙:

- 프로필 이미지 URL은 `profile_images/{claims.uid}/` prefix만 허용
- 그룹 이미지는 `group_id` admin만 발급/삭제 가능
- 그룹 일정 이미지는 해당 `group_id` 멤버만 발급/삭제 가능
- 개인 일정 이미지는 `user_id == claims.uid`만 발급/삭제 가능
- schedule image는 최대 3개 유지

## 4. API 설계

### 4-1. Public Auth / Config

| 메서드 | 경로 | 설명 |
|-------|------|------|
| `POST` | `/api/v1/auth/apple` | Apple provider token 검증 후 access/refresh 발급 |
| `POST` | `/api/v1/auth/google` | Google provider token 검증 후 access/refresh 발급 |
| `POST` | `/api/v1/auth/refresh` | refresh token 회전 |
| `GET` | `/api/v1/app-config` | 앱 운영 설정 조회 |

#### `POST /api/v1/auth/apple`

요청:

```json
{
  "identityToken": "jwt",
  "authorizationCode": "code",
  "userIdentifier": "apple-user-id",
  "email": "user@example.com",
  "fullName": "홍길동",
  "deviceId": "ios-device-id",
  "appVersion": "1.2.3"
}
```

응답:

```json
{
  "accessToken": "jwt",
  "refreshToken": "opaque",
  "expiresAt": "2026-04-09T12:00:00Z",
  "user": {
    "userId": "user_xxx",
    "email": "user@example.com",
    "provider": "apple",
    "displayName": "홍길동",
    "profileImageUrl": null
  },
  "hasProfile": false
}
```

#### `POST /api/v1/auth/google`

요청:

```json
{
  "idToken": "jwt",
  "accessToken": "token",
  "userIdentifier": "google-user-id",
  "email": "user@example.com",
  "fullName": "홍길동",
  "profileImageUrl": "https://...",
  "deviceId": "ios-device-id",
  "appVersion": "1.2.3"
}
```

응답 형태는 Apple과 동일.

#### `POST /api/v1/auth/refresh`

요청:

```json
{
  "refreshToken": "opaque",
  "deviceId": "ios-device-id"
}
```

응답:

```json
{
  "accessToken": "jwt",
  "refreshToken": "rotated-opaque",
  "expiresAt": "2026-04-09T12:00:00Z"
}
```

### 4-2. Authenticated Auth / Upload

| 메서드 | 경로 | 설명 |
|-------|------|------|
| `GET` | `/api/v1/auth/me` | 현재 인증 주체 조회 |
| `POST` | `/api/v1/auth/logout` | 현재 세션 폐기 |
| `POST` | `/api/v1/auth/logout-all` | 해당 유저의 모든 세션 폐기 |
| `POST` | `/api/v1/users/me/profile-image/upload-url` | 프로필 이미지 upload URL 발급 |
| `POST` | `/api/v1/groups/{id}/image-upload-url` | 그룹 이미지 upload URL 발급 |
| `POST` | `/api/v1/media/upload-urls` | 일정/개인 일정 이미지 upload URL 발급 |
| `POST` | `/api/v1/media/delete-urls` | 기존 이미지 cleanup용 delete URL 발급 |
| `DELETE` | `/api/v1/users/me` | 회원 탈퇴 |

#### `POST /api/v1/media/upload-urls`

요청:

```json
{
  "basePath": "schedule_images/{group_id}/{schedule_id}",
  "count": 2,
  "contentType": "image/jpeg",
}
```

응답:

```json
{
  "data": [
    {
      "uploadUrl": "https://storage.googleapis.com/...",
      "publicUrl": "https://storage.googleapis.com/bucket/schedule_images/{group_id}/{schedule_id}/upload.jpg",
      "objectPath": "schedule_images/{group_id}/{schedule_id}/upload.jpg",
      "expiresAt": "2026-04-09T12:00:00Z",
      "contentType": "image/jpeg"
    }
  ]
}
```

#### `POST /api/v1/media/delete-urls`

요청:

```json
{
  "targets": [
    "schedule_images/{group_id}/{schedule_id}/upload.jpg",
    "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/schedule_images%2F{group_id}%2F{schedule_id}%2Fupload.jpg?alt=media&token=..."
  ]
}
```

응답:

```json
{
  "data": [
    {
      "deleteUrl": "https://storage.googleapis.com/...",
      "objectPath": "schedule_images/{group_id}/{schedule_id}/upload.jpg",
      "expiresAt": "2026-04-09T12:00:00Z"
    }
  ]
}
```

### 4-3. 기존 도메인 API 변경점

#### Users

- `POST /api/v1/users`
  - 더 이상 provider 정보를 body에서 받지 않는다.
  - claims.uid 기준으로 `users` row를 생성한다.
- `POST /api/v1/users/me/profile-image`
  - 업로드 완료 후 `image_path`를 받아 검증 후 저장한다.
- `DELETE /api/v1/users/me`
  - 기존 Firebase Function `deleteUser` 대체

#### Groups / Schedules

- 기존 `imageUrl`, `imageUrls` 필드는 유지한다.
- 단, 서버가 GCS bucket host + entity prefix를 검증한다.

## 5. iOS 흐름 변경

### 로그인

1. Apple/Google SDK로 provider token 획득
2. `POST /api/v1/auth/{provider}`
3. `accessToken`은 메모리/secure storage에 저장
4. `refreshToken`은 Keychain 저장
5. 이후 `RustAPIClient`는 Firebase ID token 대신 access JWT 사용

### 세션 복원

1. access token이 유효하면 그대로 사용
2. 만료되었으면 refresh token으로 `/api/v1/auth/refresh`
3. refresh 실패 시 로그아웃

### 프로필 이미지 업로드

1. `POST /api/v1/users/me/profile-image/upload-url` 요청
2. 앱이 GCS로 직접 PUT
3. `POST /api/v1/users/me/profile-image`로 `image_path` 반영

### 일정/개인 일정 이미지 업로드

1. `POST /api/v1/media/upload-urls`
2. 앱이 GCS로 직접 PUT
3. schedule/personal event 수정 API에 `image_urls` 반영

### 일정/개인 일정 이미지 삭제

1. 제거 대상 기존 URL/path를 수집
2. `POST /api/v1/media/delete-urls`
3. 앱이 signed DELETE URL로 best-effort cleanup

## 6. 구현 순서

1. DB migration
   - `auth_accounts`
   - `auth_sessions`
   - `app_config`
   - existing users backfill
2. auth routes/service
3. app-config public route
4. upload/delete URL routes
5. `users/groups/schedules` image URL validation
6. iOS token store + RustAPIClient 교체
7. Firebase Auth/Functions/Storage/RemoteConfig 제거

## 7. 검증 포인트

- 신규 로그인/기존 로그인 모두 같은 `user_id`로 복구되는가
- 프로필 없는 신규 유저가 `hasProfile=false`로 onboarding에 진입하는가
- refresh rotation 후 old refresh token 재사용이 거부되는가
- `DELETE /api/v1/users/me`가 host/user/image cleanup 규칙을 그대로 지키는가
- profile/group/schedule 이미지가 Firebase 없이 업로드/표시되는가
- `GET /api/v1/app-config`만으로 강제 업데이트가 동작하는가
