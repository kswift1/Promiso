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
