# REST API 엔드포인트

> Rust 백엔드 (`infra/rust-backend/`) API 목록

## 공통

- Base URL: Cloud Run 배포 후 결정
- 인증: `Authorization: Bearer <firebase_id_token | server_access_token>`
- 응답 포맷: `{"data": T}` (성공) / `{"error": {"code": "...", "message": "..."}}` (실패)
- snake_case (JSON)

## 인증 불필요

| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 서버 + DB 상태 확인 |
| GET | `/api/v1/faq` | FAQ 목록 조회 (Notion 프록시) |
| POST | `/api/v1/live-activity/widget/eta` | Widget ETA broadcast (X-User-Id/X-Auth-Token 필수, widget token이면 X-Device-Id 필요) |
| POST | `/api/v1/live-activity/widget/vote` | Widget vote 응답 (X-User-Id/X-Auth-Token 필수, widget token이면 X-Device-Id 필요) |
| GET | `/api/v1/places/search?q=&size=` | Kakao 장소 검색 |

### GET /api/v1/faq

- 설명: FAQ 목록 조회 (Notion 프록시)
- 인증: 불필요
- 응답 200:
  ```json
  {
    "data": [
      {
        "id": "notion-page-id",
        "question": "질문",
        "answer": "답변",
        "category": "그룹",
        "order": 1,
        "created_at": "ISO8601",
        "updated_at": "ISO8601"
      }
    ]
  }
  ```
- 에러: 412 (`NOTION_FAQ_API_KEY` 미설정)

## Users (인증 필요)

| Method | Path | 설명 | 비고 |
|--------|------|------|------|
| POST | `/api/v1/users` | 유저 생성 | body: {name?, nickname, provider} |
| GET | `/api/v1/users/me` | 본인 프로필 (private) | email, provider 포함 |
| PATCH | `/api/v1/users/me` | 닉네임 수정 | body: {nickname?} |
| DELETE | `/api/v1/users/me` | 회원 탈퇴 | 그룹 호스트면 412, subscription 이력 보존 |
| POST | `/api/v1/users/me/profile-image/upload-url` | 프로필 이미지 GCS 업로드 URL 발급 | body: {content_type?} |
| POST | `/api/v1/users/me/profile-image` | 업로드 완료된 프로필 이미지 URL 저장 | body: {image_path} |
| GET | `/api/v1/users/nickname-check?q=` | 닉네임 중복 확인 | 본인 닉네임은 available=true |
| POST | `/api/v1/users/batch` | 여러 유저 조회 (public) | body: {user_ids: [...]} |
| GET | `/api/v1/users/{id}` | 타인 프로필 (public) | 공통 그룹 체크 (groups 마이그레이션 후) |

### DELETE /api/v1/users/me

- 설명: 현재 사용자 계정 삭제
- 인증: 필수
- 동작:
  - `group_members.role = 'admin'` 그룹이 하나라도 있으면 거부
  - `auth_accounts`, `auth_sessions`, `user_settings`, `briefing_subscriptions`, `entitlements`, `entitlement_overrides`, `admin_users` 정리
  - `users` 삭제 시 `group_members`, `schedules`, `devices`, `notifications`, `briefing_cache`는 cascade 삭제
  - `subscriptions`, `subscription_owners`는 결제 이력 보존을 위해 유지
- 응답 200: `{ "data": { "success": true } }`
- 에러:
  - `412 failed-precondition`: 그룹 호스트 상태

## User Settings (인증 필요)

### GET /api/v1/users/me/settings

- 설명: 본인 설정 조회. row가 없으면 기본값 반환 (DB 삽입 없음)
- 인증: 필수
- 응답 200:
  ```json
  {
    "data": {
      "notification_enabled": true,
      "group_sort_type": "joinedRecent",
      "group_sort_order": null,
      "conflict_threshold_min": 0,
      "briefing": {
        "style": null,
        "notification_hour": null,
        "timezone": null,
        "language": null,
        "available_transports": ["transit", "car"],
        "default_location": null
      }
    }
  }
  ```
  - `notification_enabled`: 사용자 전체 알림 on/off 상태 (`users.notification_enabled`)
  - `group_sort_type`: `"joinedRecent"` | `"joinedOldest"` | `"nameAscending"` | `"nameDescending"` | `"custom"`
  - `group_sort_order`: `custom` 정렬 시 그룹 ID 배열, 나머지는 null
  - `conflict_threshold_min`: 충돌 감지 최소 간격(분). 0 = 겹칠 때만 감지
  - `briefing.available_transports`: 최소 1개 이상. 기본 `["transit", "car"]`
  - `briefing.default_location`: `{ name, address?, latitude?, longitude? }` 또는 null

### PATCH /api/v1/users/me/settings

- 설명: 설정 부분 수정. 변경할 필드만 전송 (Option 패턴)
- 인증: 필수
- 요청:
  ```json
  {
    "group_sort_type": "custom",
    "group_sort_order": ["uuid-1", "uuid-2"],
    "conflict_threshold_min": 10,
    "briefing_style": "friendly",
    "briefing_notification_hour": 8,
    "briefing_timezone": "Asia/Seoul",
    "briefing_language": "ko",
    "briefing_available_transports": ["transit"],
    "briefing_default_location": {
      "name": "집",
      "address": "서울 강남구...",
      "latitude": 37.123,
      "longitude": 127.456
    }
  }
  ```
  - 필드 생략 — 변경 없음
  - `group_sort_order`: `null` 전송 시 NULL로 초기화
  - `briefing_notification_hour`: `null` 전송 시 `briefing_timezone`, `briefing_language`도 함께 삭제 (US-7/8)
  - `briefing_default_location`: `null` 전송 시 위치 전체 삭제
  - `briefing_available_transports`: 빈 배열 불가 (400)
  - `briefing_style` 허용값: `"friendly"` | `"humorous"` | `"concise"` | `"motivational"` | `"calm"`
- 사이드이펙트: `briefing_subscriptions` projection 자동 재계산 (US-12)
- 응답 200: UserSettingsResponse (GET과 동일 구조)
- 에러: 400 (허용값 외 group_sort_type/briefing_style, 빈 available_transports, 빈 location.name)

