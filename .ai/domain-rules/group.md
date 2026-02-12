# 그룹 (Group) 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 제약 조건 (Constraints)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| G1 | 그룹 이름 최소 길이 | 2자 | ✅ | ✅ |
| G2 | 그룹 이름 최대 길이 | 12자 | ❌ | ✅ |
| G3 | 그룹 설명 최대 길이 | 50자 | ❌ `(설정에서만 적용)` | ✅ |
| G4 | 최대 인원 범위 | 2~10명 | ✅ `MaxMembers enum` | ✅ `maxMembers >= 2` |
| G5 | 최대 인원 하한 | `max(2, 현재 멤버 수)` | ✅ | ✅ |
| G6 | 초대 코드 형식 | 6자리 영숫자 (A-Z0-9) | ✅ | ✅ |
| G7 | groupId 형식 | 비어있지 않음, `/` 문자 금지 | — | ✅ |
| G8 | maxMembers 정수 | `Number.isInteger` | — | ✅ |

---

## 2. 권한 (Permissions)

| ID | 규칙 | 조건 | iOS | Backend |
|----|------|------|:---:|:-------:|
| G9 | 호스트 = 그룹 생성자 | `createdBy == userId` | ✅ | ✅ |
| G10 | 그룹 수정 = 호스트만 | `createdBy == userId` | ✅ | ✅ |
| G11 | 그룹 삭제 = 호스트만 | `createdBy == userId` | ✅ | ✅ |
| G12 | 호스트 양도 조건 | 호스트 && 다른 멤버 존재 | ✅ | ✅ |
| G13 | 호스트 양도: 자기 자신 불가 | `currentUserId !== newHostId` | — | ✅ |
| G14 | 호스트 양도: 대상은 그룹 멤버 | `memberIds.includes(newHostId)` | — | ✅ |
| G15 | 호스트 탈퇴 불가 | 양도 또는 삭제 후 가능 | ✅ | ✅ |
| G16 | 가입 조건 | 미가입 && 정원 미달 | ✅ | ✅ |
| G17 | 그룹 멤버만 조회 가능 | Firestore rules `memberIds` 체크 | — | ✅ |

---

## 3. 동작 규칙 (Behaviors)

| ID | 규칙 | 상세 | iOS | Backend |
|----|------|------|:---:|:-------:|
| G18 | 기본 역할: 생성자 | admin | ✅ | ✅ |
| G19 | 기본 역할: 가입자 | member | ✅ | ✅ |
| G20 | 가입 시 기본 알림 | 모든 알림 ON | ✅ | ✅ |
| G21 | 가입 시 캘린더 동기화 기본값 | ON | ✅ | — |
| G22 | 초대 코드 생성 재시도 | 최대 5회 | — | ✅ |
| G23 | 초대 코드 자동 대문자 변환 | `.toUpperCase()` | — | ✅ |
| G24 | 초대 코드 6자 도달 시 | 자동 검증 시작 | ✅ | — |
| G25 | 삭제 cascade | 약속 전체 삭제 → 멤버 정리 → Storage 이미지 삭제 | — | ✅ |
| G26 | 이미지 변경 시 | 전체 멤버의 groups Map에 imageUrl 동기화 | — | ✅ |
| G27 | 그룹 목록 정렬 | joinedAt 내림차순 (최근 가입 순) | ✅ | — |
| G28 | 그룹 정렬 옵션 | joinedRecent(기본), joinedOldest, nameAsc, nameDesc, custom | ✅ | — |

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| G29 | 초대 링크 형식 | `https://promiso.app/invite/{code}` | ✅ | — |
| G30 | 딥링크 형식 | `promiso://join/{code}` | ✅ | — |
| G31 | 미리보기 멤버 최대 | 10명 | — | ✅ |
| G32 | 미리보기 인증 불필요 | 비로그인 사용자도 미리보기 가능 | — | ✅ |

---

## 5. 코드 매핑 (Code Mapping)

