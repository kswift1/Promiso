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
- 에러: 400 (잘못된 status), 403 (멤버 아님), 404 (일정 없음)

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
        "type": "group | personal | recurring",
        "title": "기존 일정",
        "emoji": "📅",
        "start_at": "ISO8601",
        "end_at": "ISO8601",
        "overlap_minutes": 30,
        "gap_minutes": -30
      }
    ]
  }
  ```
  - overlap > 0: 겹침, gap < 0: 겹침, gap >= 0 && gap < minGap: 간격 부족
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

*마지막 업데이트: 2026-04-06*
