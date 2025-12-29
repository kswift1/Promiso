# 프로젝트 컨텍스트 (AI Assistant를 위한 가이드)

> 이 문서는 Claude Code, Codex, GitHub Copilot 등 AI 도구가 프로젝트를 이해하고 일관된 코드를 생성하도록 돕습니다.

## 📋 프로젝트 개요

**프로젝트명**: Promiso
**설명**: 그룹 기반 약속 관리 iOS 애플리케이션
**플랫폼**: iOS 18.0+
**주요 기술**: SwiftUI, TCA (1.22.2), Firebase, Tuist (4.65.7)

## 🏗️ 아키텍처

### 전체 구조
```
TCA 기반 Feature-Driven Architecture
- App: 앱 진입점 및 의존성 초기화
- Features: 화면별 독립적인 TCA Reducer + View
- Clients: 외부 의존성 추상화 (TCA Dependency)
- Shared: 공통 모델 및 UI 컴포넌트
- ExternalDependency: SPM으로 관리되는 외부 라이브러리 (TCA, Firebase 등)
- ResourceKit: 공통 리소스 (Assets, Fonts, Colors)
```

### 의존성 방향
```
App → Features → Clients → Shared
 ↓       ↓         ↓        ↓
ExternalDependency, ResourceKit (모든 레이어에서 접근 가능)
```

### Feature 간 의존성 규칙

**기본 원칙**:
- ❌ **Sibling Features 간 직접 의존 금지** (HomeFeature ↔ GroupFeature)
- ✅ **Parent-Child 계층 구조는 허용** (AppEntryFeature → AuthFeature)
- ✅ 모든 외부 통신은 Client를 통해서만
- ✅ Shared는 누구에게도 의존하지 않음

**Parent-Child Feature 계층 구조**:
```
AppEntryFeature (Root Coordinator)
├── AuthFeature
├── ProfileSetup
└── RootTabFeature (Tab Coordinator)
    ├── HomeFeature
    └── GroupFeature
```

**설명**:
- **Coordinator Feature** (AppEntryFeature, RootTabFeature): 네비게이션과 화면 전환을 담당하는 부모 Feature는 자식 Feature들을 직접 의존할 수 있음
- **Leaf Feature** (HomeFeature, GroupFeature): 실제 비즈니스 로직을 담당하는 Feature들은 서로 의존하지 않음
- Feature 간 통신은 **Delegate 패턴**을 통해서만 수행

## 🎯 코딩 컨벤션

### Swift 스타일
```swift
// ✅ 선호하는 스타일
- 들여쓰기: 2 spaces
- 네이밍: camelCase (변수, 함수), PascalCase (타입)
- async/await 사용 (completion handler 지양)
- SwiftUI Preview 필수 포함
- @ObservableState 사용 (TCA 1.7+)
- Action 하위 enum에 Sendable 프로토콜 준수 (Swift 6 Concurrency 대비)

// ❌ 지양하는 스타일
- 강제 언래핑 (!)
- 옵셔널 체이닝 남발
- 과도한 축약 (btn, lbl 등)
```

### 파일 구조 규칙

#### Feature 기본 구조 (Namespace 패턴)
```swift
// 모든 Feature는 Namespace enum을 사용
public enum FeatureName {}

extension FeatureName {
    @Reducer
    public struct Feature {
        // Reducer 구현
    }

    public struct RootView: View {
        // View 구현
    }
}
```

#### 파일 배치
```swift
// Feature 파일 구조
FeatureNameFeature/
├── Sources/
│   ├── FeatureNameFeature.swift    // Reducer (Namespace + Feature)
│   ├── ExportedImports.swift       // 재수출할 의존성
│   └── Models/                      // Feature 전용 모델 (optional)
└── Tests/
    └── FeatureNameFeatureTests.swift

// Reducer 파일 내부 구조
// 1. Namespace 선언
public enum FeatureName {}

// 2. Feature Reducer
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

        public enum ViewAction: Sendable { }
        public enum InternalAction: Sendable { }
        public enum DelegateAction: Equatable { }

        @Dependency(\.clientName) var clientName

        public var body: some ReducerOf<Self> {
            Reduce { state, action in
                // 로직
            }
        }
    }
}

// 3. RootView
extension FeatureName {
    public struct RootView: View {
        let store: StoreOf<Feature>

        public var body: some View {
            // UI
        }
    }
}

// 4. Preview
#Preview {
    FeatureName.RootView(
        store: Store(initialState: FeatureName.Feature.State()) {
            FeatureName.Feature()
        }
    )
}
```

## 🔧 TCA 패턴

### Action 계층 구조 (필수)

**모든 Feature는 Action을 계층화해야 합니다:**

