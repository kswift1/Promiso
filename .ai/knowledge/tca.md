---
updated: 2025-01-29
expires: 2025-02-12
version: 1.23.1
source: https://github.com/pointfreeco/swift-composable-architecture/releases
---

# TCA (The Composable Architecture) 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.
> 2025년 1월 검색 결과 기반.

## 현재 버전 정보

- **최신 버전**: 1.23.1 (2025년 1월 기준)
- **확인 일자**: 2025-01-29
- **출처**: [GitHub Releases](https://github.com/pointfreeco/swift-composable-architecture/releases)

## Promiso 프로젝트 상태

- **사용 중인 버전**: 1.22.2
- **업그레이드 권장**: 1.23.x (버그 수정, 성능 개선)
- **Breaking Change**: 없음 (1.22 → 1.23)

---

## 2025년 릴리즈 요약

### 1.23.x (2025년 1월)

**1.23.1** (최신)
- `Store.publisher`에서 perception check 스킵
- `reportIssue` 포매팅 수정 (콘솔 에러 방지)
- 컴파일러 경고/에러 수정

**1.23.0**
- `@ObservableState`가 Swift 6.2의 `@Observable`과 동일한 `shouldNotifyObservers` 함수 생성
- 중복 observation 감소
- Perception 2.0 지원 (#3736)

### 1.22.x (2024년 말)

- Swift 6 concurrency 완전 지원
- `Sendable` 요구 강화
- iOS 18 최적화

### 1.21.x

- Effect.run에서 task 이름 지정 지원 추가
- 1.21.0 regression 수정 (child store가 nil이 될 때 observation 문제)

### 1.17.x (2025년 1월)

**1.17.1** (2025-01-07)
- Store collections 생성 시 state access 기록 수정 (#3521)
- `Reducer._printChanges()`에서 unasserted shared changes 리포트 안 함 (#3528)
- Sharing requirement를 major 2.0 버전 포함하도록 완화 (#3546)
- Xcode 16 및 이전 iOS 대상 unit test 수정

---

## 핵심 API 가이드

### 1. @ObservableState (필수)

```swift
import ComposableArchitecture

@Reducer
struct MyFeature {
    // ✅ @ObservableState 필수 (iOS 13+ 백포트됨)
    @ObservableState
    struct State: Equatable {
        var count: Int = 0
        var name: String = ""
    }

    enum Action: ViewAction, Sendable {
        case view(ViewAction)
        case _internal(InternalAction)

        enum ViewAction: Sendable {
            case incrementTapped
            case decrementTapped
        }

        enum InternalAction: Sendable {
            case loadCompleted(Result<Data, Error>)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.incrementTapped):
                state.count += 1
                return .none
            // ...
            }
        }
    }
}
```

**특징**:
- `@Observable`이 iOS 17+인 것과 달리, **iOS 13+**까지 백포트
- ViewStore가 더 이상 필요 없음
- 최소한의 상태 변경만 자동 관찰

### 2. Action 분리 패턴

```swift
enum Action: ViewAction, Sendable {
    // View에서 직접 호출하는 액션
    case view(ViewAction)

    // 내부 로직용 (View에서 직접 호출 금지)
    case _internal(InternalAction)

    // 부모 Feature로 delegate
    case delegate(DelegateAction)

    enum ViewAction: Sendable {
        case buttonTapped
        case textChanged(String)
    }

    enum InternalAction: Sendable {
        case dataLoaded(Result<Data, Error>)
    }

    enum DelegateAction: Sendable {
        case didSelectItem(Item)
    }
}
```

### 3. @Dependency 시스템

```swift
@Reducer
struct MyFeature {
    // ✅ 의존성 선언
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.loadTapped):
                return .run { send in
                    let result = await apiClient.fetchData()
                    await send(._internal(.dataLoaded(result)))
                }
            // ...
            }
        }
    }
}
```

**Built-in Dependencies**:
| Dependency | 용도 |
|------------|------|
| `\.date` | 현재 날짜 |
| `\.uuid` | UUID 생성 |
| `\.mainQueue` | 메인 큐 스케줄링 |
| `\.continuousClock` | 시간 기반 작업 |

### 4. @DependencyClient 매크로

```swift
import DependenciesMacros

// ✅ 매크로로 보일러플레이트 감소
@DependencyClient
struct APIClient {
    var fetchUser: @Sendable (String) async throws -> User
    var updateUser: @Sendable (User) async throws -> Void
}

// 자동으로 DependencyKey conformance 생성됨
extension APIClient: DependencyKey {
    static var liveValue: Self {
        Self(
            fetchUser: { id in
                // 실제 구현
            },
            updateUser: { user in
                // 실제 구현
            }
        )
    }

    static var testValue: Self {
        Self()  // 자동으로 unimplemented 버전 생성
    }
}
```

### 5. Effect.run 패턴

```swift
// ✅ 기본 패턴
return .run { send in
    do {
        let data = try await apiClient.fetch()
        await send(._internal(.fetchSucceeded(data)))
    } catch {
        await send(._internal(.fetchFailed(error)))
    }
}

// ✅ Task 이름 지정 (1.21+)
return .run(taskName: "FetchUserData") { send in
    // ...
}

// ✅ 취소 가능
return .run { send in
    // ...
}
.cancellable(id: CancelID.fetch)

// 취소하기
return .cancel(id: CancelID.fetch)
```

### 6. Deprecated API (사용 금지)

```swift
// ❌ @BindingState (deprecated)
@BindingState var text: String

// ✅ @ObservableState 사용
@ObservableState
struct State: Equatable {
    var text: String = ""
}

// ❌ .task { } (deprecated)
.task { ... }

// ✅ Effect.run { } 사용
return .run { send in ... }

// ❌ .fireAndForget { } (deprecated)
.fireAndForget { ... }

// ✅ Effect.run { _ in } 사용 (결과 무시)
return .run { _ in
    await someAsyncWork()
}
```

---

## 성능 최적화

### 1. Effect 직접 반환 (권장)

```swift
// ❌ 비효율적: 불필요한 action 전송
case .view(.buttonTapped):
    return .send(._internal(.startLoading))

case ._internal(.startLoading):
    state.isLoading = true
    return .run { send in
        let data = try await api.fetch()
        await send(._internal(.loaded(data)))
    }

// ✅ 효율적: 직접 Effect 반환
case .view(.buttonTapped):
    state.isLoading = true
    return .run { send in
        let data = try await api.fetch()
        await send(._internal(.loaded(data)))
    }
```

> "Sending actions comes with a cost" - TCA Performance Guide

### 2. 상태 관찰 최소화

```swift
// @ObservableState가 자동으로 최소 관찰 처리
// 하지만 큰 상태 객체는 분리 권장

@ObservableState
struct State: Equatable {
    var ui: UIState       // UI 관련
    var data: DataState   // 데이터 관련
}

struct UIState: Equatable {
    var isLoading: Bool = false
    var selectedTab: Tab = .home
}

struct DataState: Equatable {
    var items: [Item] = []
    var user: User?
}
```

---

## 테스트 작성

### Swift Testing 기반

```swift
import Testing
import ComposableArchitecture

@Suite
struct MyFeatureTests {
    @Test
    func increment() async {
        let store = TestStore(initialState: MyFeature.State()) {
            MyFeature()
        }

        await store.send(.view(.incrementTapped)) {
            $0.count = 1
        }
    }

    @Test
    func asyncDataLoad() async {
        let store = TestStore(initialState: MyFeature.State()) {
            MyFeature()
        } withDependencies: {
            $0.apiClient.fetchData = { .success(mockData) }
        }

        await store.send(.view(.loadTapped)) {
            $0.isLoading = true
        }

        await store.receive(._internal(.dataLoaded(.success(mockData)))) {
            $0.isLoading = false
            $0.data = mockData
        }
    }
}
```

### Exhaustivity 끄기 (선택)

```swift
// 모든 action을 검증하지 않아도 될 때
store.exhaustivity = .off
```

---

## 마이그레이션 가이드

### 1.7 이전 → 1.7+ (ViewStore 제거)

```swift
// ❌ 이전 방식
struct MyView: View {
    let store: StoreOf<MyFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Text("\(viewStore.count)")
            Button("Increment") {
                viewStore.send(.incrementTapped)
            }
        }
    }
}

// ✅ 1.7+ 방식
struct MyView: View {
    @Bindable var store: StoreOf<MyFeature>

    var body: some View {
        Text("\(store.count)")
        Button("Increment") {
            store.send(.view(.incrementTapped))
        }
    }
}
```

### 1.22 → 1.23 (변경 사항 없음)

- Breaking change 없음
- 버그 수정 및 성능 개선만 포함
- 업그레이드 권장

---

## Promiso 프로젝트 컨벤션

### Feature 구조

```swift
// Projects/Features/{Name}Feature/Sources/{Name}Feature.swift

import ComposableArchitecture

public enum {Name}Feature {}

extension {Name}Feature {
    @Reducer
    public struct Feature {
        @ObservableState
        public struct State: Equatable {
            // ...
        }

        public enum Action: ViewAction, Sendable {
            case view(ViewAction)
            case _internal(InternalAction)

            public enum ViewAction: Sendable {
                // ...
            }

            enum InternalAction: Sendable {
                // ...
            }
        }

        public init() {}

        public var body: some ReducerOf<Self> {
            Reduce { state, action in
                // ...
            }
        }
    }
}
```

### View 구조

```swift
// Projects/Features/{Name}Feature/Sources/{Name}View.swift

import ComposableArchitecture
import SwiftUI

public struct {Name}View: View {
    @Bindable var store: StoreOf<{Name}Feature.Feature>

    public init(store: StoreOf<{Name}Feature.Feature>) {
        self.store = store
    }

    public var body: some View {
        // Aurora Background + Glass Effect
        // ...
    }
}

#Preview {
    {Name}View(
        store: Store(initialState: .init()) {
            {Name}Feature.Feature()
        }
    )
}
```

---

## 자주 묻는 질문

### Q: @BindingState 대신 무엇을 사용하나요?
A: `@ObservableState`를 사용합니다. TCA 1.7부터 도입되었습니다.

### Q: .task { } 대신 무엇을 사용하나요?
A: `Effect.run { }` 또는 `.send()`를 사용합니다.

### Q: .fireAndForget { } 대신 무엇을 사용하나요?
A: `Effect.run { _ in ... }` (결과 무시)를 사용합니다.

### Q: ViewStore가 필요한가요?
A: 아니오. TCA 1.7+에서는 `@Bindable var store`를 직접 사용합니다.

### Q: iOS 13에서 @ObservableState가 작동하나요?
A: 네. TCA가 Observation 프레임워크를 iOS 13까지 백포트했습니다.

### Q: 1.22.2에서 1.23.1로 업그레이드해도 되나요?
A: 네. Breaking change가 없으므로 안전합니다.

---

## 참고 자료

### 공식 자료
- [TCA GitHub](https://github.com/pointfreeco/swift-composable-architecture)
- [TCA Releases](https://github.com/pointfreeco/swift-composable-architecture/releases)
- [TCA Documentation](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/)
- [1.7 Migration Guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7)
- [1.10 Migration Guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.10)

### 커뮤니티 자료
- [TCA Performance Best Practices](https://medium.com/@glaphi/tca-performance-best-practices-return-effects-directly-4c73de02e01b)
- [Composable Architecture in 2025](https://commitstudiogs.medium.com/composable-architecture-in-2025-building-scalable-swiftui-apps-the-right-way-134199aff811)
- [Dependency Injection in TCA (2025)](https://medium.com/@gauravios/dependency-injection-in-the-composable-architecture-an-architects-perspective-9be5571a0f89)
- [TCA FAQ - Point-Free](https://www.pointfree.co/blog/posts/141-composable-architecture-frequently-asked-questions)

---

*마지막 업데이트: 2025-01-29 (웹 검색 기반)*
