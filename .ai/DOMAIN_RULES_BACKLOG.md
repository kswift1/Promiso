# Promiso 도메인 규칙 백로그

> DOMAIN_RULES 에서 발견된 충돌, 누락, 버그, 예정 변경사항을 추적합니다.
> 각 항목이 해결되면 domain-rules/ 파일을 (사용자 허락 후) 업데이트하고 여기서 체크합니다.

---

## 🔴 충돌 해소 (Frontend ↔ Backend 불일치)

| # | 규칙 ID | 내용 | 현재 상태 | 해결 방향 |
|---|---------|------|----------|----------|
| C1 | U2 | 닉네임 최대 길이: iOS 12자 vs Backend 20자 | ❌ 불일치 | Backend 20 → 12로 변경 |
| C2 | G2 | 그룹 이름 최대 길이: iOS 미검증 vs Backend 12자 | ❌ iOS 누락 | iOS에 12자 최대 검증 추가 |
| C3 | G3 | 그룹 설명 최대 길이: iOS CreateGroup 미검증 vs Backend 50자 | ❌ iOS 누락 | iOS에 50자 최대 검증 추가 |
| C4 | P20 | 기본 이모지 불일치: iOS "📌" vs Backend "📅" | ❌ 불일치 | 통일 필요 |

---

## 🟠 iOS 내부 불일치 (버그)

| # | 규칙 ID | 내용 | 현재 상태 | 해결 방향 |
|---|---------|------|----------|----------|
| B1 | U2 | SettingsFeature 닉네임 20자 허용 (ProfileSetup은 12자) | ❌ 불일치 | 12자로 통일 |

---

## 🟡 검증 누락 (한쪽에만 존재하는 검증)

| # | 규칙 ID | 내용 | 누락 위치 | 우선순위 |
|---|---------|------|----------|---------|
| V1 | P4 | 시작 시간 미래 검증 | Backend | 중 |
| V2 | P5 | 종료 시간 > 시작 시간 검증 | Backend | 중 |
| V3 | U3 | 닉네임 공백 검증 | Backend | 높 |
| V4 | P15 | 투표 응답 시 그룹 멤버 확인 | iOS | 낮 (Backend에서 차단) |
| V5 | P7 | 그룹 멤버 2명 이상 확인 | Backend | 중 |
| V6 | P2 | 약속 제목 최대 30자 제한 | Backend | 중 |
| V7 | P3 | 약속 설명 최대 500자 제한 | Backend | 중 |
| V8 | P13 | 시작된 약속 삭제 불가 | iOS | 낮 (Backend에서 차단) |

---

## 🟢 예정된 변경

| # | 규칙 ID | 내용 | 상태 |
|---|---------|------|------|
| F1 | G4 | 그룹 최대 인원 상한: 10명 → **20명**으로 확대 | 📋 예정 |
| F2 | — | 최대 참여 인원 기준: 현재 그룹원 수 → **그룹 최대 인원 수** | 📋 예정 |
| F3 | — | 그룹당 활성 약속 제한 (`maxActivePromisesPerGroup = 10`): **제거** | 📋 예정 |
| F4 | — | 투표 마감 기능: **재설계 예정** (현재 UI 없음) | 📋 예정 |
| F5 | — | 완료된 약속 관련 기능 디벨롭 (사진 등록 등): **추후 고민** | 📋 예정 |

---

## 📝 TODO (구현 작업)

### iOS

| # | 관련 규칙 | 내용 | 상태 |
|---|----------|------|------|
| T1 | G2 | `CreateGroupFeature`에 그룹 이름 최대 길이(12자) 검증 추가 | ⬜ |
| T2 | G3 | `CreateGroupFeature`에 그룹 설명 최대 길이(50자) 검증 추가 | ⬜ |
| T3 | G2 | `GroupSettingsFeature` 그룹 이름 수정 시 12자 제한 적용 | ⬜ |
| T4 | G3 | `GroupSettingsFeature` 그룹 설명 수정 시 50자 제한 적용 | ⬜ |
| T5 | G4 | `MaxMembers` enum 및 `maxMembersUpperLimit` 10 → 20 확대 | ⬜ |
| T6 | F2 | `CreatePromiseFeature` 최대 참여 인원 기준을 그룹 최대 인원으로 변경 | ⬜ |
| T7 | F3 | `maxActivePromisesPerGroup` 상수 및 `isGroupAtLimit` 로직 제거 | ⬜ |
| T8 | F4 | 투표 마감 UI 및 로직 재설계 | ⬜ |
| T9 | B1 | `SettingsFeature` 닉네임 최대 길이 20 → 12로 수정 | ⬜ |
| T10 | C4 | 기본 이모지 통일 ("📌" vs "📅") | ⬜ |

### Backend

| # | 관련 규칙 | 내용 | 상태 |
|---|----------|------|------|
| T12 | U2 | `updateUser` 닉네임 최대 길이 20 → 12로 변경 | ⬜ |
| T13 | U3 | `updateUser`/`createUser` 닉네임 공백 검증 추가 | ⬜ |
| T14 | P4 | `createPromise`에 시작 시간 미래 검증 추가 | ⬜ |
| T15 | P5 | `createPromise`에 종료 시간 검증 추가 | ⬜ |
| T16 | P2 | `createPromise`/`updatePromise`에 제목 30자 제한 추가 | ⬜ |
| T17 | P3 | `createPromise`/`updatePromise`에 설명 500자 제한 추가 | ⬜ |
| T18 | C4 | 기본 이모지 통일 | ⬜ |

---

*마지막 업데이트: 2026-02-12*
