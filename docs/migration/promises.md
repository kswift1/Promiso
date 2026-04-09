# Promises 도메인 마이그레이션

## Firebase / Firestore → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `createPromise` | `POST /api/v1/schedules` | ✅ 완료 |
| `respondPromise` | `POST /api/v1/schedules/{id}/respond` | ✅ 완료 |
| `updatePromise` | `PATCH /api/v1/schedules/{id}` | ✅ 완료 |
| `deletePromise` | `DELETE /api/v1/schedules/{id}` | ✅ 완료 |
| 그룹 활성 일정 조회 | `GET /api/v1/groups/{group_id}/schedules?status=active` | ✅ 완료 |
| 그룹 과거 일정 조회 | `GET /api/v1/groups/{group_id}/schedules?status=past` | ✅ 완료 |
| 홈 일정 조회 | `GET /api/v1/schedules/home` | ✅ 완료 |
| 캘린더 조회 | `GET /api/v1/schedules/calendar` | ✅ 완료 |
| 캘린더 동기화용 확정 일정 조회 | `GET /api/v1/schedules/calendar-sync` | ✅ 완료 |
| 개인 일정 생성/수정/삭제/조회 | `POST/PATCH/DELETE/GET /api/v1/schedules` | ✅ 완료 |
| 반복 개인 일정 CRUD | `POST/PATCH/DELETE/GET /api/v1/recurring-schedules` | ✅ 완료 |
| 일정 이미지 direct upload | `POST /api/v1/media/upload-urls` | ✅ 완료 |
| 일정 이미지 cleanup | `POST /api/v1/media/delete-urls` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `ScheduleClient` | Rust schedules API | ✅ release도 Rust 고정 |
| `PersonalEventClient` | Rust schedules API | ✅ release도 Rust 고정 |
| `RecurringPersonalEventClient` | Rust recurring API | ✅ release도 Rust 고정 |
| `ImageUploadClient` | Rust media signed URL + GCS direct upload/delete | ✅ 완료 |

메모:

- `Projects/Clients/Sources/Clients/FeatureFlagsClient.swift`에서 `promises` 도메인은 release에서도 Rust를 강제한다.
- `ScheduleClient` / `PersonalEventClient`의 subscribe API는 Firebase listener 대신 Rust one-shot stream을 사용한다.

## 남은 항목

- 레거시 Firebase 구현 파일 정리:
  - `ScheduleRemoteDataSource`
  - `PersonalEventRemoteDataSource`
  - `RecurringPersonalEventRemoteDataSource`
- 필요 시 Rust polling / SSE 기반 실시간 갱신 전략 재설계

## 검증 현황

- Rust 백엔드:
  - `infra/rust-backend/tests/groups_test.rs`
  - `infra/rust-backend/tests/users_test.rs`
  - `infra/rust-backend/tests/media_upload_urls_test.rs`
  - `infra/rust-backend/tests/group_image_upload_url_test.rs`
  - `infra/rust-backend/tests/user_profile_image_upload_url_test.rs`
- iOS:
  - `Clients` scheme unit test는 현재 Xcode에 iOS 26.4 simulator platform이 없어 이 머신에서 실행 불가
