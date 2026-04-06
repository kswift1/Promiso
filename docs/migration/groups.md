# Groups 도메인 마이그레이션

## Firebase Functions → REST 매핑

| Firebase Function | Rust 엔드포인트 | 상태 |
|---|---|---|
| `createGroup` | `POST /api/v1/groups` | ✅ 구현 |
| `previewGroup` | `GET /api/v1/groups/preview?code=XXX` | ✅ 구현 |
| `joinGroup` | `POST /api/v1/groups/join` | ✅ 구현 |
| `leaveGroup` | `POST /api/v1/groups/{id}/leave` | ✅ 구현 |
| `updateGroup` | `PATCH /api/v1/groups/{id}` | ✅ 구현 |
| `deleteGroup` | `DELETE /api/v1/groups/{id}` | ✅ 구현 |
| `transferGroupHost` | `POST /api/v1/groups/{id}/transfer-host` | ✅ 구현 |
| `expelMember` | `POST /api/v1/groups/{id}/expel` | ✅ 구현 |
| (신규) 그룹 상세 조회 | `GET /api/v1/groups/{id}` | ✅ 구현 |
| (신규) 내 그룹 목록 | `GET /api/v1/groups/me` | ✅ 구현 |
| (신규) 멤버 목록 조회 | `GET /api/v1/groups/{id}/members` | ✅ 구현 |
| (신규) 읽음 처리 | `POST /api/v1/groups/{id}/mark-read` | ✅ 구현 |
| (신규) 알림 설정 수정 | `PATCH /api/v1/groups/{id}/notification-settings` | ✅ 구현 |
| (신규) 그룹 색상 수정 | `PATCH /api/v1/groups/{id}/color` | ✅ 구현 |

> Firebase에서 별도 Callable Function으로 없었던 조회/설정 API들은 iOS가 Firestore 직접 읽기 또는 Firestore 트리거로 처리하던 것을 REST API로 명시화.

## Firestore 트리거 → 흡수 방식

| Firestore 트리거 | Firebase 처리 방식 | Rust 처리 방식 | 상태 |
|---|---|---|---|
| `onGroupImageUpdated` | 그룹 이미지 변경 시 전체 멤버의 `users/{uid}.groups` Map에 `imageUrl` 동기화 | 비정규화 제거 — `group_members` JOIN으로 항상 최신 이미지 조회 | ✅ 불필요 |
| 그룹 삭제 시 Storage 이미지 삭제 | Functions에서 Storage 파일 제거 | ⚠️ Storage 마이그레이션 시 처리 (현재 Firebase Storage 유지) | ❌ 보류 |
| 그룹 삭제 시 약속 cascade | Functions에서 promises 컬렉션 삭제 | DB FK CASCADE로 처리 예정 (schedules 도메인 마이그레이션 후) | ❌ 보류 |

## Firestore 스키마 → PostgreSQL 매핑

| Firestore | PostgreSQL | 변경 사항 |
|---|---|---|
| `groups/{groupId}` 문서 | `groups` 테이블 | 문서 ID를 UUID로 재생성 |
| `groups/{id}.name` | `groups.name` | 동일 (이름 변경 불가 규칙 유지) |
| `groups/{id}.description` | `groups.description` | 동일 |
| `groups/{id}.imageUrl` | `groups.image_url` | camelCase → snake_case |
| `groups/{id}.maxMembers` | `groups.max_members` | camelCase → snake_case |
| `groups/{id}.inviteCode` | `groups.invite_code` | camelCase → snake_case |
| `groups/{id}.createdBy` | `group_members` WHERE `role = 'admin'` | 비정규화 제거 — 별도 컬럼 없이 role로 표현 |
| `groups/{id}.memberIds` 배열 | `group_members` 테이블 | 비정규화 배열 → 정규화된 조인 테이블 |
| `users/{uid}.groups` Map | `group_members` 테이블 | 양방향 비정규화 → 단일 테이블로 통합 |
| `users/{uid}.groups.{groupId}.notifications` | `group_members` 알림 컬럼들 | JSONB 없이 명시적 컬럼 (schedule_invitation, schedule_reminder, ...) |
| `users/{uid}.groups.{groupId}.groupColor` | `group_members.group_color` | 개인별 색상 유지 |
| `users/{uid}.groups.{groupId}.joinedAt` | `group_members.joined_at` | 동일 |
| `groups/{id}.lastActivityAt` | `groups.last_activity_at` | 배지 계산용 유지 |

## iOS 클라이언트 전환 상태

| GroupClient 메서드 | 현재 (Firebase) | 전환 후 (Rust REST) | 상태 |
|---|---|---|---|
| `fetchGroups` | Firestore 직접 읽기 | `GET /api/v1/groups/me` | ❌ 미전환 |
| `fetchGroupSummaries` | Firestore 직접 읽기 | `GET /api/v1/groups/me` | ❌ 미전환 |
| `fetchGroupsByIds` | Firestore 직접 읽기 | `GET /api/v1/groups/{id}` 반복 또는 batch | ❌ 미전환 |
| `fetchGroup` | Firestore 직접 읽기 | `GET /api/v1/groups/{id}` | ❌ 미전환 |
| `fetchGroupMembers` | users 컬렉션 batch 조회 | `GET /api/v1/groups/{id}/members` | ❌ 미전환 |
| `createGroup` | `createGroup` Callable | `POST /api/v1/groups` | ❌ 미전환 |
| `previewGroup` | `previewGroup` Callable | `GET /api/v1/groups/preview?code=` | ❌ 미전환 |
| `joinGroup` | `joinGroup` Callable | `POST /api/v1/groups/join` | ❌ 미전환 |
| `leaveGroup` | `leaveGroup` Callable | `POST /api/v1/groups/{id}/leave` | ❌ 미전환 |
| `deleteGroup` | `deleteGroup` Callable | `DELETE /api/v1/groups/{id}` | ❌ 미전환 |
| `updateGroup` | `updateGroup` Callable | `PATCH /api/v1/groups/{id}` | ❌ 미전환 |
| `updateGroupNotificationSettings` | Firestore 직접 쓰기 | `PATCH /api/v1/groups/{id}/notification-settings` | ❌ 미전환 |
| `updateGroupColor` | Firestore 직접 쓰기 | `PATCH /api/v1/groups/{id}/color` | ❌ 미전환 |
| `clearGroupBadge` | Firestore 직접 쓰기 | `POST /api/v1/groups/{id}/mark-read` | ❌ 미전환 |
| `transferHost` | `transferGroupHost` Callable | `POST /api/v1/groups/{id}/transfer-host` | ❌ 미전환 |
| `expelMember` | `expelMember` Callable | `POST /api/v1/groups/{id}/expel` | ❌ 미전환 |

## 보류 항목

- **Storage 이미지**: Firebase Storage 유지. Storage 마이그레이션 시 image_url 경로 전환
- **그룹 삭제 cascade (약속)**: schedules 도메인 마이그레이션 후 DB FK CASCADE 추가
- **타인 프로필 공통 그룹 체크**: `GET /api/v1/users/{id}` 핸들러에서 `group_members` 테이블 조인으로 구현 가능. groups 마이그레이션 완료 후 활성화

## 검증 현황

- Rust 백엔드 테스트: `infra/rust-backend/tests/groups_test.rs` (57개 테스트)
- iOS 클라이언트: 미전환 (Firebase 직접 호출 유지)
