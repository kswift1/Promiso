# 접근 제어 + Firestore 보안 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. Firestore Security Rules

| ID | 컬렉션 | 읽기 | 쓰기 | 조건 |
|----|--------|------|------|------|
| S1 | `users/{userId}` | 본인만 | 본인만 | `auth.uid == userId` |
| S2 | `users/{userId}/auth/**` | 본인만 | 본인만 | `auth.uid == userId` |
| S3 | `users/{userId}/settings/**` | 본인만 | 본인만 | `auth.uid == userId` |
| S4 | `groups/{groupId}` | 멤버만 | 조건부 | 읽기: `uid in memberIds` |
| S5 | `groups` 생성 | — | 인증 사용자 | 자신을 memberIds에 포함 필수 |
| S6 | `groups` 수정/삭제 | — | admin만 | `users/{uid}.groups[groupId].role == "admin"` |
| S7 | `promises/{promiseId}` | 그룹 멤버만 | 조건부 | `uid in groups/{groupId}.memberIds` |
| S8 | `promises` votes 수정 | — | 그룹 멤버 | `votes` + `updatedAt` 필드만 변경 가능 |
| S9 | `notifications/{userId}/**` | 본인만 | 제한적 | 생성: 불가(Functions만), 수정: `isRead`/`readAt` 필드만 |
| S10 | 기타 모든 경로 | 차단 | 차단 | `allow read, write: if false` |

---

## 2. 보안 조치 (Security Measures)

| ID | 규칙 | 목적 | 위치 |
|----|------|------|------|
| S11 | groupId에 `.` 문자 금지 | Field Path Injection 방지 | Backend: `transferGroupHost` |
| S12 | groupId에 `/` 문자 금지 | Firestore 문서 ID 제약 | Backend: `validateCreateGroupRequest` |
| S13 | 프로필 이미지 경로 prefix 검증 | 임의 파일 삭제 방지 | Backend: `deleteUser` (`profile_images/{userId}/` 확인) |
| S14 | 썸네일 경로 보안 검증 | 썸네일 삭제 시에도 경로 확인 | Backend: `deleteUser` |
| S15 | 호스트 양도 트랜잭션 | race condition 방지 | Backend: `transferGroupHost` (`db.runTransaction`) |
| S16 | Widget CORS 차단 | OPTIONS 요청 시 403 | Backend: Widget HTTP 엔드포인트 |

---

## 3. 데이터 접근 권한 요약

```
본인 데이터:         본인만 읽기/쓰기
그룹 데이터:         멤버만 읽기, admin만 수정/삭제
약속 데이터:         그룹 멤버만 읽기, 호스트/그룹호스트만 수정/삭제
타인 정보:           같은 그룹 멤버만 조회 가능
알림 데이터:         본인만 읽기, Functions만 생성, isRead만 수정 가능
LiveActivity 시작:   호스트만
배지 해제:           본인만
```