```swift
@Reducer
public struct Feature {
    public enum Action {
        case view(ViewAction)              // 사용자 인터랙션
        case `internal`(InternalAction)    // 내부 상태 변경 & 비동기 응답
        case delegate(DelegateAction)      // 부모 Feature와 통신
        case destination(PresentationAction<Destination.Action>)  // 자식 Feature 네비게이션 (optional)
    }

    // 1. ViewAction: 사용자가 직접 트리거하는 액션
    // 네이밍: ViewAction 또는 View (둘 다 허용)
    public enum ViewAction: Sendable {
        case onAppear
        case buttonTapped
        case textChanged(String)
        case logoutTapped
    }

    // 2. InternalAction: 시스템 내부에서 발생하는 액션
    // 네이밍: InternalAction 또는 Internal (둘 다 허용)
    public enum InternalAction: Sendable {
        case dataResponse(Result<[Item], Error>)
        case timerTicked
        case updateState(newValue: String)
    }

    // 3. DelegateAction: 부모 Feature에게 전달할 이벤트
    // 네이밍: DelegateAction 또는 Delegate (둘 다 허용)
    public enum DelegateAction: Equatable {
        case itemSelected(Item)
        case completed
        case logoutRequested
    }

    // 4. Destination (Optional): 자식 Feature가 있을 경우
    @Reducer
    public enum Destination {
        case detail(DetailFeature)
        case settings(SettingsFeature)
    }
}
```

**Action 처리 패턴**:
```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        // View Actions
        case .view(.onAppear):
            state.isLoading = true
            return .run { send in
                await send(.internal(.dataResponse(
                    Result { try await apiClient.fetchItems() }
                )))
            }

        case .view(.buttonTapped):
            return .send(.delegate(.completed))

        // Internal Actions
        case let .internal(.dataResponse(.success(items))):
            state.isLoading = false
            state.items = items
            return .none

        case let .internal(.dataResponse(.failure(error))):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none

        // Delegate Actions (부모에게 전달만 함)
        case .delegate:
            return .none

        // Destination Actions
        case .destination:
            return .none
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

### Reducer 작성 규칙 (전체 예시)
```swift
// ✅ 올바른 패턴
public enum MyFeature {}

extension MyFeature {
    @Reducer
    public struct Feature {
        @ObservableState
        public struct State: Equatable {
            var data: [Item] = []
            var isLoading = false
            var errorMessage: String?
        }

        public enum Action {
            case view(ViewAction)
            case `internal`(InternalAction)
            case delegate(DelegateAction)
        }

        public enum ViewAction: Sendable {
            case onAppear
            case itemTapped(Item.ID)
            case refreshButtonTapped
        }

        public enum InternalAction: Sendable {
            case dataResponse(Result<[Item], Error>)
        }

        public enum DelegateAction: Equatable {
            case itemSelected(Item)
        }

        @Dependency(\.apiClient) var apiClient

        public var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .view(.onAppear):
                    state.isLoading = true
                    return .run { send in
                        await send(.internal(.dataResponse(
                            Result { try await apiClient.fetchItems() }
                        )))
                    }

                case let .internal(.dataResponse(.success(items))):
                    state.isLoading = false
                    state.data = items
                    return .none

                case let .internal(.dataResponse(.failure(error))):
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                    return .none

                case let .view(.itemTapped(id)):
                    guard let item = state.data.first(where: { $0.id == id }) else {
                        return .none
                    }
                    return .send(.delegate(.itemSelected(item)))

                case .view(.refreshButtonTapped):
                    return .send(.view(.onAppear))

                case .delegate:
                    return .none
                }
            }
        }
    }
}

// ❌ 피해야 할 패턴
// - State에 비즈니스 로직 포함
// - Action 계층화 없이 flat 구조 사용
// - 에러 처리 없음
// - Delegate 패턴 없이 Feature 간 직접 통신
```

### Client 작성 규칙
```swift
// ✅ 올바른 Client 구조
// Clients/APIClient/Sources/APIClient.swift
import ComposableArchitecture

@DependencyClient
public struct APIClient {
    public var fetchItems: @Sendable () async throws -> [Item]
    public var createItem: @Sendable (Item) async throws -> String
    public var deleteItem: @Sendable (String) async throws -> Void
}

extension APIClient: DependencyKey {
    public static let liveValue = Self(
        fetchItems: {
            // 실제 구현 (URLSession, Firebase 등)
        },
        createItem: { item in
            // 실제 구현
        },
        deleteItem: { id in
            // 실제 구현
        }
    )
}

extension APIClient: TestDependencyKey {
    public static let testValue = Self()

    public static let previewValue = Self(
        fetchItems: { Item.mocks },
        createItem: { _ in "preview-id" },
        deleteItem: { _ in }
    )
}