### POST /api/v1/users/me/settings/initialize-pro

- 설명: Pro 전환 시 브리핑 기본값 일괄 세팅
- 인증: 필수
- 요청:
  ```json
  { "timezone": "Asia/Seoul" }
  ```
  - `timezone`: 필수. 브리핑 기본 timezone으로 저장
- 세팅되는 기본값:
  - `briefing_notification_hour`: 8
  - `briefing_style`: `"friendly"`
  - `briefing_timezone`: 요청 timezone
  - `briefing_language`: `"ko"`
  - `conflict_threshold_min`: 0
  - `briefing_available_transports`: `["transit", "car"]`
- 사이드이펙트: `briefing_subscriptions` projection 자동 재계산 (US-12)
- 응답 200: UserSettingsResponse (GET과 동일 구조)

## Groups

### 인증 불필요

#### GET /api/v1/groups/preview?code=XXX

- 설명: 초대 코드로 그룹 미리보기 (비로그인 사용자도 접근 가능)
- 인증: 불필요
- 쿼리 파라미터: `code` — 6자리 영숫자 초대 코드
- 응답 200:
  ```json
  {
    "data": {
      "group_id": "uuid",
      "name": "그룹명",
      "description": "설명 (nullable)",
      "image_url": "이미지 URL (nullable)",
      "member_count": 3,
      "max_members": 10,
      "preview_members": [
        { "user_id": "uid", "nickname": "닉네임", "profile_url": "URL (nullable)" }
      ]
    }
  }
  ```
- 에러: 404 (코드가 유효하지 않음)

### 인증 필요

#### POST /api/v1/groups

- 설명: 그룹 생성. 생성자는 자동으로 admin 역할 부여
- 인증: 필수
- 요청:
  ```json
  { "name": "그룹명", "description": "설명 (optional)", "max_members": 10 }
  ```
- 응답 201:
  ```json
  { "data": { "group_id": "uuid", "invite_code": "ABC123", "created_at": "ISO8601" } }
  ```
- 에러: 400 (이름 2자 미만 또는 12자 초과, 설명 50자 초과, max_members 2 미만 또는 10 초과)

#### POST /api/v1/groups/join

- 설명: 초대 코드로 그룹 참여. 참여자는 자동으로 member 역할, 기본 알림 설정 ON
- 인증: 필수
- 요청:
  ```json
  { "invite_code": "ABC123" }
  ```
- 응답 200: GroupResponse (하단 참조)
- 에러: 404 (코드 유효하지 않음), 409 (이미 가입된 그룹), 422 (정원 초과)

#### GET /api/v1/groups/me

- 설명: 내가 속한 그룹 목록 조회 (joined_at 내림차순)
- 인증: 필수
- 응답 200:
  ```json
  {
    "data": [
      {
        "group_id": "uuid",
        "name": "그룹명",
        "description": "설명 (nullable)",
        "image_url": "이미지 URL (nullable)",
        "max_members": 10,
        "member_count": 3,
        "role": "admin | member",
        "group_color": "#AF52DE",
        "has_new_activity": true,
        "joined_at": "ISO8601"
      }
    ]
  }
  ```

#### GET /api/v1/groups/{id}

- 설명: 특정 그룹 상세 조회 (그룹 멤버만 접근 가능)
- 인증: 필수
- 응답 200: GroupResponse (하단 참조)
- 에러: 404 (그룹 없음), 403 (멤버 아님)

#### PATCH /api/v1/groups/{id}

- 설명: 그룹 정보 수정 (admin만). name 필드는 수정 불가 (전송 시 400)
- 인증: 필수 (admin)
- 요청:
  ```json
  {
    "description": "새 설명",
    "max_members": 8,
    "image_url": "https://..."
  }
  ```

#### POST /api/v1/groups/{id}/image-upload-url

- 설명: 그룹 이미지 GCS direct upload용 signed URL 발급 (admin만)
- 인증: 필수 (admin)
- 요청:
  ```json
  { "content_type": "image/jpeg" }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "object_path": "group_images/{group_id}/{uuid}.jpg",
      "upload_url": "https://storage.googleapis.com/...",
      "image_url": "https://storage.googleapis.com/{bucket}/group_images/{group_id}/{uuid}.jpg",
      "expires_at": "ISO8601",
      "content_type": "image/jpeg"
    }
  }
  ```
- 에러: 403 (admin 아님), 404 (그룹 없음), 400 (지원하지 않는 content_type)
  - `description`, `image_url`: `Option<Option<String>>` 패턴
    - 필드 생략 — 변경 없음
    - `null` — 삭제 (필드를 NULL로)
    - 문자열 값 — 변경
  - `name` 필드 포함 시 400 반환 (`deny_unknown_fields`)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 400 (유효성 실패), 403 (admin 아님), 404 (그룹 없음)

#### DELETE /api/v1/groups/{id}

- 설명: 그룹 삭제 (admin만). group_members cascade 삭제
- 인증: 필수 (admin)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403 (admin 아님), 404 (그룹 없음)

#### GET /api/v1/groups/{id}/members

- 설명: 그룹 멤버 목록 조회 (그룹 멤버만 접근 가능)
- 인증: 필수 (그룹 멤버)
- 응답 200:
  ```json
  {
    "data": [
      {
        "user_id": "uid",
        "nickname": "닉네임",
        "profile_url": "URL (nullable)",
        "role": "admin | member",
        "group_color": "#AF52DE",
        "joined_at": "ISO8601"
      }
    ]
  }
  ```
- 에러: 403 (멤버 아님), 404 (그룹 없음)

#### POST /api/v1/groups/{id}/transfer-host

- 설명: 호스트 양도 (admin만). 자기 자신에게 양도 불가. 대상은 그룹 멤버여야 함
- 인증: 필수 (admin)
- 요청:
  ```json
  { "new_host_uid": "target_user_id" }
  ```
- 응답 200: `{ "data": { "success": true } }`
- 에러: 400 (자기 자신 지정, 멤버 아닌 대상), 403 (admin 아님), 404 (그룹 없음)

