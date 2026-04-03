# Users 도메인 마이그레이션

## Firebase → Rust 매핑

| Firebase Function | Rust Endpoint | 상태 |
|-------------------|---------------|------|
| `createUser` | `POST /api/v1/users` | ✅ 완료 |
| `getUser` (본인) | `GET /api/v1/users/me` | ✅ 완료 |
| `getUser` (타인) | `GET /api/v1/users/{id}` | ⚠️ 항상 Forbidden (groups 마이그레이션 후 완성) |
| `updateUser` | `PATCH /api/v1/users/me` | ✅ 완료 |
| `uploadProfileImage` | `POST /api/v1/users/me/profile-image` | ⚠️ 라우트 존재, Storage는 Firebase 유지 |
| `checkNicknameAvailable` | `GET /api/v1/users/nickname-check?q=` | ✅ 완료 |
| (신규) batch 조회 | `POST /api/v1/users/batch` | ✅ 완료 |
| `deleteUser` | 미마이그레이션 | ❌ groups/promises 전환 후 |

## iOS 직접호출 → Rust

| iOS 메서드 | 상태 |
|-----------|------|
| `getUserSettings` | ❌ Firebase 유지 (settings 별도 마이그레이션) |
| `updateUserSettings` | ❌ Firebase 유지 |

## 보류 항목

- **프로필 이미지**: Storage 마이그레이션 시 한번에 처리
- **deleteUser**: groups/promises 전환 후 (10단계 cascade)
- **settings**: groupSortOption, proSettings 별도 마이그레이션
- **타인 조회 공통 그룹 체크**: groups 도메인의 group_members 테이블 필요
- **soft delete**: deleteUser 마이그레이션 시 ADR 결정

## 스키마

`infra/rust-backend/migrations/002_users.sql` 참조

## 로컬 검증 결과 (2026-04-03)

- 유저 생성: ✅
- 닉네임 중복 체크: ✅
- 닉네임 수정: ✅
- 본인 프로필 조회: ✅
- 프로필 이미지: ⚠️ (Storage 마이그레이션 보류)