extension DependencyValues {
    public var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
```

## 📦 모듈 구조

### 새 Feature 생성 시
```bash
# 1. Tuist를 통한 자동 생성 (권장)
make feature FEATURE_NAME=NewFeature

# 2. 수동 생성 시 체크리스트
- [ ] Project.swift 생성
- [ ] Sources/ 폴더에 Reducer + View 생성 (Namespace 패턴 사용)
- [ ] ExportedImports.swift 생성
- [ ] Tests/ 폴더에 테스트 작성
- [ ] 필요한 Client 의존성 추가
- [ ] Shared Models import
- [ ] Preview 코드 작성
```

### 타겟 분리 기준
```
Small Feature (파일 <10개)
→ 단일 타겟

Medium Feature (파일 10-30개)
→ Interface 타겟 분리 고려
   (다른 Feature가 참조할 경우)

Large Feature (파일 >30개)
→ Subfeature별 타겟 분리
```

## 🎨 UI/UX 가이드

### SwiftUI 스타일
```swift
// ✅ 선호하는 패턴
// 1. ViewBuilder 사용
@ViewBuilder
private var headerSection: some View {
    VStack {
        // 헤더 내용
    }
}

// 2. Preview 필수
#Preview {
    MyFeature.RootView(
        store: Store(initialState: MyFeature.Feature.State()) {
            MyFeature.Feature()
        }
    )
}

// 3. 공통 컴포넌트는 Shared/DesignSystem에
// Shared/DesignSystem/Components/CustomButton.swift
public struct CustomButton: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding()
        }
    }
}

// ❌ 지양하는 패턴
// - 200줄 넘는 단일 View
// - GeometryReader 남용
// - .onAppear에서 복잡한 로직 (Reducer로 이동)
```

### 디자인 시스템
```swift
// Shared/DesignSystem/Styles/에 정의
extension Color {
    static let primaryBackground = Color(hex: "1A1A2E")
    static let secondaryBackground = Color(hex: "16213E")
    static let accentColor = Color(hex: "0F3460")
}

extension Font {
    static let title = Font.system(size: 28, weight: .bold)
    static let headline = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
}
```

## 🧪 테스트 작성 규칙

**프레임워크**: Swift Testing (`import Testing`)

```swift
import ComposableArchitecture
import Testing
@testable import MyFeature

@Suite("MyFeature Tests")
@MainActor
struct MyFeatureTests {

    @Test("사용자 액션 처리")
    func testUserAction() async {
        let store = TestStore(initialState: MyFeature.Feature.State()) {
            MyFeature.Feature()
        } withDependencies: {
            // Mock 의존성 주입
            $0.apiClient.fetchItems = { [.mock1, .mock2] }
            $0.date.now = Date(timeIntervalSince1970: 1234567890)
        }

        store.exhaustivity = .off  // 필요시 사용

        // When
        await store.send(.view(.onAppear))

        // Then
        await store.receive(\.internal.dataResponse.success)

        // 최종 상태 검증 (필요시)
        #expect(store.state.items.count == 2)
    }

