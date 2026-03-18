# Promiso 컨벤션 (Single Source of Truth)

> 모든 에이전트와 도구가 참조하는 유일한 컨벤션 문서.
> 코드 작성, 리뷰, 테스트 시 이 문서를 기준으로 판단합니다.

---

## 1. 아키텍처

### 의존성 방향 (단방향, 위반 시 Critical)
```
App → Features → Clients → Shared
 ↓       ↓         ↓        ↓
ExternalDependency, ResourceKit (모든 레이어에서 접근 가능)
```

### Feature 간 규칙
- Sibling Features 간 직접 의존 금지 (HomeFeature ↔ GroupFeature)
- Parent-Child 계층은 허용 (AppEntryFeature → AuthFeature)
- Feature 간 통신은 Delegate 패턴만 사용
- 외부 통신은 반드시 Client 레이어 통과

### Feature 계층 구조
```
AppEntryFeature (Root Coordinator)
├── AuthFeature
├── ProfileSetup
└── RootTabFeature (Tab Coordinator)
    ├── HomeFeature
    ├── GroupFeature / PersonalFeature (탭 재선택 시 모드 전환)
    ├── CalendarFeature
    └── SettingsFeature
```

### 파일 구조
```
Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift      # Namespace + Reducer
│   ├── {Name}View.swift         # View (또는 Reducer 파일 내 RootView)
│   └── ExportedImports.swift    # 재수출할 의존성
└── Tests/
    └── Sources/{Name}FeatureTests.swift
```

---

## 2. Swift 코딩 컨벤션

### 스타일
- 들여쓰기: **2 spaces**
- 네이밍: camelCase (변수/함수), PascalCase (타입)
- async/await 사용 (completion handler 지양)
- 500라인 이상 파일은 분리 권장

### Critical (위반 시 즉시 수정)

| 항목 | 규칙 |
|------|------|
| 강제 언래핑 `!` | `guard let` 사용 |
| `@BindingState` | `@ObservableState` 사용 |
| `.task { }` | `Effect.run { }` 사용 |
| `.fireAndForget { }` | `Effect.run { }` 사용 |
| 하드코딩 색상 | `Color.pm*` 사용 |
| Feature에서 Firebase 직접 호출 | Client 레이어 통과 필수 |
| Glass Effect Fallback 누락 | `#available(iOS 26)` 분기 필수 |
| XCTest 사용 | Swift Testing (`@Test`, `#expect`) 사용 |
| Button/탭 영역에 Spacer 포함 시 | `.contentShape(Rectangle())` 필수 |

### Warning (권장 수정)

| 항목 | 규칙 |
|------|------|
| 축약 네이밍 (btn, lbl) | 전체 단어 사용 |
| `print()` 문 | 제거 |
| SwiftUI Preview 누락 | 추가 |
| Aurora Background 누락 | 주요 화면에 적용 |

---

## 3. TCA 1.22.2 패턴

### Namespace 패턴 (필수)
```swift
public enum FeatureName {}

extension FeatureName {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable { }

    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
    }

    @CasePathable
    public enum ViewAction: Sendable { case onAppear }
    @CasePathable
    public enum InternalAction: Sendable { case dataLoaded(Result<[Item], Error>) }
    public enum DelegateAction: Equatable { }

    @Dependency(\.someClient) var someClient

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .run { send in
            await send(.internal(.dataLoaded(
              Result { try await someClient.fetch() }
            )))
          }
        case .delegate:
          return .none
        }
      }
    }
  }
}
```

### Action 3분할 (필수)
- **ViewAction**: 사용자 인터랙션 (onAppear, buttonTapped)
- **InternalAction**: 비동기 응답, 내부 상태 변경
- **DelegateAction**: 부모 Feature 통신

### Client 패턴
```swift
@DependencyClient
public struct SomeClient {
  public var fetch: @Sendable () async throws -> [Item]
}

extension SomeClient: DependencyKey {
  public static let liveValue = Self(fetch: { /* 실제 구현 */ })
}

extension SomeClient: TestDependencyKey {
  public static let testValue = Self()
}

extension DependencyValues {
  public var someClient: SomeClient {
    get { self[SomeClient.self] }
    set { self[SomeClient.self] = newValue }
  }
}
```

### 에러/비동기 규칙
- 비동기 실패는 `InternalAction`으로 수렴
- 취소 가능한 Effect: `.cancellable(id:)` + `.cancel(id:)`
- UI 표시용 메시지와 내부 로깅 분리

---

## 4. UI 스타일

### 색상 시스템 (Color.pm* 필수)
```swift
Color.pmindigo.n500       // Primary (n50 ~ n900)
Color.pmaurora.purple     // Aurora 색상
Color.pmbrand.primary     // 브랜드 색상
Color.pmpurple.n500       // Purple 스케일
```

### Glass Effect + Fallback (필수)
```swift
if #available(iOS 26.0, *) {
  content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
  content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}
```

### Glass Effect 사용 기준

| 수식어 | 용도 | 예시 |
|--------|------|------|
| `.adaptiveGlassCard()` | 탭/인터랙션이 있는 섹션 | 버튼, 네비게이션 링크, 카드 탭 |
| `.staticGlassBackground(cornerRadius:)` | 탭 동작 없는 정보 표시 섹션 | 상세 헤더, 읽기 전용 정보 카드 |
| `.adaptiveGlassBackground()` | 탭 동작 있는 배경 (그림자 없음) | 인터랙티브 배경 영역 |