#### POST /api/v1/groups/{id}/expel

- 설명: 멤버 추방 (admin만). admin 자신은 추방 불가
- 인증: 필수 (admin)
- 요청:
  ```json
  { "target_uid": "target_user_id" }
  ```
- 응답 200: `{ "data": { "success": true } }`
- 에러: 400 (admin 추방 시도), 403 (admin 아님), 404 (그룹 없음 또는 대상 멤버 없음)

#### POST /api/v1/groups/{id}/leave

- 설명: 그룹 나가기 (member만). admin은 호스트 양도 또는 그룹 삭제 후 가능
- 인증: 필수 (member)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403 (admin은 나가기 불가), 404 (그룹 없음)

#### POST /api/v1/groups/{id}/mark-read

- 설명: 그룹 읽음 처리 (last_read_at 갱신). 배지 클리어 용도
- 인증: 필수 (그룹 멤버)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403 (멤버 아님), 404 (그룹 없음)

#### PATCH /api/v1/groups/{id}/notification-settings

- 설명: 개인별 알림 설정 수정 (그룹 멤버만)
- 인증: 필수 (그룹 멤버)
- 요청:
  ```json
  {
    "enabled": true,
    "schedule": {
      "invitation": true,
      "reminder": true,
      "confirmed": true,
      "cancelled": true,
      "updated": true,
      "attendance_response": true
    },
    "group": {
      "update": true
    },
    "calendar_sync": true
  }
  ```
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403 (멤버 아님), 404 (그룹 없음)

#### PATCH /api/v1/groups/{id}/color

- 설명: 개인별 그룹 색상 수정 (그룹 멤버만). 16가지 팔레트 중 하나
- 인증: 필수 (그룹 멤버)
- 요청:
  ```json
  { "color": "#AF52DE" }
  ```
  - 허용 팔레트: `#FF3B30`, `#FF6F61`, `#FF9500`, `#FFCC00`, `#84CC16`, `#34C759`, `#00C7BE`, `#007AFF`, `#1E3F8A`, `#AF52DE`, `#C4B5FD`, `#E040FB`, `#FF6B9D`, `#C2185B`, `#A0845C`, `#8E8E93`
- 응답 200: `{ "data": { "success": true } }`
- 에러: 400 (팔레트 외 색상), 403 (멤버 아님), 404 (그룹 없음)

### GroupResponse (공통 응답 구조)

GET /api/v1/groups/{id}, POST /api/v1/groups/join 응답의 `data` 필드:

```json
{
  "group_id": "uuid",
  "name": "그룹명",
  "description": "설명 (nullable)",
  "image_url": "이미지 URL (nullable)",
  "max_members": 10,
  "invite_code": "ABC123",
  "created_by": "admin_user_id",
  "member_count": 3,
  "role": "admin | member",
  "group_color": "#AF52DE",
  "notification_settings": {
    "enabled": true,
    "schedule": {
      "invitation": true,
      "reminder": true,
      "confirmed": true,
      "cancelled": true,
      "updated": true,
      "attendance_response": true
    },
    "group": {
      "update": true
    },
    "calendar_sync": true
  },
  "last_read_at": "ISO8601",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

## Media (인증 필요)

### POST /api/v1/media/upload-urls

- 설명: 일정/개인 일정 이미지용 GCS direct upload signed URL 발급
- 인증: 필수
- 요청:
  ```json
  {
    "base_path": "schedule_images/{group_id}/{schedule_id}",
    "count": 2,
    "content_type": "image/jpeg"
  }
  ```
  - `base_path` 허용값:
    - `schedule_images/{group_id}/{schedule_id}`: 해당 그룹 멤버만 발급 가능
    - `personal_event_images/{user_id}/{event_id}`: `user_id == claims.uid`만 발급 가능
  - `count`: 1~3
  - `content_type`: 현재 `image/jpeg`만 지원. 생략 시 기본값 `image/jpeg`
- 응답 200:
  ```json
  {
    "data": [
      {
        "object_path": "schedule_images/{group_id}/{schedule_id}/{uuid}.jpg",
        "upload_url": "https://storage.googleapis.com/...",
        "public_url": "https://storage.googleapis.com/{bucket}/schedule_images/{group_id}/{schedule_id}/{uuid}.jpg",
        "expires_at": "ISO8601",
        "content_type": "image/jpeg"
      }
    ]
  }
  ```
- 에러: 400 (허용되지 않은 base_path/count/content_type), 403 (권한 없음)

### POST /api/v1/media/delete-urls

- 설명: 기존 이미지 cleanup용 GCS signed DELETE URL 발급
- 인증: 필수
- 요청:
  ```json
  {
    "targets": [
      "schedule_images/{group_id}/{schedule_id}/image.jpg",
      "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/schedule_images%2F{group_id}%2F{schedule_id}%2Fimage.jpg?alt=media&token=..."
    ]
  }
  ```
  - 지원 입력 형식:
    - raw object path
    - `gs://{bucket}/{object_path}`
    - `https://storage.googleapis.com/{bucket}/{object_path}`
    - Firebase download URL (`firebasestorage.googleapis.com`)
  - 권한 규칙:
    - `schedule_images/{group_id}/{schedule_id}/{file}`: 그룹 멤버
    - `personal_event_images/{user_id}/{event_id}/{file}`: 본인
    - `profile_images/{user_id}/{file}`: 본인
    - `group_images/{group_id}/{file}`: 그룹 admin
- 응답 200:
  ```json
  {
    "data": [
      {
        "object_path": "schedule_images/{group_id}/{schedule_id}/image.jpg",
        "delete_url": "https://storage.googleapis.com/...",
        "expires_at": "ISO8601"
      }
    ]
  }
  ```
- 에러: 400 (지원되지 않는 URL/path, 다른 bucket, 개수 초과), 403 (권한 없음)

## Schedules (인증 필요)

### POST /api/v1/schedules