> 마지막 매핑: 2026-02-12 | iOS 구현 없는 규칙(Backend only)은 `—` 표시

### 제약 조건

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| G1 | `CreateGroupFeature.swift` `isValid` (count >= 2) | `CreateGroupReducerTests` 2개 | ✅ |
| G2 | ❌ iOS 미구현 (Backend만) | — | — |
| G3 | `GroupSettingsFeature.swift` `editGroupDescriptionChanged` `prefix(50)` | — | ❌ |
| G4 | `CreateGroupFeature.swift` `MaxMembers` enum (2~10) | — | ❌ |
| G5 | `GroupSettingsFeature.swift` `minMaxMembers` = max(2, memberCount) | — | ❌ |
| G6 | `JoinGroupFeature.swift` `isValidCode` (count==6, 영숫자) | — | ❌ |
| G7~G8 | — | — | — |

### 권한

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| G9 | `GroupSettingsFeature.swift` `isHost` (createdBy == currentUserId) | — | ❌ |
| G10 | `GroupSettingsFeature.swift` `editGroupSaveTapped` | — | ❌ |
| G11 | `GroupSettingsFeature.swift` `confirmDelete` | — | ❌ |
| G12 | `GroupSettingsFeature.swift` `canTransferHost` | — | ❌ |
| G13~G14 | — | — | — |
| G15 | `GroupSettingsFeature.swift` `confirmLeave` | — | ❌ |
| G16 | `JoinGroupFeature.swift` `joinGroupTapped` | `JoinGroupPermissionTests` | ✅ |
| G17 | — | — | — |

### 동작 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| G18~G19 | — (Backend only) | — | — |
| G20 | `CreateGroupFeature.swift` / `JoinGroupFeature.swift` `notificationEnabled = true` | `CreateGroupPermissionTests` `JoinGroupPermissionTests` | ✅ |
| G21 | `CreateGroupFeature.swift` / `JoinGroupFeature.swift` `calendarSyncEnabled = true` | `CreateGroupPermissionTests` `JoinGroupPermissionTests` | ✅ |
| G22~G23 | — | — | — |
| G24 | `JoinGroupFeature.swift` `isValidCode` | — | ❌ |
| G25~G26 | — | — | — |
| G27 | `GroupMainFeature.swift` `sortedGroupsForSelection` (joinedAt 내림차순) | — | ❌ |
| G28 | `GroupSortOption.swift` enum + `GroupSortSettingsFeature.swift` | — | ❌ |

### 표시 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| G29 | `GroupInviteShareMessage.swift` `inviteLink` | — | ❌ |
| G30 | `GroupInviteShareMessage.swift` `deeplinkURL` | — | ❌ |
| G31~G32 | — | — | — |

### 핵심 파일

| 구현 파일 | 경로 | 관련 규칙 |
|----------|------|----------|
| CreateGroupFeature.swift | `Features/GroupFeature/Sources/CreateGroup/Main/` | G1,G4,G20,G21 |
| JoinGroupFeature.swift | `Features/GroupFeature/Sources/JoinGroup/Main/` | G6,G16,G20,G21,G24 |
| GroupSettingsFeature.swift | `Features/GroupFeature/Sources/GroupSettings/` | G3,G5,G9-G12,G15 |
| GroupMainFeature.swift | `Features/GroupFeature/Sources/GroupMain/` | G27 |
| GroupSortOption.swift | `Shared/Sources/Models/` | G28 |
| GroupInviteShareMessage.swift | `Shared/Sources/Utils/` | G29,G30 |

| 테스트 파일 | 경로 | 관련 규칙 |
|------------|------|----------|
| CreateGroupReducerTests.swift | `Features/GroupFeature/Tests/Sources/` | G1 |
| CreateGroupPermissionTests.swift | `Features/GroupFeature/Tests/Sources/` | G20,G21 |
| JoinGroupPermissionTests.swift | `Features/GroupFeature/Tests/Sources/` | G16,G20,G21 |
