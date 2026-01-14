# Promiso iOS Style Guide

이 문서는 Promiso iOS 프로젝트의 코드 리뷰 가이드라인을 정의합니다.

---

## 핵심 원칙

- **일관성**: 기존 코드 패턴을 따릅니다
- **단순성**: 과도한 추상화를 지양합니다
- **안전성**: 런타임 크래시를 방지하는 코드를 작성합니다
- **테스트 용이성**: Protocol 기반 설계로 테스트 가능한 코드를 작성합니다

---

## 아키텍처

### TCA (The Composable Architecture)

Feature는 하나의 파일에 다음 순서로 정의합니다:

1. Feature Namespace (`enum`)
2. Reducer (`@Reducer struct Feature`)
3. State (`@ObservableState struct State`)
4. Action (`@CasePathable enum Action`)
5. Reducer Body (`var body`) - switch 중첩 방식
6. RootView (`struct RootView: View`)

```swift
// ✅ 올바른 예시
public enum Home {}

extension Home {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    public init() {}

    // MARK: - State
    @ObservableState
    public struct State: Equatable {
      var items: LoadingState<[ItemModel]> = .idle
    }

    // MARK: - Action
    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case refreshTriggered
      }

      public enum Internal: Sendable {
        case fetchResponse(Result<[ItemModel], Error>)
      }

      public enum Delegate: Sendable {
        case navigateToDetail(id: String)
      }
    }

    // MARK: - Reducer Body
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.items = .loading
            return .run { [client = promiseClient] send in
              do {
                let items = try await client.fetch()
                await send(.internal(.fetchResponse(.success(items))))
              } catch {
                await send(.internal(.fetchResponse(.failure(error))))
              }
            }

          case .refreshTriggered:
            return .send(.view(.onAppear))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchResponse(.success(let items)):
            state.items = .loaded(items)
            return .none

          case .fetchResponse(.failure(let error)):
            state.items = .failed(error)
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View
  public struct RootView: View {
    private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      // View 구현
    }
  }
}
```

### Action 분류 규칙

| 분류 | 용도 | 예시 |
|------|------|------|
| `view` | 사용자 인터랙션, UI 이벤트 | `onAppear`, `buttonTapped`, `refreshTriggered` |
| `internal` | 비동기 작업 결과, 내부 로직 | `fetchResponse(Result<T, Error>)` |
| `delegate` | 상위 Feature로 위임 | `navigateToDetail(id:)` |

### Switch 바인딩 네이밍

Reducer body에서 action을 switch할 때 바인딩 변수명을 통일합니다:

```swift
// ✅ 올바른 예시
switch action {
case .view(let viewAction):
  switch viewAction { ... }
case .internal(let internalAction):
  switch internalAction { ... }
case .delegate(let delegateAction):
  switch delegateAction { ... }
}

// ❌ 잘못된 예시
switch action {
case .view(let action):      // 상위 action과 이름 충돌
  switch action { ... }
case .internal(let a):       // 의미 없는 이름
  switch a { ... }
}
```

### Clean Architecture 레이어

```
Feature (Presentation)
    ↓
Client (TCA Dependency Interface)
    ↓
DataSource (Data Layer)
    ↓
Firebase / Remote API (Infrastructure)
```

- **Client**: TCA `@DependencyClient`로 정의, 비즈니스 로직 인터페이스
- **DataSource**: Protocol 기반, 실제 데이터 접근 구현
- **Firestore 쿼리는 DataSource 레이어에서만 수행합니다**

---

## Swift 컨벤션

### Concurrency

- Swift 6 Concurrency를 사용합니다
- 모든 Action enum은 `Sendable`을 준수합니다
- UI 관련 코드에는 `@MainActor`를 명시합니다

```swift
// ✅ 올바른 예시
public enum Action: Sendable {
  case view(View)
}

// ❌ 잘못된 예시
public enum Action {  // Sendable 누락
  case view(View)
}
```

### 안전한 코드

