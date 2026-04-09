# Users 도메인 마이그레이션

## Firebase → Rust 매핑

| Firebase Function | Rust Endpoint | 상태 |
|-------------------|---------------|------|
| `createUser` | `POST /api/v1/users` | ✅ 완료 |
| `getUser` (본인) | `GET /api/v1/users/me` | ✅ 완료 |
| `getUser` (타인) | `GET /api/v1/users/{id}` | ✅ 완료 (공통 그룹이 있을 때만 조회 허용) |
| `updateUser` | `PATCH /api/v1/users/me` | ✅ 완료 |
| `deleteUser` | `DELETE /api/v1/users/me` | ✅ 완료 (그룹 호스트는 `failed-precondition`, subscription 이력 보존) |
| `uploadProfileImage` | `POST /api/v1/users/me/profile-image/upload-url` + `POST /api/v1/users/me/profile-image` | ✅ 완료 (GCS signed upload + finalize) |
| `checkNicknameAvailable` | `GET /api/v1/users/nickname-check?q=` | ✅ 완료 |
| (신규) batch 조회 | `POST /api/v1/users/batch` | ✅ 완료 |

## iOS 직접호출 → Rust

| iOS 메서드 | 상태 |
|-----------|------|
| `UserProfileClient` 주요 조회/수정 (`create/get/check/update`) | ✅ Feature Flag 연결 완료 |
| `UserProfileClient.create/updateProfileImage` (Rust users 경로) | ✅ GCS direct upload 연결 완료 |
| `UserSettingsClient.fetch/update/initializeProDefaults` | ✅ settings 도메인으로 Rust 이관 완료 |
| `UserProfileClient.getUserSettings` 레거시 헬퍼 | ⚠️ 미사용 레거시 경로로 Firebase fallback 유지 |

## 보류 항목

- **레거시 `UserProfileClient.getUserSettings` 정리**: 현재는 별도 `UserSettingsClient`가 Rust 경로 사용
- **soft delete**: deleteUser 마이그레이션 시 ADR 결정

## 다른 도메인으로 이관된 Firestore 데이터

| Firestore 필드 | 내용 | 처리 시점 |
|---------------|------|----------|
| `users/{uid}.devices` Map | FCM 토큰, pushToStartToken, platform, lastActiveAt | **notifications 도메인**에서 `devices` + `notification_endpoints` + `live_activity_endpoints`로 분리 완료 |
| `users/{uid}.groups` Map | 그룹 목록 (groupName, role, notifications 등) | **groups 도메인**에서 `group_members` 조인 테이블로 이관 완료 |
| `users/{uid}/settings/main` | groupSortOption, proSettings.briefing.* | **settings 도메인**에서 `user_settings` 테이블로 이관 완료 |
| `users/{uid}/personalEvents/*` | 개인 일정 | **schedules/promises 도메인**으로 이관 완료 |
| `users/{uid}/recurringEvents/*` | 반복 일정 규칙 | **schedules/promises 도메인**으로 이관 완료 |
| `users/{uid}/cache/*` | 위젯 캐시 (deprecated) | Direct Query 기반 위젯으로 대체, 제거 대상 |

## 스키마

`infra/rust-backend/migrations/002_users.sql` 참조

## 로컬 검증 결과 (2026-04-09)

- 유저 생성: ✅
- 닉네임 중복 체크: ✅
- 닉네임 수정: ✅
- 본인 프로필 조회: ✅
- 타인 프로필 조회: ✅ (공통 그룹 조건)
- 배치 조회: ✅
- 회원 탈퇴: ✅ (`DELETE /api/v1/users/me`)
- 회원 탈퇴 host 차단: ✅ (`failed-precondition`)
- 프로필 이미지 upload-url 발급: ✅ (`POST /api/v1/users/me/profile-image/upload-url`)
- 프로필 이미지 finalize: ✅ (`POST /api/v1/users/me/profile-image`)
