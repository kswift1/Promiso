# Test BestPractice 적용 체크리스트

이 문서는 `AppEntryFeatureTests`를 BestPractice 기준으로 삼아 나머지 테스트 파일을 개선/재구성할 때 진행 상황을 추적합니다.

## 기준

- **BestPractice**: `Projects/Features/AppEntryFeature/Tests/Sources/AppEntryFeatureTests.swift`
- **패턴 문서**: `docs/TESTING_DEPENDENCY_RULES.md` §6
- **에이전트**: `.claude/agents/test-writer.md`
- **브랜치**: `test/coverage-enhancement`

## BestPractice 주요 점검 항목

| # | 항목 | 설명 |
|---|------|------|
| 1 | import | `import Testing` + `@testable import {Name}Feature`만 |
| 2 | 구조 | `@Suite` + `@MainActor` + MARK 섹션 분리 |
| 3 | 네이밍 | `@Test("한글")` + `func action_condition_result()` |
| 4 | 의존성 | 필요한 것만 `withDependencies` override |
| 5 | exhaustivity | 기본 on, child reducer 시에만 off (이유 주석) |
| 6 | 구독 정리 | subscription 시작 → `cancelSubscriptions` 필수 |
| 7 | 헬퍼 | 3곳+ 중복 시 `private extension`으로 추출 |
| 8 | 팩토리 | `make{Model}(기본값 + 커스텀)` |
| 9 | 전역 상태 | 변경 시 `defer`로 복원 |
| 10 | 쌍 테스트 | 성공/실패, 허용/거부 양쪽 모두 |

---

## Feature 테스트 (TCA TestStore)

BestPractice 패턴 적용 대상입니다.

### AppEntryFeature

- [x] `AppEntryFeatureTests.swift` (778L → 848L, +4 tests) — **BestPractice 기준 파일**
- [x] `DeeplinkRoutingTests.swift` (390L → 387L, +3 tests, import/헬퍼 정리)

### AuthFeature

- [x] `AuthFeatureTests.swift` (300L → 286L, 중복 제거 + 에러 폴백 테스트 추가, BestPractice 정리)

### CalendarFeature

- [x] `CalendarFeatureTests.swift` (347L → 430L, 11→16 tests, 주석 해제 + BestPractice 정리 + InternalAction @CasePathable 추가)

### GroupFeature

- [x] `GroupFeatureTests.swift` (403L → 429L, 14→17 tests, exhaustivity 정리 + 기존 실패 테스트 수정 + proposalRespondFailed/deletePromiseFailed/sameGroup 추가)
- [x] `CreateGroupReducerTests.swift` (164L → 213L, 8→10 tests, successAcknowledged/settingsSkipped delegate 테스트 추가)
- [x] `CreateGroupPermissionTests.swift` (366L → 348L, 17 tests, import 정리 + @MainActor 통합 + func 스페이싱 수정)
- [x] `CreatePromiseReducerTests.swift` (209L → 300L, 11→17 tests, liveActivityInfo/toggleUseEndTime/createPromiseResponse 추가)
- [x] `CreatePromiseStepTests.swift` (147L, 16 tests) — 이미 BestPractice 준수
- [x] `GroupMainStateTests.swift` (343L → 355L, 15→16 tests, filteredPromises needResponse 추가)
- [x] `GroupSettingsReducerTests.swift` (317L → 504L, 17→27 tests, confirmLeave/confirmDelete/confirmTransferHost + 응답 테스트 추가 + maxMembers 상한 테스트 수정)
- [x] `JoinGroupPermissionTests.swift` (207L → 197L, 9 tests, import 정리 + @MainActor 통합 + func 스페이싱 수정)
- [x] `JoinGroupReducerTests.swift` (124L → 211L, 5→9 tests, nextTapped/previewGroupResponse/joinGroupResponse 추가)

### HomeFeature

- [x] `HomeFeatureTests.swift` (490L → 540L, 20→23 tests, import 정리 + @MainActor + makeStore 헬퍼 + GroupModel Date 안정화)
- [x] `HomeFeatureStateTests.swift` (348L → 464L, 13→19 tests, import 정리 + @MainActor + filteredPromises/timelineData 추가)

### NotificationCenterFeature

- [x] `NotificationCenterFeatureTests.swift` (463L → 710L, 25→38 tests, import 정리 + @MainActor + 누락 액션 테스트 추가)

### RootTabFeature