다음은 사용하지 않습니다:
- 강제 언래핑 (`!`)
- 강제 캐스팅 (`as!`)
- 강제 try (`try!`)

```swift
// ✅ 올바른 예시
guard let value = optionalValue else { return }
if let casted = object as? TargetType { }

// ❌ 잘못된 예시
let value = optionalValue!
let casted = object as! TargetType
```

### 상태 관리

로딩 상태는 `LoadingState<T>` enum을 사용합니다:

```swift
// ✅ 올바른 예시
var itemsState: LoadingState<[ItemModel]> = .idle

var items: [ItemModel] {
  itemsState.value ?? []
}

// ❌ 잘못된 예시
var items: [ItemModel] = []
var isLoading: Bool = false
var error: Error? = nil
```

---

## 네이밍 규칙

### 파일 네이밍

| 유형 | 패턴 | 예시 |
|------|------|------|
| Feature | `{Feature}Feature.swift` | `HomeFeature.swift` |
| Client | `{Domain}Client.swift` | `PromiseClient.swift` |
| DataSource | `{Domain}RemoteDataSource.swift` | `PromiseRemoteDataSource.swift` |
| Model | `{Name}Model.swift` | `PromiseModel.swift` |
| DTO | `{Name}DTO.swift` | `PromiseDTO.swift` |
| View Component | `{Name}Section.swift`, `{Name}Card.swift` | `TodayPromiseSection.swift` |

### 코드 네이밍

- 변수/함수: `camelCase`
- 타입/프로토콜: `PascalCase`
- 상수: `camelCase` (UPPER_SNAKE_CASE 사용하지 않음)

```swift
// ✅ 올바른 예시
let maximumRetryCount = 3
struct PromiseModel {}
protocol DataSourceProtocol {}

// ❌ 잘못된 예시
let MAXIMUM_RETRY_COUNT = 3
```

---

## SwiftUI View

### iOS 26.0 및 glassEffect API

이 프로젝트는 iOS 26.0에서 도입된 `glassEffect` API를 사용합니다. **iOS 26.0은 실제로 존재하는 버전**이며, `glassEffect`는 visionOS 전용이 아닌 iOS 26.0에서도 사용 가능한 API입니다.

```swift
// ✅ 올바른 예시 - iOS 26.0 glassEffect 사용
@ViewBuilder
func adaptiveGlassBackground() -> some View {
  if #available(iOS 26.0, *) {
    self
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
  } else {
    self
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}
```

> **참고**: 코드 리뷰 시 `#available(iOS 26.0, *)` 체크를 오타로 판단하지 마세요. iOS 26.0은 실제 버전이며, glassEffect는 iOS 26.0에서 정식 지원됩니다.

### View 구조

- `StoreOf<Feature>`를 주입받습니다
- 복잡한 레이아웃은 `private var` 또는 `private func`로 분리합니다
- `MARK: -` 주석으로 섹션을 구분합니다

```swift
struct ItemSection: View {
  private let store: StoreOf<Home.Feature>

  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack {
      header
      content
    }
  }

  // MARK: - Private Views

  private var header: some View {
    Text("Header")
  }

  private var content: some View {
    // 조건부 렌더링
  }
}
```

### Preview

`#Preview` 매크로를 사용합니다:

```swift
#Preview("기본 상태") {
  Home.RootView(
    store: Store(initialState: Home.Feature.State(currentUser: .mock)) {
      Home.Feature()
    }
  )
}
```

---

## 에러 처리

### Client 에러 정의

각 Client는 도메인별 Error enum을 정의합니다:

```swift
public enum PromiseClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case invalidData(String?)
  case unknown(String?)

  // 사용자에게 보여줄 메시지
  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .notFound:
      return "요청한 정보를 찾을 수 없습니다"
    // ...
    }
  }

  // Firebase 에러 변환
  init(from error: Error) {
    // 에러 매핑 로직
  }
}
```

### Effect에서 에러 처리

```swift
return .run { [client] send in
  do {
    let result = try await client.fetch()
    await send(.internal(.fetchResponse(.success(result))))
  } catch {
    await send(.internal(.fetchResponse(.failure(error))))
  }
}
```

