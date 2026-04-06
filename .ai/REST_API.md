# REST API 엔드포인트

> Rust 백엔드 (`infra/rust-backend/`) API 목록

## 공통

- Base URL: Cloud Run 배포 후 결정
- 인증: `Authorization: Bearer <firebase_id_token>`
- 응답 포맷: `{"data": T}` (성공) / `{"error": {"code": "...", "message": "..."}}` (실패)
- snake_case (JSON)

## 인증 불필요

| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 서버 + DB 상태 확인 |

## Users (인증 필요)

| Method | Path | 설명 | 비고 |
|--------|------|------|------|
| POST | `/api/v1/users` | 유저 생성 | body: {name?, nickname, provider} |
| GET | `/api/v1/users/me` | 본인 프로필 (private) | email, provider 포함 |
| PATCH | `/api/v1/users/me` | 닉네임 수정 | body: {nickname?} |
| POST | `/api/v1/users/me/profile-image` | 프로필 이미지 URL 저장 | body: {image_path} |
| GET | `/api/v1/users/nickname-check?q=` | 닉네임 중복 확인 | 본인 닉네임은 available=true |
| POST | `/api/v1/users/batch` | 여러 유저 조회 (public) | body: {user_ids: [...]} |
| GET | `/api/v1/users/{id}` | 타인 프로필 (public) | 공통 그룹 체크 (groups 마이그레이션 후) |

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

### 인증 필요 (Authorization: Bearer \<firebase_id_token\>)

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

*마지막 업데이트: 2026-04-05*