- 설명: 일정 생성 (그룹일정 또는 개인일정)
- 인증: 필수. 그룹일정: 그룹 멤버만. 개인일정: 누구나
- 요청:
  ```json
  {
    "schedule_type": "group",
    "group_id": "uuid (group 필수)",
    "title": "영화 관람",
    "emoji": "🎬",
    "description": "마블 신작",
    "description_blocks": [{"type": "text", "content": "..."}],
    "start_at": "ISO8601",
    "end_at": "ISO8601 (optional)",
    "location": {
      "name": "CGV 강남",
      "address": "서울 강남구 ... (optional)",
      "latitude": 37.501 ,
      "longitude": 127.026
    },
    "minimum_participants": 2,
    "tracking_start_minutes_before": 30,
    "image_urls": ["https://..."],
    "reminder_minutes_before": 60
  }
  ```
  - `group_id`: group 타입 필수, personal 타입이면 생략
  - `minimum_participants`: group 타입 필수 (>= 1), personal이면 생략
  - `tracking_start_minutes_before`, `image_urls`: group 전용
  - `reminder_minutes_before`: personal 전용
  - `location`: 선택. 있으면 `name` 필수
  - `description_blocks`: 최대 20개
  - `image_urls`: 최대 3개
- 응답 201:
  ```json
  {
    "data": {
      "schedule_id": "uuid",
      "title": "영화 관람",
      "group_id": "uuid",
      "start_at": "ISO8601",
      "is_confirmed": false
    }
  }
  ```
  - 그룹일정: 호스트 자동 accepted (P16), is_confirmed 자동 계산 (P21)
  - vote_deadline = start_at (P19)
- 에러: 400 (유효성), 403 (그룹 멤버 아님), 404 (그룹 없음)

### GET /api/v1/schedules/{id}

- 설명: 일정 상세 조회
- 인증: 필수. 그룹일정: 그룹 멤버만. 개인일정: 소유자만
- 응답 200:
  ```json
  {
    "data": {
      "id": "uuid",
      "schedule_type": "group",
      "title": "영화 관람",
      "emoji": "🎬",
      "description": "마블 신작",
      "description_blocks": [...],
      "start_at": "ISO8601",
      "end_at": "ISO8601",
      "location": { "name": "...", "address": "...", "latitude": 0, "longitude": 0 },
      "created_at": "ISO8601",
      "updated_at": "ISO8601",

      "group_id": "uuid",
      "host_id": "user_id",
      "minimum_participants": 2,
      "is_confirmed": true,
      "vote_deadline": "ISO8601",
      "tracking_start_minutes_before": 30,
      "image_urls": ["..."],
      "votes": {
        "accepted": ["uid1", "uid2"],
        "declined": ["uid3"]
      },

      "reminder_minutes_before": null
    }
  }
  ```
  - 그룹일정: `votes` 포함 (accepted/declined userId 배열)
  - 개인일정: 그룹 전용 필드는 null
- 에러: 403, 404

### PATCH /api/v1/schedules/{id}

- 설명: 일정 수정
- 인증: 필수
  - 그룹일정: 약속 호스트 OR 그룹 호스트 (P10), 시작 전만 (P12), LiveActivity 중 불가 (P14)
  - 개인일정: 소유자만
- 요청: 수정할 필드만 전송 (Option 패턴)
  ```json
  {
    "title": "수정된 제목",
    "emoji": "🍿",
    "description": null,
    "start_at": "ISO8601",
    "end_at": "ISO8601",
    "location": { "name": "새 장소" },
    "minimum_participants": 3,
    "tracking_start_minutes_before": 60,
    "image_urls": ["..."],
    "reminder_minutes_before": 30
  }
  ```
  - `description`, `emoji`, `location`, `end_at`: `Option<Option<T>>` — 생략=변경없음, null=삭제, 값=변경
  - start_at 변경 시: vote_deadline 동기화 (P30)
  - title trim 후 빈 문자열 → 400
- 응답 200: `{ "data": { "success": true } }`
- 에러: 400 (유효성), 403 (권한 없음), 404, 409 (시작됨 또는 LA 실행 중)

### DELETE /api/v1/schedules/{id}

- 설명: 일정 삭제 (Hard Delete)
- 인증: 필수
  - 그룹일정: 약속 호스트 OR 그룹 호스트 (P11), 시작 전만 (P13)
  - 개인일정: 소유자만
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403, 404, 409 (이미 시작됨)

### POST /api/v1/schedules/{id}/respond

- 설명: 그룹일정 투표 응답
- 인증: 필수 (같은 그룹 멤버, P15)
- 요청:
  ```json
  { "status": "accepted | declined | pending" }
  ```
  - `accepted`: schedule_votes에 INSERT/UPDATE
  - `declined`: schedule_votes에 INSERT/UPDATE
  - `pending`: schedule_votes에서 DELETE (P28)
  - 동일 상태 → no-op (P27)
  - 트랜잭션 내 is_confirmed 재계산 (P29)
- 응답 200:
  ```json
  {
    "data": {
      "schedule_id": "uuid",
      "status": "accepted",
      "is_confirmed": true,
      "confirmed_schedule": {
        "id": "uuid",
        "title": "영화 관람",
        "emoji": "🎬",
        "start_at": "ISO8601",
        "end_at": "ISO8601",
        "location": "CGV 강남",
        "group_id": "uuid"
      }
    }
  }
  ```
  - `confirmed_schedule`: is_confirmed && status==accepted 일 때만 포함 (캘린더 동기화용)
  - 활성 Vote Live Activity가 있으면 현재 상태로 APNs update/end broadcast를 함께 전송
- 에러: 400 (잘못된 status), 403 (멤버 아님), 404 (일정 없음)

### POST /api/v1/schedules/{id}/vote-live-activity/start

- 설명: 호스트가 투표 Live Activity를 시작. APNs channel 생성 후 그룹 멤버 디바이스로 Push to Start 전송
- 인증: 필수 (호스트만)
- 요청 바디: 없음
- 응답 200:
  ```json
  {
    "data": {
      "success": true,
      "success_count": 3,
      "failure_count": 0,
      "channel_id": "apple-vote-channel-id"
    }
  }
  ```
