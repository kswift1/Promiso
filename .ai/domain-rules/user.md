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

### 회원 탈퇴 Cascade (7단계)

| 단계 | 동작 | 실패 시 |
|:----:|------|---------|
| 1 | 그룹 호스트 여부 확인 → 호스트면 차단 | 에러 반환 |
| 2 | 호스트인 약속 전체 삭제 (500개 단위 배치) | — |
| 3 | 모든 그룹의 memberIds에서 제거 | — |
| 4 | 모든 약속의 votes(accepted/declined)에서 제거 | — |
| 5 | Storage 프로필 이미지 + 썸네일 삭제 | 실패 무시 |
| 6 | Firestore 서브컬렉션(auth, settings, cache) 삭제 | — |
| 7 | Firebase Auth 계정 삭제 | — |

**보안**: 프로필 이미지 삭제 시 `profile_images/{userId}/` prefix 검증 (임의 파일 삭제 방지)

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| U14 | displayName | nickname | ✅ | — |
| U15 | GroupRole | admin, member (2종) | ✅ | ✅ |
| U16 | UserPlan | free, pro (2종) | ✅ | — |

---

## 5. 코드 매핑 (Code Mapping)

> 마지막 매핑: 2026-02-12

### 제약 조건

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| U1 | `UserModel.swift` `validateNickname` (count < 2 → tooShort) | `UserModelTests` 2개 | ✅ |
| U2 | `UserModel.swift` `validateNickname` (count > 12 → tooLong) | `UserModelTests` 2개 | ✅ |
| U3 | `UserModel.swift` `validateNickname` (whitespace → containsWhitespace) | `UserModelTests` 1개 | ✅ |
| U4 | `UserModel.swift` `validateNickname` (trim 후 비교) | `UserModelTests` 2개 | ✅ |
| U5 | — (Backend only) | — | — |
| U6 | — (Backend only) | — | — |

### 권한

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| U7 | `AuthClient.swift` Apple/Google 로그인 | `AuthClientModelTests` | ✅ |
| U8~U9 | — (Backend only) | — | — |

### 동작 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| U10 | — (Backend only) | — | — |
| U11 | `ProfileSetup.swift` 디바운스 400ms | — | ❌ |
| U12 | `UserModel.swift` `profileImageUrl` (thumbUrl > url) | `UserModelTests` 3개 | ✅ |
| U13 | — (Backend only) | — | — |

### 표시 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| U14 | `UserModel.swift` `displayName` = nickname | `UserModelTests` 1개 | ✅ |
| U15 | `UserModel.swift` `GroupRole` enum (admin, member) | 모델 정의 | ⚠️ |
| U16 | `UserError.swift` `UserPlan` enum (free, pro) | `ErrorModelTests` 2개 | ✅ |

### ✅ 불일치 검증 완료

| ID | 결과 |
|----|------|
| U2 | 정상 — 회원가입=12자(ProfileSetup), 설정=20자(SettingsFeature), 의도된 설계 |
| U11 | 수정 완료 — ProfileSetup.swift 400ms → 500ms |

### 핵심 파일

| 구현 파일 | 경로 | 관련 규칙 |
|----------|------|----------|
| UserModel.swift | `Clients/Sources/Domain/Models/` | U1-U4,U12,U14-U15 |
| AuthClient.swift | `Clients/Sources/Clients/` | U7 |
| ProfileSetup.swift | `Features/AppEntryFeature/Sources/ProfileSetup/` | U11 |
| UserError.swift | `Clients/Sources/Domain/Errors/` | U16 |

| 테스트 파일 | 경로 | 테스트 수 |
|------------|------|:--------:|
| UserModelTests.swift | `Clients/Tests/` | 11개+ |
| AuthClientModelTests.swift | `Clients/Tests/` | 일부 |
| ErrorModelTests.swift | `Clients/Tests/` | 2개 |
| SettingsFeatureTests.swift | `Features/SettingsFeature/Tests/Sources/` | 닉네임 관련 4개 |
