# 프로젝트 컨텍스트 (AI Assistant를 위한 가이드)

> 이 문서는 Claude Code, Codex, GitHub Copilot 등 AI 도구가 프로젝트를 이해하고 일관된 코드를 생성하도록 돕습니다.

## 🎯 작업 원칙

1. **아키텍처 준수**: App → Features → Clients → Shared (단방향 의존성)
2. **변경 최소화**: 필요한 범위로 제한하고, 기존 모듈 구조/Tuist 구성 존중
3. **언어**: 문서 작성 및 사용자 답변은 한국어 우선 (기술 용어/코드는 원문 유지)
4. **일관성**: 기존 코드 패턴과 컨벤션 준수

## 📋 프로젝트 개요

**프로젝트명**: Promiso
**설명**: 그룹 기반 약속 관리 iOS 애플리케이션
**플랫폼**: iOS 18.0+
**주요 기술**: SwiftUI, TCA (1.22.2), Firebase, Tuist (4.65.7)
**백엔드**: Firebase Functions (Node.js), Firestore, Storage

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

### 🔴 Critical (즉시 수정 필수)

| 항목 | 규칙 |
|-----|-----|
| 강제 언래핑 (!) | ❌ 금지 → `guard let` 사용 |
| @BindingState | ❌ 금지 → `@ObservableState` 사용 |
| .task { } | ❌ 금지 → `Effect.run { }` 사용 |
| .fireAndForget { } | ❌ 금지 → `Effect.run { }` 사용 |
| 하드코딩 색상 | ❌ 금지 → `Color.pm*` 사용 (아래 색상 시스템 참조) |
| Feature에서 Firebase 직접 호출 | ❌ 금지 → Client 레이어 통과 필수 |
| Glass Effect Fallback 누락 | ❌ 금지 → `#available(iOS 26)` 분기 필수 |
| XCTest 사용 | ❌ 금지 → Swift Testing 사용 |
| Button/탭 영역 Spacer 포함 시 | `.contentShape(Rectangle())` 필수 |

### 🟡 Warning (권장 수정)

| 항목 | 규칙 |
|-----|-----|
| 축약 네이밍 (btn, lbl) | 전체 단어 사용 권장 |
| print() 문 | 제거 권장 |
| SwiftUI Preview 누락 | 추가 권장 |
| 500라인 이상 파일 | 파일 분리 권장 |
| Aurora Background 누락 | 주요 화면에 적용 권장 |

### ℹ️ Info (허용)

| 항목 | 규칙 |
|-----|-----|
| TODO/FIXME 주석 | 허용 (정보 표시만) |

### Swift 스타일
```swift
// ✅ 필수 사항
- 들여쓰기: 2 spaces
- 네이밍: camelCase (변수, 함수), PascalCase (타입)
- async/await 사용 (completion handler 지양)
- SwiftUI Preview 권장
- @ObservableState 사용 (TCA 1.22.2)
- Action 하위 enum에 Sendable 프로토콜 준수 (Swift 6 Concurrency 대비)

// ❌ 금지 사항
- 강제 언래핑 (!) → guard let 사용
- @BindingState → @ObservableState 사용
- .task { } → Effect.run { } 사용
- 과도한 축약 (btn, lbl 등)
- 하드코딩 색상 → Color.pm* 사용
```

## 📝 Git 커밋 메시지 컨벤션

### 포맷
```
<type>: <subject>    ← 한글, 50자 이내

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

### Type 규칙 (소문자)
- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 리팩터링 (기능 변경 없음)
- `test`: 테스트 추가/수정
- `docs`: 문서 변경
- `chore`: 빌드/설정 변경
- `style`: 코드 포맷팅 (로직 변경 없음)

### Subject 규칙
- 50자 이내
- 명령형 (동사원형): "추가한다" ❌ → "추가" ✅
- 마침표 없음
- **한글 사용** (코드/기술용어는 영어)

### 예시
```
✅ 올바른 예시:
feat: 알림 설정 Feature 추가
fix: 그룹 목록 중복 렌더링 버그 수정
refactor: FirestoreClient 쿼리 로직 개선