- 비고:
  - 호스트 투표는 accepted로 강제 동기화
  - deadline = `min(start_at - tracking_start_minutes_before, now + 8h)`
- 에러: 403 (호스트 아님), 409 (이미 진행 중), 412 (시간 경과/토큰 없음), 404

### POST /api/v1/schedules/{id}/vote-live-activity/finalize

- 설명: 호스트가 투표 Live Activity를 종료. 현재 vote 상태를 기반으로 end broadcast 전송
- 인증: 필수 (호스트만)
- 요청 바디: 없음
- 응답 200:
  ```json
  {
    "data": {
      "success": true,
      "content_state": {
        "accepted_members": [{ "id": "uid1", "name": "호스트" }],
        "declined_members": [],
        "pending_count": 2,
        "is_finalized": true
      }
    }
  }
  ```
- 비고:
  - business vote를 닫는 기능이 아니라 Live Activity 종료용 상태 동기화 API
- 에러: 403, 404

### POST /api/v1/schedules/{id}/live-activity/start

- 설명: 호스트가 즉시 Live Activity를 시작. APNs channel 생성 후 accepted 참가자 디바이스로 Push to Start 전송
- 인증: 필수 (호스트만)
- 요청 바디: 없음
- 응답 200:
  ```json
  {
    "data": {
      "success": true,
      "success_count": 2,
      "failure_count": 0,
      "channel_id": "apple-channel-id"
    }
  }
  ```
- 에러: 403 (호스트 아님), 412 (APNs 미구성/Push to Start 토큰 없음/미확정 일정), 404

### POST /api/v1/schedules/{id}/live-activity/eta

- 설명: accepted 참가자가 ETA를 갱신하고 APNs broadcast update 전송
- 인증: 필수 (accepted 참가자만)
- 요청:
  ```json
  {
    "channel_id": "apple-channel-id",
    "participants": [
      { "id": "uid1", "name": "호스트", "estimated_arrival_minutes": 5 },
      { "id": "uid2", "name": "멤버", "estimated_arrival_minutes": null }
    ],
    "tracking_duration_minutes": 30
  }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "success": true,
      "success_count": 1,
      "failure_count": 0
    }
  }
  ```
- 비고:
  - 첫 도착/모두 도착 시 alert payload 포함
  - 모두 도착이면 환경별 지연 종료 job 예약
- 에러: 403 (accepted 참가자 아님), 409 (channel mismatch), 404

### GET /api/v1/groups/{group_id}/schedules

- 설명: 그룹의 일정 목록 조회
- 인증: 필수 (그룹 멤버)
- 쿼리 파라미터:
  - `status`: `active` (기본값, startAt >= today) | `past` (startAt < now)
  - `limit`: 최대 개수 (기본 20)
  - `cursor`: 페이지네이션 커서 (past용, startAt ISO8601)
- 응답 200:
  ```json
  {
    "data": [ScheduleResponse, ...],
    "cursor": "ISO8601 | null"
  }
  ```
  - active: startAt 오름차순
  - past: startAt 내림차순
- 에러: 403, 404

### GET /api/v1/schedules/home

- 설명: 홈화면 일정 (내 그룹들의 미래 일정, startAt 오름차순)
- 인증: 필수
- 쿼리 파라미터:
  - `limit`: 최대 개수 (기본 20)
- 응답 200:
  ```json
  { "data": [ScheduleResponse, ...] }
  ```
  - startAt >= now, 그룹일정만 (내가 속한 모든 그룹)
  - 클라이언트가 today/upcoming 분리

### GET /api/v1/schedules/calendar

- 설명: 캘린더 날짜 범위 조회 (그룹 + 개인 + 반복)
- 인증: 필수
- 쿼리 파라미터:
  - `start`: 시작 날짜 ISO8601 (필수)
  - `end`: 종료 날짜 ISO8601 (필수)
  - `accepted_only`: true이면 내가 accepted한 그룹일정만 (충돌 감지용)
  - `timezone`: IANA timezone (반복일정 확장용, 기본 UTC)
- 응답 200:
  ```json
  {
    "data": {
      "schedules": [ScheduleResponse, ...],
      "recurring_instances": [
        {
          "recurring_schedule_id": "uuid",
          "title": "헬스장",
          "emoji": "🏋️",
          "date": "2026-04-07",
          "start_time": { "hour": 19, "minute": 0 },
          "end_time": { "hour": 20, "minute": 0 },
          "location": { ... }
        }
      ]
    }
  }
  ```
  - 반복일정: 서버에서 규칙 확장하여 인스턴스 배열로 반환
- 에러: 400 (범위 31일 초과)

### GET /api/v1/schedules/calendar-sync

- 설명: 캘린더 동기화용 경량 조회 (확정 + accepted + 미래)
- 인증: 필수
- 응답 200:
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "title": "영화 관람",
        "emoji": "🎬",
        "start_at": "ISO8601",
        "end_at": "ISO8601",
        "location": "CGV 강남",
        "group_id": "uuid"
      }
    ]
  }
  ```
  - 최대 50개 (P44)
  - 최소 필드만 반환 (배경 동기화 대역폭 절감)

### POST /api/v1/schedules/check-conflicts

- 설명: 일정 충돌 감지 (Pro 구독 필요)
- 인증: 필수 (Pro)
- 요청:
  ```json
  {
    "start_at": "ISO8601",
    "end_at": "ISO8601 (optional)",
    "min_gap_minutes": 0,
    "exclude_ids": ["uuid1"],
    "timezone": "Asia/Seoul"
  }
  ```
- 응답 200:
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "source": "schedule | personalEvent",
        "severity": "confirmed | pending",
        "title": "기존 일정",
        "emoji": "📅",
        "start_at": "ISO8601",
        "end_at": "ISO8601",
        "overlap_minutes": 30,
        "gap_minutes": 0
      }
    ]
  }
  ```
  - `source = schedule`: 그룹 일정, `source = personalEvent`: 개인/반복 일정
  - `severity = pending`: 미확정 그룹 일정, `severity = confirmed`: 확정 그룹 일정 또는 개인/반복 일정
  - overlap > 0: 겹침, gap = 0: 겹침, gap > 0 && gap < minGap: 간격 부족
  - 정렬: overlap 내림차순 → gap 오름차순