### Aurora Background (주요 화면)
```swift
.auroraBackground()
```

### 탭 영역 확보 (필수)
```swift
Button { } label: {
  HStack {
    Text("Label")
    Spacer()
  }
  .contentShape(Rectangle())
}
```

### View 패턴
- `@Bindable var store` 사용
- `@ViewBuilder` 로 섹션 분리
- 200줄 넘는 View는 서브뷰로 분리
- GeometryReader 남용 금지

### 날짜/시간 포맷
- **사용자 표시용** (UI, 메일 본문 등): `.formatted(date:time:)` 사용 → 로컬 타임존 자동 적용
- **`.iso8601` 사용 금지** — UTC로 표시돼 사용자 혼란 유발
- **서버 저장/로그용**: ISO 8601 + 타임존 명시 (`TimeZone.current.identifier` 함께 기록)

---

## 5. xcstrings 수정 규칙 (Critical)

```
❌ json.dumps / Write로 .xcstrings 파일 전체를 다시 쓰기 금지
❌ Python/스크립트로 파싱 후 재직렬화 금지
✅ Edit 도구로 필요한 부분만 삽입/수정
```

- 새 키 추가: 같은 prefix 그룹의 마지막 항목 뒤에 Edit으로 삽입
- 기존 키 수정: 해당 키의 value만 Edit으로 변경
- 기존 파일의 JSON 포맷(들여쓰기, `" : "` 구분자, 키 순서)을 반드시 유지
- **이유**: 전체 재직렬화 시 Xcode ↔ Python 포맷 차이로 15,000줄+ diff 발생

---

## 6. Git 규칙

### 커밋 메시지
```
<type>: <subject>    ← 한글, 50자 이내, 명령형

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

**Type**: feat | fix | refactor | test | docs | chore | style

### PR 생성
- Base: 최신 `release/` 브랜치 (main 직접 PR 금지)
```bash
latest_release=$(git branch -r | grep 'origin/release/' | sort -V | tail -1 | sed 's/.*origin\///')
gh pr create --base "$latest_release" --title "..." --body "..."
```

---

## 7. 테스트 (Swift Testing)

### 필수 사항
- `import Testing` + `@testable import {Name}Feature`
- `@Suite` + `@Test` + `#expect`
- `TestStore` 사용, `XCTest` 금지

### 패턴
```swift
@Suite("{Name}.Feature 테스트")
@MainActor
struct FeatureTests {
  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = FeatureName.Feature.State()
    #expect(state.someProperty == expectedValue)
  }

  @Test("onAppear 시 데이터 로드")
  func onAppear_loadsData() async {
    let store = TestStore(initialState: FeatureName.Feature.State()) {
      FeatureName.Feature()
    } withDependencies: {
      $0.someClient.fetch = { .mock }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal.dataLoaded) {
      $0.data = .mock
    }
  }
}
```

### 네이밍
- `@Test("한글 설명")` + `func action_condition_result() async`
- MARK 섹션: 초기 상태 / 기능 영역 / 에러 핸들링

### 정책
- 허용/거부 쌍 테스트 필수 (권한/조건 분기)
- 구독 테스트: `cancelSubscriptions`로 정리 필수
- 상세: `.ai/TEST_POLICY.md` 참조

---

## 8. Firebase

### Client 패턴
- `@DependencyClient` + `DependencyKey` + `TestDependencyKey`
- CRUD + Real-time (`AsyncStream`) 분리
- Firestore 스키마: `.ai/FIRESTORE_SCHEMA.md` 참조

### Functions 코드 규칙 (Google ESLint + max-len 80)

`infra/firebase/functions/` 코드는 `google` ESLint 프리셋을 사용한다. 코드 생성 시 아래를 반드시 준수:

| 규칙 | 설명 |
|------|------|
| **max-len 80** | 모든 줄 80자 이내. 긴 문자열은 `+` 연결 또는 줄바꿈 |
| **valid-jsdoc** | export 함수 및 주요 함수에 `@param`, `@return` JSDoc 필수 |
| **quotes: double** | 쌍따옴표(`"`) 사용 |
| **indent: 2** | 2칸 들여쓰기 |

```typescript
// ✅ Good — 80자 이내, JSDoc 완비
/**
 * 가격을 반환한다.
 *
 * @param {string} productId 상품 ID
 * @return {number} 가격
 */
function getPrice(productId: string): number {
  const label = "long text " +
    "continuation";
  return 0;
}

// ❌ Bad — 80자 초과, JSDoc 누락
function getPrice(productId: string): number {
  const label = "this is a very long string that exceeds the eighty character limit";
  return 0;
}
```

**배포 전 검증 필수:**
```bash
cd infra/firebase/functions && npm run lint
```

### 문서 정합
- API 변경 시 OpenAPI (`infra/firebase/functions/openapi.yaml`) 반영
- Firestore 변경 시 `.ai/FIRESTORE_SCHEMA.md` 반영

---

## 9. 참조 문서

| 문서 | 설명 |
|------|------|
| `.ai/DOMAIN_RULES.md` | 도메인 비즈니스 규칙 (수정 금지) |
| `.ai/domain-rules/*.md` | 도메인별 상세 규칙 |
| `.ai/FIRESTORE_SCHEMA.md` | Firestore 데이터 스키마 |
| `.ai/TEST_POLICY.md` | 테스트 설계 기준 |
| `.ai/templates/*.swift` | 코드 템플릿 (Feature/View/Test) |
