# 테스트 의존성 규칙

Promiso의 TCA 테스트(`TestStore`)에서 의존성 주입을 일관되게 구현하기 위한 상세 규칙입니다.  
`testValue` 동작 원리, `Unimplemented` 대응, 중복 링킹(`objc ... implemented in both ...`) 방지 기준을 포함합니다.

## 문서 메타

- 목적: 테스트 의존성 주입/검증 규칙의 단일 기준 제공
- 대상 독자: Feature 테스트 작성/수정 개발자
- 최종 수정일: 2026-02-13
- 관련 문서: [DEVELOPMENT.md](DEVELOPMENT.md) · [ARCHITECTURE.md](ARCHITECTURE.md)

---

## 1. 핵심 원칙

1. `TestStore`에서 override하지 않은 의존성은 자동으로 `testValue`를 사용한다.
2. `testValue`는 기본적으로 `unimplemented(...)`를 유지해 누락된 mock을 즉시 실패시킨다.
3. 테스트는 "필요한 의존성만 명시 override"를 기본 전략으로 한다.
4. 중복 링킹이 발생한 상태에서는 `withDependencies` override가 있어도 오동작할 수 있다.  
   먼저 링크 구조를 정상화한 뒤 테스트 실패를 해석한다.

---

## 2. `liveValue` / `previewValue` / `testValue` 사용 시점

- `liveValue`: 실제 앱 실행
- `previewValue`: SwiftUI Preview
- `testValue`: `TestStore` / 테스트 컨텍스트

즉, 테스트 코드에서 `withDependencies`를 생략하면 해당 의존성은 `testValue`로 해석된다.

---

## 3. 테스트 구현 규칙

### 3.1 기본 형태

```swift
let store = TestStore(initialState: Feature.State()) {
  Feature()
} withDependencies: {
  $0.someClient.fetch = { ... }
  $0.someClient.save = { ... }
}
```

### 3.2 권장 패턴: 기본 stub 헬퍼 + 테스트별 override

```swift
private func applyDefaultDependencies(_ dependencies: inout DependencyValues) {
  dependencies.analyticsClient.logEvent = { _, _ in }
  dependencies.notificationClient.setBadgeCount = { _ in }
}

func makeStore(
  state: Feature.State,
  configure: (inout DependencyValues) -> Void = { _ in }
) -> TestStoreOf<Feature> {
  TestStore(initialState: state) {
    Feature()
  } withDependencies: {
    applyDefaultDependencies(&$0)
    configure(&$0)
  }
}
```

규칙:

1. 공통적으로 필요한 no-op 의존성은 `applyDefaultDependencies`에 둔다.
2. 테스트가 검증하려는 동작은 각 테스트에서 명시 override한다.
3. override는 해당 테스트 본문에 가깝게 작성한다.

### 3.3 `Unimplemented` 에러 해석

`Unimplemented: XxxClient.yyy ...`는 정상적인 경고 신호다.  
의미는 단 하나다: 해당 테스트 경로에서 필요한 의존성 override가 빠졌다.

대응 순서:

1. 실패 액션 경로 확인 (`onAppear`, delegate, child action 등)
2. 해당 액션이 호출하는 의존성 함수 목록 확인
3. 테스트 `withDependencies` 또는 기본 헬퍼에 stub 추가

### 3.4 `exhaustivity` / in-flight effect 규칙

1. 모든 effect까지 엄격 검증할 때: 기본 `exhaustive` 유지
2. child reducer 부수효과는 무시하고 root 상태만 검증할 때:
   - `store.exhaustivity = .off(showSkippedAssertions: false)`
3. 테스트 종료 전에 장수 effect 정리:
   - `await store.finish()`
   - 또는 의도적으로 무시: `await store.skipInFlightEffects()`

---

## 4. 중복 링킹 방지 규칙 (중요)

### 4.1 증상

다음 로그가 보이면 중복 링킹이다:

- `Class ... is implemented in both ... ExternalDependency.framework ... and ... <FeatureTests>.xctest`

### 4.2 의미

`ComposableArchitecture`/`Dependencies` 타입이 두 바이너리에 중복 내장된 상태다.  
이 상태에서는 타입 캐스팅 실패, 의존성 override 미적용, 랜덤 크래시가 발생할 수 있다.