    @Test("confirmation을 사용한 비동기 검증")
    func testAsyncAction() async {
        await confirmation("API called", expectedCount: 1) { @Sendable confirm in
            let store = Store(initialState: MyFeature.Feature.State()) {
                MyFeature.Feature()
            } withDependencies: {
                $0.apiClient.fetchItems = {
                    confirm()
                    return [.mock1, .mock2]
                }
            }

            await store.send(.view(.onAppear))
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

// Mock 데이터는 Model+Mock.swift에 정의
extension Item {
    static let mock1 = Item(id: "1", name: "Test Item 1")
    static let mock2 = Item(id: "2", name: "Test Item 2")
    static let mocks = [mock1, mock2]
}
```

## 🔥 Firebase 규칙

### Firestore 구조
```
collections/
├── users/{userId}
│   ├── name: String
│   ├── email: String
│   └── createdAt: Timestamp
│
├── groups/{groupId}
│   ├── name: String
│   ├── members: [String] (userIds)
│   └── createdAt: Timestamp
│
└── promises/{promiseId}
    ├── title: String
    ├── date: Timestamp
    ├── groupId: String
    ├── participants: [String] (userIds)
    ├── acceptedBy: [String] (userIds)
    └── status: String (pending, confirmed, completed)
```

### FirebaseClient 패턴
```swift
@DependencyClient
public struct FirebaseClient {
    // Create
    public var createPromise: @Sendable (Promise) async throws -> String

    // Read
    public var fetchPromise: @Sendable (String) async throws -> Promise
    public var fetchPromises: @Sendable (String) async throws -> [Promise]

    // Update
    public var updatePromise: @Sendable (String, Promise) async throws -> Void

    // Delete
    public var deletePromise: @Sendable (String) async throws -> Void

    // Real-time
    public var observePromises: @Sendable (String) -> AsyncStream<[Promise]>
}

// Live 구현
extension FirebaseClient: DependencyKey {
    public static let liveValue = Self(
        createPromise: { promise in
            let db = Firestore.firestore()
            let docRef = db.collection("promises").document()

            try await docRef.setData([
                "title": promise.title,
                "date": Timestamp(date: promise.date),
                "groupId": promise.groupId,
                "participants": promise.participants,
                "acceptedBy": [],
                "status": "pending"
            ])

            return docRef.documentID
        },
        // ... 나머지 구현
    )
}
```

## 📝 문서화 규칙

### 코드 주석
```swift
// ✅ 필요한 주석
// 복잡한 비즈니스 로직
/// 약속이 "확정"되려면 모든 참가자가 수락해야 함
func isPromiseConfirmed(promise: Promise) -> Bool {
    Set(promise.acceptedBy) == Set(promise.participants)
}

// 비직관적인 코드
/// Firebase Timestamp는 밀리초 단위이므로 변환 필요
let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))

// ❌ 불필요한 주석
// 변수를 생성한다
let name = "John"

// 버튼을 눌렀을 때 동작
case .buttonTapped:
```

### README 필수 항목

각 모듈의 README.md에 포함:
- 모듈 목적 (1줄)
- 의존성 목록
- 주요 타입/함수 (간단한 예시)
- 사용 예시 코드

## 🚨 일반적인 실수와 해결법

### 1. State 직접 수정
```swift
// ❌ 잘못된 방법
case .updateName:
    state.user.name = "New Name"  // 직접 수정
    return .send(.save)

// ✅ 올바른 방법
case .updateName:
    var updatedUser = state.user
    updatedUser.name = "New Name"
    state.user = updatedUser
    return .send(.save)
```

### 2. 순환 참조
```swift
// ❌ Feature A → Feature B → Feature A
// ✅ Interface 패턴 사용
//    Feature A → Feature B Interface
//    Feature B → Feature B Interface
```

### 3. 비동기 작업 취소 없음
```swift
// ❌ 취소 불가
return .run { send in
    try await apiClient.fetchData()
}

// ✅ 취소 가능
return .run { send in
    try await apiClient.fetchData()
}
.cancellable(id: CancelID.fetchData)

// 필요시 취소
return .cancel(id: CancelID.fetchData)
```

### 4. Action 계층화 누락
```swift
// ❌ Flat 구조
enum Action {
    case onAppear
    case dataLoaded([Item])
    case itemTapped(Item.ID)
}

// ✅ 계층화 구조
enum Action {
    case view(ViewAction)
    case `internal`(InternalAction)
    case delegate(DelegateAction)
}

enum ViewAction: Sendable {
    case onAppear
    case itemTapped(Item.ID)
}

enum InternalAction: Sendable {
    case dataLoaded([Item])
}

enum DelegateAction: Equatable { }
```

## 🎓 학습 자료

- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)
- [Point-Free Episodes](https://www.pointfree.co)
- [프로젝트 아키텍처 문서](./docs/architecture.md)

## 🤖 AI 도구 사용 시 프롬프트 템플릿

### 새 Feature 생성
```
SwiftUI와 TCA를 사용해서 [기능명] Feature를 만들어줘.

요구사항:
- Namespace 패턴 사용 (public enum FeatureName {})
- [구체적인 기능 설명]
- [필요한 Client] 의존성 사용
- @ObservableState 사용
- Action 계층화 (view/internal/delegate)
- async/await 기반 비동기 처리
- 에러 핸들링 포함
- Swift Testing 프레임워크 사용
- Preview 코드 포함

참고할 기존 Feature: [유사한 Feature명]
```

### Client 생성
```
[Client명]을 TCA Dependency로 만들어줘.

인터페이스:
- [함수1]: [파라미터] -> [리턴 타입]
- [함수2]: [파라미터] -> [리턴 타입]

구현:
- [구현 방법 - Firebase/URLSession/등]
- testValue와 previewValue 포함
- DependencyKey와 TestDependencyKey 모두 구현
```

### 리팩토링
```
이 코드를 TCA 베스트 프랙티스에 맞게 리팩토링해줘:

[코드 붙여넣기]

개선 포인트:
- Namespace 패턴 적용
- Action 계층화 (view/internal/delegate)
- Delegate 패턴 추가
- 에러 핸들링 개선
- Swift Testing으로 테스트 가능하도록 구조 변경
```

---

**마지막 업데이트**: 2024-12-29
**프로젝트 버전**: 1.0.0