❌ 잘못된 예시:
Add notification settings feature (영어 금지)
feat: 알림 설정 기능을 추가했습니다 (명령형 아님)
알림 설정 추가 (type 없음)
```

---

## 🧰 빌드/환경 규칙

### iOS 빌드
- Tuist 기반으로 프로젝트 생성/빌드
- 기본 커맨드
  - `tuist install`
  - `tuist generate`
  - `tuist build`

### Firebase Functions 배포
- 기본 커맨드: `firebase deploy --only functions`
- 경고(lint warnings)는 허용되나 에러는 반드시 해결
- 배포 전에 `npm --prefix infra/firebase/functions run build` 통과 확인

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

### 상태/바인딩 규칙
- `State`는 도메인 상태와 뷰 전용 상태를 구분해 배치
- 입력 폼은 `BindingReducer` 사용을 우선 고려
- 뷰에서 직접 변형하지 말고 `ViewAction`을 통해 상태 변경

### 에러/로깅 규칙
- 사용자 표시용 메시지와 내부 로깅 메시지를 분리
- 비동기 실패는 `InternalAction`으로 수렴시키고 상태에 저장
- 로깅은 Client/Reducer 레벨에서 최소화하고, UI에서 직접 로깅하지 않음

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

### 색상 시스템 (필수)

**위치**: `Projects/ResourceKit/Sources/Generated/Color+Generated.swift`

```swift
// ✅ 올바른 사용 - Color.pm* 필수
Color.pmindigo.n500       // Indigo 스케일 (n50 ~ n900)
Color.pmaurora.purple     // Aurora 색상
Color.pmaurora.indigo
Color.pmaurora.pink
Color.pmbrand.primary     // 브랜드 색상
Color.pmbrand.secondary
Color.pmpurple.n500       // Purple 스케일

// ❌ 금지 - 하드코딩 색상
Color(red: 0.5, green: 0.3, blue: 0.8)
Color(UIColor.systemBlue)
Color(hex: "1A1A2E")
```

### Glass Effect + Fallback (필수)

```swift
// iOS 26+ Glass Effect 사용 시 반드시 Fallback 포함
if #available(iOS 26.0, *) {
    content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
    content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}

// ⚠️ Button/탭 영역 - 빈 공간도 탭 가능하게
Button {
    // action
} label: {
    HStack {
        Text("Label")
        Spacer()  // ← 이 부분도 탭 가능하게
    }
    .contentShape(Rectangle())  // ← 필수!
}
```

### Aurora Background (주요 화면 권장)

```swift
// 로그인, 메인 탭, 모달 등 주요 화면에 적용
var body: some View {
    ScrollView {
        // 콘텐츠
    }
    .auroraBackground()
}
```

### 폰트
```swift
extension Font {
    static let title = Font.system(size: 28, weight: .bold)
    static let headline = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
}
```

### 리소스/이미지 규칙
- 색상/폰트/아이콘은 `ResourceKit` 사용
- 공용 UI는 `Shared` 컴포넌트 우선 사용
- 이미지 로딩은 Shared 공용 이미지 뷰 또는 Nuke 사용

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

### 테스트 기본 규칙
- 의미 없는 기본 테스트는 주석 처리 또는 삭제
- 문서(.ai 가이드)와 테스트는 중요한 흐름에서 정합 유지

## 🔥 Firebase 규칙

### Firestore 구조
- 실제 스키마는 `.ai/FIRESTORE_SCHEMA.md`를 기준으로 한다.
- 변경 시 OpenAPI(`infra/firebase/functions/openapi.yaml`)와 함께 갱신.

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

## 📚 문서/정합 규칙

### 문서 정합 우선순위
1. 코드 동작 (최우선)
2. OpenAPI (`infra/firebase/functions/openapi.yaml`)
3. `.ai` 가이드 문서 (`.ai/FIRESTORE_SCHEMA.md`, `.ai/PUSH_NOTIFICATION_GUIDE.md`, `.ai/DEEPLINK_GUIDE.md`)

### 정합 체크리스트
- API 스키마/예시 변경 시 OpenAPI 반영
- Firestore 문서 변경 시 `.ai/FIRESTORE_SCHEMA.md` 반영
- 푸시/딥링크 변경 시 해당 가이드 업데이트

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

### 네이밍/폴더 규칙
- Feature 이름과 폴더명/타겟명 일치
- `Feature`/`RootView`/`Tests` 파일 네이밍 일관성 유지

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

## 🔍 자동 검사 명령어

### Critical 검사
```bash
# TCA Deprecated API
grep -rn "@BindingState\|\.task\s*{\|\.fireAndForget" --include="*.swift" .

# 하드코딩 색상
grep -rn "Color(red:\|Color(UIColor" --include="*.swift" .

# Glass Effect Fallback 누락
grep -l "\.glassEffect" --include="*.swift" . | xargs grep -L "#available(iOS 26"

# Button contentShape 누락
grep -l "Spacer()" --include="*.swift" . | xargs grep -L "contentShape"
```

### Warning 검사
```bash
# 강제 언래핑
grep -rn "!" --include="*.swift" . | grep -v "!="

# 축약 네이밍
grep -rn "\(btn\|lbl\|txt\|img\)" --include="*.swift" .

# print 문
grep -rn "print(" --include="*.swift" .
```

---

## 🤖 AI 도구 사용

AI 도구(Claude Code, GitHub Copilot 등)를 사용할 때는 **[PROMPTS.md](.ai/archive/PROMPTS.md)**를 참고하세요.

프롬프트 템플릿, 사용 예시, 베스트 프랙티스가 포함되어 있습니다.

---

**마지막 업데이트**: 2025-01-27
**프로젝트 버전**: 1.0.0