### 4.3 필수 규칙

1. 같은 타겟에서 TCA 계열 의존성 경로를 혼용하지 않는다.
   - 경로 A: `ExternalDependency` 경유
   - 경로 B: 직접 SPM import
   - A/B를 타겟 단위에서 섞지 않는다.
2. 테스트 타겟에 불필요한 직접 의존성을 추가하지 않는다.
   - 기본은 `테스트 대상 Feature`만 의존
   - `@testable import`도 실제 필요한 모듈만 사용
3. 패키지 링크 타입을 일관되게 유지한다.
   - `Tuist/Package.swift`의 `PackageSettings(productTypes:)`로 TCA/Dependencies 계열 고정

### 4.4 변경 후 필수 재생성 절차

링크 관련 설정을 바꾼 뒤에는 반드시 아래 순서를 따른다.

1. `tuist install`
2. `tuist generate`
3. DerivedData 정리
4. 테스트 재실행

> 과거 빌드 산출물이 남아 있으면 이전 링크 구성이 계속 사용될 수 있다.

---

## 5. Feature 테스트 작성 체크리스트

PR 전 점검:

1. `Unimplemented` 로그가 없는가?
2. `objc ... implemented in both ...` 로그가 없는가?
3. 필요한 의존성 override가 테스트 의도와 1:1로 대응되는가?
4. 장수 effect 테스트는 `finish` 또는 cancel 경로가 있는가?
5. child reducer 검증이 목적이 아니면 `exhaustivity` 전략을 명시했는가?

---

## 6. BestPractice: AppEntryFeatureTests

> 참조 파일: `Projects/Features/AppEntryFeature/Tests/Sources/AppEntryFeatureTests.swift`

새 Feature 테스트 작성 시 이 파일의 패턴을 기준으로 따른다.

### 6.1 파일 구조

```
import Testing                          // Swift Testing만
@testable import {Name}Feature          // Feature 모듈만 의존

@Suite("{Name}.Feature 테스트")
@MainActor
struct {Name}FeatureTests {
  // MARK: - 초기 상태 테스트       ← 항상 첫 섹션
  // MARK: - {기능 영역} 테스트     ← 기능별 MARK 분리
  // MARK: - 에러 핸들링 테스트
}

private extension {Name}FeatureTests {
  // 헬퍼 메서드, 팩토리, actor 등
}
```

### 6.2 핵심 패턴 요약

| 패턴 | 규칙 | 예시 |
|------|------|------|
| import | `Testing` + `@testable import Feature`만 | ExternalDependency 직접 의존 금지 |
| 의존성 주입 | 필요한 것만 `withDependencies`에서 override | 나머지는 `testValue`(unimplemented) |
| exhaustivity | 기본 on, child reducer 영향 시에만 off | off 사용 시 이유 주석 권장 |
| 구독 정리 | subscription 시작한 테스트는 `cancelSubscriptions` 필수 | `await store.send(.internal(.cancelSubscriptions))` |
| 반복 체인 | 3곳 이상 중복 시 헬퍼 메서드 추출 | `receiveContinueAppFlowUnauthenticated` |
| 모델 팩토리 | 기본값 + 커스텀 파라미터 | `makeUser(id:nickname:)` |
| 비동기 캡처 | `actor` 기반 thread-safe 캡처 | `URLRecorder` |
| 전역 상태 | 변경 시 `defer`로 원래 값 복원 | `defer { Global.value = original }` |
| 에러 테스트 | 성공 + 실패 쌍으로 검증 | 로그아웃 성공/실패, FCM 저장 성공/실패 |
| 허용/거부 쌍 | 조건 분기 양쪽 모두 테스트 | 인증됨/미인증, 권한 허용/거부 |

### 6.3 네이밍 컨벤션

- `@Test`: 한글 설명 (`"onAppear 시 버전 체크 시작"`)
- 함수명: 영어, `action_condition_expectedResult` (`onAppear_startsVersionCheck`)
- 헬퍼: `make{Model}` 팩토리, `receive{Flow}` 체인 헬퍼