- 에러: 400, 403 (Pro 아님)

### POST /api/v1/schedules/extract

- 설명: LLM 일정 추출 (Gemini)
- 인증: 필수
- 요청:
  ```json
  {
    "text": "SMS 원문 (optional)",
    "image_base64": "base64 (optional)",
    "timezone": "Asia/Seoul"
  }
  ```
  - `text` 또는 `image_base64` 중 하나 이상 필수
  - text 최대 2000자, image 최대 4MB
- 응답 200:
  ```json
  {
    "data": {
      "title": "GS25 근무",
      "emoji": "💼",
      "start_date": "ISO8601",
      "end_date": "ISO8601",
      "location": "장소명",
      "address": "상세 주소",
      "description": "plain text",
      "description_blocks": [...]
    }
  }
  ```
- 에러: 400 (입력 누락/초과), 500 (추출 실패)

## Weather (인증 필요)

### POST /api/v1/transportation

- 설명: 두 좌표 간 교통 정보 조회
- 인증: 필수
- 요청:
  ```json
  {
    "from_lat": 37.5665,
    "from_lng": 126.9780,
    "to_lat": 37.4979,
    "to_lng": 127.0276
  }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "transit_routes": [
        {
          "total_time": 45,
          "payment": 1500,
          "bus_transit_count": 1,
          "subway_transit_count": 0,
          "path_type": 2,
          "sub_paths": [
            {
              "traffic_type": 2,
              "section_time": 35,
              "distance": 12000,
              "start_name": "서울역",
              "end_name": "강남역",
              "station_count": 12,
              "lanes": [
                {
                  "name": "146",
                  "bus_no": "146",
                  "type": 11,
                  "bus_color": "#5BB025"
                }
              ],
              "pass_stop_coords": [[126.97, 37.55], [127.02, 37.49]]
            }
          ]
        }
      ],
      "driving": {
        "distance": 18500,
        "duration": 45,
        "toll": 900,
        "route_points": [[126.97, 37.55], [127.02, 37.49]]
      },
      "walking_minutes": 22,
      "walking_distance_km": 1.4
    }
  }
  ```
- 동작:
  - 직선거리 1km 미만은 외부 API 호출 없이 도보 결과만 반환
  - `ODSAY_API_KEY`, `KAKAO_REST_API_KEY`가 없으면 해당 transport만 비워서 반환
- 에러: 400 (좌표 누락/NaN)

### POST /api/v1/weather

- 설명: 특정 위치/시각 기준 날씨 조회
- 인증: 필수
- 요청:
  ```json
  {
    "latitude": 37.5665,
    "longitude": 126.9780,
    "target_date": "2026-04-09T09:00:00Z"
  }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "forecasts": [
        {
          "date_time": "ISO8601",
          "temperature": 18.2,
          "feels_like_temperature": 17.6,
          "condition": "clear",
          "precipitation_probability": 10,
          "humidity": 55,
          "wind_speed": 2.1,
          "precipitation_amount": ""
        }
      ],
      "daily_forecasts": [
        {
          "date": "2026-04-12",
          "min_temperature": 8,
          "max_temperature": 16,
          "am_condition": "cloudy",
          "pm_condition": "rain",
          "am_precipitation_probability": 30,
          "pm_precipitation_probability": 70
        }
      ]
    }
  }
  ```
  - `daily_forecasts`: 5일 초과 targetDate일 때만 포함될 수 있음
  - targetDate가 현재보다 3시간 이상 과거이거나 10일 초과 미래면 빈 배열 반환
- 에러: 412 (`KMA_API_KEY` 미설정)

## Recurring Schedules (인증 필요)

### POST /api/v1/recurring-schedules

- 설명: 반복일정 생성
- 인증: 필수 (본인 소유)
- 요청:
  ```json
  {
    "title": "헬스장",
    "emoji": "🏋️",
    "description": null,
    "start_time": { "hour": 19, "minute": 0 },
    "end_time": { "hour": 20, "minute": 0 },
    "location": { "name": "강남 피트니스", "address": "..." },
    "reminder_minutes_before": 30,
    "frequency": "weekly",
    "days_of_week": [2, 4, 6],
    "day_of_month": null,
    "series_start_date": "2026-04-01",
    "series_end_date": null
  }
  ```
  - frequency별 필수 필드: weekly → days_of_week, monthly → day_of_month
  - daily → days_of_week/day_of_month 모두 null
- 응답 201:
  ```json
  { "data": { "id": "uuid", "created_at": "ISO8601" } }
  ```
- 에러: 400 (유효성)

### GET /api/v1/recurring-schedules

- 설명: 내 반복일정 목록
- 인증: 필수 (본인 소유만)
- 응답 200:
  ```json
  { "data": [RecurringScheduleResponse, ...] }
  ```

### PATCH /api/v1/recurring-schedules/{id}

- 설명: 반복일정 수정
- 인증: 필수 (소유자만)
- 요청: 수정할 필드만 전송
  ```json
  {
    "title": "수정된 제목",
    "excluded_dates": ["2026-04-07"],
    "overrides": {
      "2026-04-14": { "start_time": { "hour": 20, "minute": 0 } }
    }
  }
  ```
  - `excluded_dates`: 전체 교체 (배열)
  - `overrides`: 전체 교체 (Map)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403 (소유자 아님), 404

### DELETE /api/v1/recurring-schedules/{id}

- 설명: 반복일정 삭제
- 인증: 필수 (소유자만)
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403, 404

## Notifications (인증 필요)

### PUT /api/v1/devices

- 설명: 현재 디바이스 메타데이터 upsert. 토큰은 저장하지 않음
- 인증: 필수
- 요청:
  ```json
  {
    "device_id": "device-uuid",
    "platform": "ios"
  }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "device_id": "device-uuid",
      "platform": "ios",
      "last_active_at": "ISO8601",
      "created_at": "ISO8601"
    }
  }
  ```

