# Promiso 테스트 커버리지 강화 계획

> 브랜치: `test/coverage-enhancement`
> 목표: 테스트 커버리지 ~8.7% → ~45%

---

## Phase 1: 인프라 구축 ✅

- [x] `scripts/run-changed-tests.sh` — 변경 모듈 감지/빌드/테스트 스크립트
- [x] `scripts/hooks/pre-push` — pre-push hook (환경변수로 빌드/테스트 선택)
- [x] `scripts/install-git-hooks.sh` 수정 — pre-push 설치 추가
- [x] `Makefile` 수정 — test, test-module, build-module, test-changed, build-changed
- [x] `.github/workflows/pr-check.yml` 수정 — 커버리지 리포트 + PR 코멘트
- [x] Phase 1 커밋

---

## Wave 1 (병렬 3개) — Phase 2-1 + 2-2 + 3d ✅

### 워커 A: 공통 테스트 인프라 (Phase 2-2)

- [x] `Clients/Tests/Helpers/TestFactories.swift` — 통합 팩토리 (makePromise, makeGroup 등)
- [x] `Clients/Tests/Mocks/MockPromiseRemoteDataSource.swift`
- [x] `Clients/Tests/Mocks/MockGroupRemoteDataSource.swift`

### 워커 B: XCTest → Swift Testing 마이그레이션 (Phase 2-1)

- [x] `HomeFeature/Tests/Sources/HomeFeatureTests.swift` — Swift Testing으로 재작성
- [x] `AuthFeature/Tests/Sources/AuthFeatureTests.swift` — Swift Testing으로 재작성
- [x] `GroupFeature/Tests/Sources/GroupFeatureTests.swift` — Swift Testing으로 재작성
- [x] `RootTabFeature/Tests/Sources/RootTabFeatureTests.swift` — Swift Testing으로 재작성

### 워커 C: Shared 유틸리티 테스트 (Phase 3d, ~54 tests)

- [x] `Shared/Tests/DatePromiseTests.swift` — Date 확장 (~27)
- [x] `Shared/Tests/StringExtensionsTests.swift` — isNotEmpty, isNilOrEmpty (~6)
- [x] `Shared/Tests/ArrayExtensionsTests.swift` — chunked(into:) (~4)
- [x] `Shared/Tests/EmojiModelsTests.swift` — EmojiEntry 디코딩 (~2)
- [x] `Shared/Tests/EmojiSuggesterTests.swift` — 키워드 기반 이모지 제안 (~5)
- [x] 기존 테스트 파일 확장 — FAQModel, GroupSortOption, LoadingState 등 (~10)

**Wave 1 완료**: `c80075e` 커밋

---

## Wave 2 (병렬 3개) — Phase 3a + 3b + 3c ✅

### 워커 A: Client 레이어 테스트 (Phase 3c, 47 tests)

- [x] `Clients/Tests/PromiseClientTests.swift` — 에러 매핑, localizedDescription (10)
- [x] `Clients/Tests/AuthClientModelTests.swift` — FirebaseUserSnapshot, ServiceTokenBundle (13)
- [x] `Clients/Tests/DataSource/PromiseRemoteDataSourceTests.swift` — Mock 기반 (6)
- [x] `Clients/Tests/DataSource/GroupRemoteDataSourceTests.swift` — Mock 기반 (4)
- [x] `Clients/Tests/DTOMappingTests.swift` — DTO → Model 변환 (14)

### 워커 B: TCA Reducer 테스트 (Phase 3b, ~117 tests)

- [x] `HomeFeature/Tests/Sources/HomeFeatureTests.swift` 확장 (+9)
- [x] `AuthFeature/Tests/Sources/AuthFeatureTests.swift` 확장 (+6)
- [x] `CalendarFeature/Tests/Sources/CalendarFeatureTests.swift` 재작성 (~10)
- [x] `SettingsFeature/Tests/Sources/SettingsFeatureTests.swift` 새 파일
- [x] `GroupFeature/Tests/Sources/CreateGroupReducerTests.swift` 새 파일
- [x] `GroupFeature/Tests/Sources/CreatePromiseReducerTests.swift` 새 파일
- [x] `GroupFeature/Tests/Sources/JoinGroupReducerTests.swift` 새 파일
- [x] `GroupFeature/Tests/Sources/GroupSettingsReducerTests.swift` 새 파일
- [x] `AppEntryFeature/Tests/Sources/AppEntryFeatureTests.swift` 확장 (+7)
- [x] `RootTabFeature/Tests/Sources/RootTabFeatureTests.swift` 확장 (+8)
- [x] `SharedFeature/Tests/Sources/SharedFeatureTests.swift` 재작성 (52)
- [x] `NotificationCenterFeature/Tests/Sources/NotificationCenterFeatureTests.swift` 확장 (+25)

### 워커 C: Domain Model 테스트 (Phase 3a, 156 tests)

- [x] `Clients/Tests/PromiseModelTests.swift` — responseStatus, isConfirmed, isOngoing 등 (52)
- [x] `Clients/Tests/UserModelTests.swift` — validateNickname, toPublic 등 (23)
- [x] `Clients/Tests/NotificationModelTests.swift` — iconName, deeplink 등 (24)
- [x] `Clients/Tests/SupportingTypesTests.swift` — PromiseVotesModel, LocationInfoModel (26)
- [x] `Clients/Tests/ErrorModelTests.swift` — 에러 타입별 localizedDescription (20)
- [x] `Clients/Tests/GroupModelTests.swift` — 초기화, DTO 변환 (11)

**Wave 2 완료**: `67a05e1` 커밋

---

## 최종 검증

- [ ] `tuist test` 전체 통과 (0 failures)
- [ ] `make test-changed` 정상 동작
- [ ] pre-push hook 정상 동작
- [ ] 커버리지 수치 확인 (목표 ~45%)