- [x] `RootTabFeatureTests.swift` (609L → 705L, 28→35 tests)
- [x] `LivePromiseDataTests.swift` (115L → 149L, 6→10 tests)
- [x] `LivePromiseFeatureTests.swift` (399L, 17 tests) — **신규 생성** (+ @Shared withLock 패턴 수정)
- [x] `LivePromiseDetailTests.swift` (243L, 12 tests) — **신규 생성** (+ delegate receive 제거)

### SettingsFeature

- [x] `SettingsFeatureTests.swift` (210L → 390L, 9→21 tests, logoutConfirmed/profileSave/imageDetail 등 추가)
- [x] `CalendarSettingsFeatureTests.swift` (160L, 8 tests) — **신규 생성**
- [x] `NotificationSettingsFeatureTests.swift` (155L, 7 tests) — **신규 생성**
- [x] `GroupNotificationDetailTests.swift` (163L, 7 tests) — **신규 생성**
- [x] `FAQFeatureTests.swift` (209L, 10 tests) — **신규 생성**
- [x] `LegalInfoFeatureTests.swift` (57L, 2 tests) — **신규 생성**
- [x] `SupportFeatureTests.swift` (61L, 2 tests) — **신규 생성**
- [x] `ProfileFeatureTests.swift` — **삭제** (주석 처리된 XCTest 파일)

### SharedFeature

- [x] `SharedFeatureTests.swift` (1026L → 1170L, 55→63 tests, import 정리 + @MainActor 통합 + 기존 실패 테스트 수정 + onAppear/editTapped/resetTapped/mapTapped/setEndDate/saveTapped 추가)

---

## Clients 테스트 (모델/서비스 단위)

TCA TestStore를 사용하지 않는 순수 단위 테스트입니다. BestPractice 중 import/네이밍/구조 규칙만 적용합니다.

- [x] `AuthClientModelTests.swift` (264L) — 이미 BestPractice 준수
- [x] `CalendarSyncClientTests.swift` (619L → 607L, `import ComposableArchitecture` 제거 + @MainActor struct 레벨 통합)
- [x] `DTOMappingTests.swift` (396L → 395L, `import FirebaseFirestore` 제거)
- [x] `DeeplinkNotificationParserTests.swift` (78L) — 이미 BestPractice 준수
- [x] `DeeplinkURLParserTests.swift` (180L) — 이미 BestPractice 준수
- [x] `ErrorModelTests.swift` (182L) — 이미 BestPractice 준수
- [x] `GroupModelTests.swift` (231L) — 이미 BestPractice 준수
- [x] `NotificationModelTests.swift` (257L) — 이미 BestPractice 준수
- [x] `PromiseClientTests.swift` (141L) — 이미 BestPractice 준수
- [x] `PromiseModelTests.swift` (510L) — 이미 BestPractice 준수
- [x] `PromiseModelValidationTests.swift` (221L) — 이미 BestPractice 준수
- [x] `SupportingTypesTests.swift` (290L) — 이미 BestPractice 준수
- [x] `UserModelTests.swift` (225L) — 이미 BestPractice 준수
- [x] `Helpers/TestFactories.swift` (307L) — 이미 BestPractice 준수
- [x] `Mocks/MockGroupRemoteDataSource.swift` (225L) — 이미 BestPractice 준수
- [x] `Mocks/MockPromiseRemoteDataSource.swift` (253L) — 이미 BestPractice 준수

---

## Shared 테스트 (유틸리티/모델)

TCA TestStore를 사용하지 않는 순수 단위 테스트입니다. BestPractice 중 import/네이밍/구조 규칙만 적용합니다.

- [ ] `SharedTests.swift` (557L)
- [ ] `DatePromiseTests.swift` (503L)
- [ ] `CalendarSyncPromiseTests.swift` (257L)
- [ ] `ParticipantStateTests.swift` (113L)
- [ ] `EmojiModelsTests.swift` (107L)
- [ ] `EmojiSuggesterTests.swift` (108L)
- [ ] `StringExtensionsTests.swift` (102L)
- [ ] `ArrayExtensionsTests.swift` (77L)

---

## 커버리지 기록

### AppEntryFeature (2026-02-13)

```
타깃: AppEntryFeature.framework        33.27% (1007/3027)
타깃: AppEntryFeatureTests.xctest       99.18% (1456/1468)
파일: AppEntryFeature.swift             83.88% (770/918)
파일: ProfileSetup.swift                12.30% (237/1927)
파일: AppEntryFeatureTests.swift        98.95% (945/955)
파일: DeeplinkRoutingTests.swift        99.61% (511/513)
```

> 각 모듈 개선 완료 시 커버리지를 측정하여 이 섹션에 추가합니다.