### DELETE /api/v1/devices/{device_id}

- 설명: 현재 디바이스 등록 삭제. 일반 알림 endpoint와 Live Activity endpoint도 cascade 삭제
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`
- 에러: 404

### DELETE /api/v1/devices

- 설명: 내 모든 디바이스 등록 삭제
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`

### PUT /api/v1/devices/{device_id}/notification-endpoints/{provider}

- 설명: 일반 앱 알림 endpoint 등록/갱신
- 인증: 필수
- 경로 파라미터:
  - `provider`: 현재 `fcm`만 지원
- 요청:
  ```json
  { "token": "fcm-registration-token" }
  ```
- 응답 200:
  ```json
  {
    "data": {
      "device_id": "device-uuid",
      "provider": "fcm",
      "token": "fcm-registration-token",
      "updated_at": "ISO8601"
    }
  }
  ```
- 에러: 400 (빈 토큰), 404 (디바이스 없음)

### DELETE /api/v1/devices/{device_id}/notification-endpoints/{provider}

- 설명: 일반 앱 알림 endpoint 삭제
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`
- 에러: 404

### PUT /api/v1/devices/{device_id}/live-activity-endpoint

- 설명: Live Activity용 APNs endpoint 등록/갱신
- 인증: 필수
- 요청:
  ```json
  {
    "push_to_start_token": "apns-push-to-start-token",
    "live_activity_push_token": null
  }
  ```
  - 둘 중 하나는 반드시 필요
  - 필드 생략 시 기존 값을 유지
- 응답 200:
  ```json
  {
    "data": {
      "device_id": "device-uuid",
      "push_to_start_token": "apns-push-to-start-token",
      "live_activity_push_token": null,
      "updated_at": "ISO8601"
    }
  }
  ```
- 에러: 400 (둘 다 비어 있음), 404 (디바이스 없음)

### DELETE /api/v1/devices/{device_id}/live-activity-endpoint

- 설명: Live Activity endpoint 삭제
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`
- 에러: 404

### POST /api/v1/live-activity/widget/eta

- 설명: Widget Extension 전용 ETA broadcast endpoint
- 인증:
  - `X-User-Id` 헤더 필수
  - `X-Auth-Token` 헤더는 선택. 있으면 Firebase ID Token 또는 widget token 검증 후 uid 일치 확인
  - `X-Device-Id` 헤더는 widget token 사용 시 필수. token의 `device_id`와 일치해야 함
- 요청:
  ```json
  {
    "schedule_id": "uuid",
    "channel_id": "apple-channel-id",
    "participants": [
      { "id": "uid1", "name": "호스트", "estimated_arrival_minutes": 0 }
    ],
    "tracking_duration_minutes": 30
  }
  ```
- 응답 200: `POST /api/v1/schedules/{id}/live-activity/eta`와 동일
- 에러: 401 (X-User-Id 누락, token uid mismatch), 403, 404

### POST /api/v1/live-activity/widget/vote

- 설명: Widget Extension 전용 투표 응답 endpoint. schedule vote 저장 후 활성 Vote Live Activity가 있으면 APNs update/end broadcast 전송
- 인증:
  - `X-User-Id` 헤더 필수
  - `X-Auth-Token` 헤더 필수. Firebase ID Token 또는 widget token 허용
  - `X-Device-Id` 헤더는 widget token 사용 시 필수. token의 `device_id`와 일치해야 함
- 요청:
  ```json
  {
    "schedule_id": "uuid",
    "channel_id": "apple-vote-channel-id",
    "response": "accepted"
  }
  ```
  - `response`: `accepted | declined | pending`
  - `channel_id`는 stale intent 검사용으로 전달되지만 서버 상태가 source of truth
- 응답 200:
  ```json
  {
    "data": {
      "success": true,
      "content_state": {
        "accepted_members": [{ "id": "uid1", "name": "호스트" }],
        "declined_members": [{ "id": "uid2", "name": "멤버" }],
        "pending_count": 0,
        "is_finalized": true
      }
    }
  }
  ```
  - 활성 Vote Live Activity가 없으면 `{ "data": { "success": true } }`
- 에러: 400 (잘못된 response), 401 (header/token mismatch), 403, 404

### GET /api/v1/notifications

- 설명: 내 알림 목록 조회
- 인증: 필수
- 쿼리 파라미터:
  - `limit`: 기본 20
  - `before`: ISO8601 커서
- 응답 200: `{ "data": [NotificationResponse, ...] }`

### GET /api/v1/notifications/unread-count

- 설명: 안 읽은 알림 수
- 인증: 필수
- 응답 200:
  ```json
  { "data": { "count": 3 } }
  ```

### PATCH /api/v1/notifications/{id}/read

- 설명: 단일 알림 읽음 처리
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403, 404

### POST /api/v1/notifications/mark-all-read

