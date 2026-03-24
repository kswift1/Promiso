# 사용자 (User) 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 제약 조건 (Constraints)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| U1 | 닉네임 최소 길이 | 2자 | ✅ | ✅ |
| U2 | 닉네임 최대 길이 | 12자 | ✅ `(회원가입)` ⚠️ `(설정: 20자)` | ❌ `(20자)` |
| U3 | 닉네임 공백 불가 | 중간 공백 불가 | ✅ | ❌ |
| U4 | 닉네임 앞뒤 공백 불가 | trim 후 비교 | ✅ | — |
| U5 | 닉네임 중복 불가 | 고유 닉네임 (본인 닉네임은 사용 가능) | — | ✅ |
| U6 | name/email 수정 불가 | provider 정보이므로 변경 불가 | — | ✅ |

---

## 2. 권한 (Permissions)

| ID | 규칙 | 조건 | iOS | Backend |
|----|------|------|:---:|:-------:|
| U7 | 인증 제공자 | Apple, Google | ✅ | ✅ |
| U8 | 타인 정보 조회 | 같은 그룹 멤버만 가능 | — | ✅ |
| U9 | 그룹 호스트면 탈퇴 불가 | 모든 그룹에서 createdBy 체크 | — | ✅ |

---

## 3. 동작 규칙 (Behaviors)

| ID | 규칙 | 상세 | iOS | Backend |
|----|------|------|:---:|:-------:|
| U10 | name 미제공 시 | nickname으로 대체 | — | ✅ |
| U11 | 닉네임 중복 체크 디바운스 | 500ms | ✅ | — |
| U12 | 프로필 이미지 URL 우선순위 | thumbUrl > url (썸네일 우선) | ✅ | — |
| U13 | 이미 존재하는 사용자 생성 거부 | `already-exists` 에러 | — | ✅ |

### 회원 탈퇴 Cascade (10단계)

| 단계 | 동작 | 실패 시 |
|:----:|------|---------|
| 1 | 그룹 호스트 여부 확인 → 호스트면 차단 | 에러 반환 |
| 2 | 호스트인 약속 전체 삭제 (500개 단위 배치) | — |
| 3 | 모든 그룹의 memberIds에서 제거 | — |
| 4 | 모든 약속의 votes(accepted/declined)에서 제거 | — |
| 5 | Storage 프로필 이미지 + 썸네일 삭제 | 실패 무시 |
| 6 | 루트 컬렉션 정리: notifications, liveActivities (userId 쿼리 배치 삭제) | 실패 무시 |
| 7 | 루트 문서 정리: entitlements/{userId}, briefingSubscriptions/{userId} 삭제 | 실패 무시 |
| 8 | Firestore 서브컬렉션(auth, settings, cache, personalEvents, recurringEvents) 삭제 | — |
| 9 | Firestore users/{userId} 메인 문서 삭제 | — |
| 10 | Firebase Auth 계정 삭제 | — |

**보안**: 프로필 이미지 삭제 시 `profile_images/{userId}/` prefix 검증 (임의 파일 삭제 방지)
**보류**: subscriptions/{userId}, subscriptionOwners는 결제 이력 보존을 위해 삭제하지 않음

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| U14 | displayName | nickname | ✅ | — |
| U15 | GroupRole | admin, member (2종) | ✅ | ✅ |
| U16 | UserPlan | free, pro (2종) | ✅ | — |