---

## 주석 및 문서화

### 허용되는 주석

- 한국어 주석 허용
- `MARK: -`로 섹션 구분
- `///`로 public API 문서화

```swift
// MARK: - State

/// 사용자의 현재 약속 목록을 관리하는 상태
@ObservableState
public struct State: Equatable {
  /// 오늘의 약속 로딩 상태
  var todaysPromisesState: LoadingState<[PromiseModel]> = .idle
}
```

### MARK 주석 순서

Feature 파일에서 권장하는 MARK 순서:

```swift
// MARK: - State
// MARK: - Computed Properties
// MARK: - Action
// MARK: - Reducer Body
// MARK: - Root View
// MARK: - Private Views
```

---

## 비동기 작업

### 병렬 실행

독립적인 작업은 `.merge`로 병렬 실행합니다:

```swift
// ✅ 올바른 예시 - 병렬 실행
return .merge(
  .run { send in
    let promises = try await promiseClient.getTodayPromises(userId)
    await send(.internal(.todayPromisesResponse(.success(promises))))
  },
  .run { send in
    let upcoming = try await promiseClient.getUpcomingPromises(userId)
    await send(.internal(.upcomingResponse(.success(upcoming))))
  }
)

// ❌ 잘못된 예시 - 순차 실행 (불필요하게 느림)
return .run { send in
  let promises = try await promiseClient.getTodayPromises(userId)
  await send(.internal(.todayPromisesResponse(.success(promises))))
  let upcoming = try await promiseClient.getUpcomingPromises(userId)
  await send(.internal(.upcomingResponse(.success(upcoming))))
}
```

### 실시간 구독

Firestore 실시간 리스너는 `AsyncStream`으로 래핑합니다:

```swift
func subscribeToPromises(groupId: String) -> AsyncStream<[PromiseModel]> {
  AsyncStream { continuation in
    let listener = db.collection("promises")
      .whereField("groupId", isEqualTo: groupId)
      .addSnapshotListener { snapshot, error in
        guard let documents = snapshot?.documents else { return }
        let promises = documents.compactMap { try? $0.data(as: PromiseModel.self) }
        continuation.yield(promises)
      }

    continuation.onTermination = { _ in
      listener.remove()
    }
  }
}
```

---

## 테스트

### 테스트 파일 위치

각 Feature 모듈의 `Tests/` 디렉토리에 위치합니다.

### Client Mock

TCA의 `TestDependencyKey`를 활용합니다:

```swift
extension PromiseClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    getTodayPromises: { _, _ in [.mock] },
    createPromise: { _ in UUID().uuidString }
  )
}
```

---

## 금지 사항

다음 패턴은 코드 리뷰에서 반드시 수정을 요청합니다:

1. **강제 언래핑/캐스팅**: `!`, `as!`, `try!` 사용
2. **Sendable 미준수**: Action enum에 Sendable 누락
3. **레이어 위반**: Feature에서 직접 Firestore 접근
4. **분리되지 않은 Action**: view/internal/delegate 구분 없이 flat한 Action
5. **하드코딩된 문자열**: 반복되는 문자열은 상수로 추출
6. **미사용 코드**: 주석 처리된 코드, 사용하지 않는 import

---

## 폴더 구조

```
Projects/
├── App/                      # 앱 진입점
├── Features/                 # Feature 모듈
│   ├── HomeFeature/
│   │   ├── Sources/
│   │   │   ├── HomeFeature.swift
│   │   │   ├── Components/
│   │   │   └── Models/
│   │   └── Tests/
│   └── ...
├── Clients/                  # 데이터 레이어
│   └── Sources/
│       ├── Clients/          # TCA Dependency
│       ├── Data/             # DataSource, DTO
│       ├── Domain/           # 도메인 모델
│       └── Infrastructure/   # Firebase 등
├── Shared/                   # 공용 유틸리티
└── ResourceKit/              # 리소스 관리
```