- 설명: 전체 알림 읽음 처리
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`

### POST /api/v1/notifications/delete-batch

- 설명: 알림 일괄 삭제
- 인증: 필수
- 요청:
  ```json
  { "notification_ids": ["uuid-1", "uuid-2"] }
  ```
- 응답 200: `{ "data": { "success": true } }`
- 에러: 403

### DELETE /api/v1/notifications

- 설명: 전체 알림 삭제
- 인증: 필수
- 응답 200: `{ "data": { "success": true } }`

## Briefing (인증 필요)

### POST /api/v1/briefing/generate

- 설명: AI 브리핑 생성 (Gemini 2.0 Flash + KMA 단기예보 + ODsay 대중교통 + Kakao 자동차)
- 인증: 필수 (Pro 여부는 교통 정보 포함 여부에만 영향)
- 요청:
  ```json
  {
    "timezone": "Asia/Seoul",
    "language": "ko",
    "location": {
      "latitude": 37.123,
      "longitude": 127.456,
      "title": "집 (optional)"
    },
    "force_refresh": false,
    "style": "friendly"
  }
  ```
  - `location`: 선택. 없으면 교통 정보 생략
  - `force_refresh`: true이면 promptKey 일치 여부 무시하고 Gemini 재호출
  - `style` 허용값: `"friendly"` | `"humorous"` | `"concise"` | `"motivational"` | `"calm"`. 생략 시 user_settings 값 사용
- 응답 200:
  ```json
  {
    "data": {
      "summary": "오늘 일정 2건...",
      "detail": "마크다운 전체 브리핑",
      "is_updated": true,
      "style": "friendly",
      "available_transports": ["transit", "car"],
      "notification_hour": 8
    }
  }
  ```
  - `is_updated`: true이면 Gemini 새로 호출, false이면 캐시 반환
  - `available_transports`: user_settings 기반 (Pro만 교통 정보 포함)
  - `notification_hour`: user_settings.briefing_notification_hour (Pro 비활성이면 null)
- 캐시: promptKey(SHA-256 16자) 일치 시 Gemini 스킵, `briefing_cache` 테이블에서 반환
- 에러: 400 (허용값 외 style), 500 (Gemini 호출 실패)

## Widget (인증 필요)

### POST /api/v1/widget/token

- 설명: Widget JWT 발급. `widget_token_version`을 DB에서 조회하고 HS256 JWT를 생성하여 반환
- 인증: 필수 (Firebase Token)
- 요청:
  ```json
  { "device_id": "device-uuid" }
  ```
  - `device_id`: 필수
- 응답 200:
  ```json
  {
    "data": {
      "widget_token": "eyJ...",
      "expires_at": 1780000000
    }
  }
  ```
  - `expires_at`: Unix epoch seconds (now + 30일)
  - JWT payload: `{ sub, scope: "widget:read", device_id, version, exp, iat }`

### POST /api/v1/widget/revoke

- 설명: 현재 유저의 Widget 토큰 전체 무효화. `widget_token_version`을 +1 증가시켜 기존 발급 토큰을 모두 만료
- 인증: 필수 (Firebase Token)
- 요청 바디: 없음
- 응답 200:
  ```json
  { "data": { "success": true } }
  ```

### GET /api/v1/widget/snapshot

- 설명: 위젯 스냅샷 조회. 오늘 일정(최대 6개)과 예정 일정(최대 9개)을 KST 기준으로 반환
- 인증:
  - `Authorization: Bearer <token>` 필수
  - Firebase Token 또는 Widget Token 허용
  - `X-Device-Id` 헤더는 Widget Token 사용 시 필수. token의 `device_id`와 일치해야 함
- 응답 200:
  ```json
  {
    "data": {
      "next": {
        "id": "uuid",
        "schedule_type": "group",
        "title": "영화 관람",
        "emoji": "🎬",
        "start_at": "ISO8601",
        "end_at": "ISO8601",
        "location_name": "CGV 강남",
        "group_name": "친구들",
        "is_confirmed": true
      },
      "today": [...],
      "upcoming": [...]
    }
  }
  ```
  - `next`: today[0] ?? upcoming[0]. 일정 없으면 null
  - `today`: KST 기준 오늘 날짜의 일정 (start_at 오름차순, 최대 6개)
  - `upcoming`: KST 기준 내일 이후 일정 (start_at 오름차순, 최대 9개)
  - 최근 1시간 이내에 종료된 일정은 위젯 연속성 유지를 위해 포함될 수 있음
  - 그룹일정: `is_confirmed = true`인 것만 포함
  - 개인일정: 소유자의 모든 미래 일정 포함
- 에러: 401 (토큰 없음/무효, revoke된 widget token, `X-Device-Id` 불일치)

## Places (인증 불필요)

### GET /api/v1/places/search

- 설명: Kakao 장소 키워드 검색. `KAKAO_REST_API_KEY` 환경변수로 Kakao API 호출
- 인증: 불필요
- 쿼리 파라미터:
  - `q`: 검색 키워드 (필수)
  - `size`: 결과 개수 (선택, 기본 15, 최대 45)
- 응답 200:
  ```json
  {
    "data": [
      {
        "id": "12345678",
        "name": "CGV 강남",
        "latitude": 37.5012,
        "longitude": 127.0261,
        "address": "서울 강남구 ...",
        "road_address": "서울 강남구 강남대로 ...",
        "category": "문화시설",
        "phone": "02-123-4567"
      }
    ]
  }
  ```
  - `address`, `road_address`, `category`, `phone`: nullable
- 에러: 500 (Kakao API 호출 실패)

## Emoji (인증 필요)

### POST /api/v1/emoji/generate

- 설명: 일정 제목으로 Gemini 2.0 Flash를 호출하여 어울리는 이모지 1개 생성. 실패 시 "📅" 반환
- 인증: 필수
- 요청:
  ```json
  { "title": "영화 관람" }
  ```
- 응답 200:
  ```json
  { "data": { "emoji": "🎬" } }
  ```
  - Gemini 호출 실패 또는 이모지 미추출 시 `"📅"` 반환 (에러 없음)
- 에러: 401 (인증 실패)

## Internal (스케줄러 전용)

### POST /api/v1/internal/briefing/dispatch

- 설명: 브리핑 스케줄러 dispatch. `briefing_subscriptions`에서 due 항목을 최대 50개 처리하고 next_dispatch_at을 갱신
- 인증: `X-Scheduler-Secret` 헤더 (SCHEDULER_SECRET 환경변수와 대조). 불일치 시 401
- 요청 바디: 없음
- 응답 200:
  ```json
  {
    "summary": {
      "totalDue": 12,
      "processed": 12,
      "succeeded": 11,
      "failed": 1,
      "skipped": 0,
      "deleted": 0
    }
  }
  ```
  - `totalDue`: 조회된 due 항목 수
  - `processed`: 실제 처리 시도 수
  - `succeeded`: 브리핑 생성 + FCM 발송 성공
  - `failed`: 처리 중 오류 발생 (next_dispatch_at은 갱신)
  - `skipped`: Pro 박탈 등으로 건너뜀
  - `deleted`: briefing_subscriptions row 삭제 (notification_hour NULL 또는 Pro 상실)
- 에러: 401 (X-Scheduler-Secret 불일치)

*마지막 업데이트: 2026-04-08*
