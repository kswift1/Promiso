# 아키텍처 가이드

Promiso는 **The Composable Architecture (TCA)** 기반의 모듈형 iOS 애플리케이션입니다.

## 📋 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [계층 구조](#계층-구조)
3. [모듈 설명](#모듈-설명)
4. [TCA 패턴](#tca-패턴)
5. [의존성 규칙](#의존성-규칙)
6. [데이터 흐름](#데이터-흐름)

---

## 아키텍처 개요

### 핵심 원칙

1. **단방향 데이터 흐름**: TCA의 Reducer를 통한 상태 관리
2. **모듈화**: 각 기능을 독립적인 Feature 모듈로 분리
3. **의존성 역전**: TCA Dependency를 통한 외부 의존성 추상화
4. **테스트 용이성**: Mock Dependency를 통한 단위 테스트 지원

### 기술 스택

| 레이어 | 기술 |
|--------|------|
| **아키텍처** | TCA 1.22.2 |
| **UI** | SwiftUI (iOS 18+) |
| **백엔드** | Firebase (Auth, Firestore, Functions, Storage) |
| **빌드 시스템** | Tuist 4.65.7 |
| **테스트** | Swift Testing |
| **배포** | Fastlane, GitHub Actions |

---

## 계층 구조

```
┌────────────────────────────────────┐
│          App Layer                 │
│      (앱 조립 및 통합)              │
│                                    │
│  - AppMain.swift                   │
│  - LiveDependencies.swift          │
│  - AppDelegate.swift               │
└─────────────────┬──────────────────┘
                  ↓
┌────────────────────────────────────┐
│       Features Layer               │
│    (TCA Reducers & Views)          │
│                                    │
│  - AppEntryFeature                 │
│  - RootTabFeature                  │
│  - HomeFeature                     │
│  - GroupFeature                    │
│  - PromiseFeature                  │
│  - AuthFeature                     │
│  - SettingsFeature                 │
└─────────────────┬──────────────────┘
                  ↓
┌────────────────────────────────────┐
│        Clients Layer               │
│      (TCA Dependencies)            │
│                                    │
│  - AuthClient                      │
│  - GroupClient                     │
│  - PromiseClient                   │
│  - UserProfileClient               │
│  - NotificationClient              │
│  - Infrastructure                  │
│    - FirebaseClient                │
│    - DataSources                   │
└─────────────────┬──────────────────┘
                  ↓
┌────────────────────────────────────┐
│         Shared Layer               │
│       (공통 요소)                   │
│                                    │
│  - Models                          │
│  - DesignSystem                    │
│  - UI Components                   │
│  - Extensions                      │
│  - Constants                       │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    ExternalDependency              │
│    (외부 라이브러리 집약)           │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│        ResourceKit                 │
│       (리소스 관리)                 │
└────────────────────────────────────┘
```

### 의존성 방향

```
App → Features → Clients → Shared
         ↓           ↓
   ExternalDependency
         ↓
   ResourceKit
```

**규칙**:
- 화살표 방향으로만 의존 가능
- Features끼리는 서로 의존하지 않음
- 상위 레이어가 하위 레이어를 의존

---

## 모듈 설명

### App Layer

**역할**: 앱 진입점 및 Feature 조립

**주요 파일**:
```swift
// AppMain.swift - 앱 진입점
@main
struct PromisoApp: App {
    var body: some Scene {
        WindowGroup {
            AppEntryView(
                store: Store(initialState: AppEntryFeature.State()) {
                    AppEntryFeature()
                }
            )
        }
    }
}

// LiveDependencies.swift - Production 의존성 주입
extension DependencyValues {
    static let live = Self(
        authClient: .liveValue,
        groupClient: .liveValue,
        promiseClient: .liveValue
    )
}
```

### Features Layer

**역할**: 비즈니스 로직 및 화면 구성

**Feature 구조**:
```
GroupFeature/
├── Sources/
│   ├── GroupFeature.swift        # TCA Reducer
│   ├── GroupView.swift            # SwiftUI View
│   └── Components/                # View Components
│       ├── GroupCard.swift
│       └── MemberRow.swift
└── Tests/
    └── GroupFeatureTests.swift    # 단위 테스트
```

**Feature 예시**:
```swift
@Reducer
public struct GroupFeature {
    @ObservableState
    public struct State: Equatable {
        var groups: [Group] = []
        var isLoading = false
        var selectedGroup: Group?
    }

    public enum Action {
        case onAppear
        case groupsResponse([Group])
        case selectGroup(Group)

        // Delegate Actions (부모 Feature에 전달)
        case delegate(Delegate)

        public enum Delegate {
            case groupSelected(Group)
        }
    }

    @Dependency(\.groupClient) var groupClient

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let groups = try await groupClient.fetchGroups()
                    await send(.groupsResponse(groups))
                }

            case let .groupsResponse(groups):
                state.isLoading = false
                state.groups = groups
                return .none

            case let .selectGroup(group):
                state.selectedGroup = group
                return .send(.delegate(.groupSelected(group)))

            case .delegate:
                return .none
            }
        }
    }
}
```

### Clients Layer

**역할**: 외부 의존성 추상화

**Client 구조**:
```
GroupClient/
├── Sources/
│   ├── GroupClient.swift          # Client Interface
│   └── Implementations/
│       └── GroupRemoteDataSource.swift
└── Tests/
    └── GroupClientTests.swift
```

**Client 예시**:
```swift
// GroupClient.swift - 인터페이스
@DependencyClient
public struct GroupClient {
    public var fetchGroups: @Sendable () async throws -> [Group]
    public var createGroup: @Sendable (String) async throws -> Group
    public var deleteGroup: @Sendable (String) async throws -> Void
}

extension GroupClient: DependencyKey {
    public static let liveValue: GroupClient = {
        let dataSource = GroupRemoteDataSource()
        return Self(
            fetchGroups: dataSource.fetchGroups,
            createGroup: dataSource.createGroup,
            deleteGroup: dataSource.deleteGroup
        )
    }()

    public static let testValue: GroupClient = {
        Self()
    }()
}

extension DependencyValues {
    public var groupClient: GroupClient {
        get { self[GroupClient.self] }
        set { self[GroupClient.self] = newValue }
    }
}

// GroupRemoteDataSource.swift - 실제 구현
public actor GroupRemoteDataSource {
    @Dependency(\.firestore) var firestore

    public func fetchGroups() async throws -> [Group] {
        let snapshot = try await firestore
            .collection("groups")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Group.self)
        }
    }
}
```

### Shared Layer

**역할**: 공통 모델, UI 컴포넌트, 유틸리티

**구조**:
```
Shared/
├── Models/              # 데이터 모델
│   ├── Group.swift
│   ├── Promise.swift
│   └── User.swift
├── DesignSystem/        # 디자인 시스템
│   ├── Colors.swift
│   ├── Typography.swift
│   └── Spacing.swift
├── UI/                  # 공통 UI 컴포넌트
│   ├── Buttons/
│   ├── Cards/
│   └── Modifiers/
└── Extensions/          # Swift/SwiftUI 확장
    ├── Date+Extensions.swift
    └── View+Extensions.swift
```

**예시**:
```swift
// Models/Group.swift
public struct Group: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let memberIds: [String]
    public let createdAt: Date
}

// DesignSystem/Colors.swift
extension Color {
    public static let pmIndigo = Color.pmindigo.n500
    public static let pmAurora = Color.pmaurora.purple
}
```

### ExternalDependency

**역할**: 외부 라이브러리를 단일 모듈로 집약

**포함 라이브러리**:
```swift
// ExternalDependency.swift
@_exported import ComposableArchitecture
@_exported import FirebaseAuth
@_exported import FirebaseFirestore
@_exported import FirebaseStorage
@_exported import KakaoSDKAuth
@_exported import GoogleSignIn
```

**장점**:
- 다른 모듈에서 개별 라이브러리 의존 불필요
- 버전 업그레이드 시 단일 지점에서 관리
- 빌드 시간 단축

### ResourceKit

**역할**: 리소스 파일 및 생성 코드 관리

**구조**:
```
ResourceKit/
├── Resources/
│   ├── Animations/      # Lottie JSON
│   ├── Fonts/           # Custom Fonts
│   └── Colors/          # Color Assets
└── Sources/
    └── Generated/       # 자동 생성 코드
        ├── Assets.swift
        └── Colors.swift
```

---

## TCA 패턴

### State 관리

```swift
@ObservableState
public struct State: Equatable {
    // 화면에 표시될 데이터
    var items: [Item] = []

    // 로딩 상태
    var isLoading = false

    // 에러 상태
    var error: AppError?

    // 하위 Feature State (Composition)
    var detail: DetailFeature.State?
}
```

### Action 분리

```swift
public enum Action {
    // View에서 발생하는 액션
    case viewAction(ViewAction)

    // 내부 로직 액션
    case internalAction(InternalAction)

    // 부모에게 전달할 액션
    case delegate(DelegateAction)

    public enum ViewAction {
        case onAppear
        case itemTapped(Item)
    }

    public enum InternalAction {
        case itemsResponse([Item])
        case errorOccurred(AppError)
    }

    public enum DelegateAction {
        case itemSelected(Item)
    }
}
```

### Reducer Composition

```swift
@Reducer
public struct ParentFeature {
    public struct State {
        var child1: Child1Feature.State
        var child2: Child2Feature.State
    }

    public enum Action {
        case child1(Child1Feature.Action)
        case child2(Child2Feature.Action)
    }

    public var body: some ReducerOf<Self> {
        // Child Reducers
        Scope(state: \.child1, action: \.child1) {
            Child1Feature()
        }
        Scope(state: \.child2, action: \.child2) {
            Child2Feature()
        }

        // Parent Reducer
        Reduce { state, action in
            switch action {
            case .child1(.delegate(.completed)):
                // Child1 완료 시 Child2 갱신
                return .send(.child2(.refresh))

            default:
                return .none
            }
        }
    }
}
```

---

## 의존성 규칙

### 허용되는 의존성

```
✅ App → Features
✅ App → Clients
✅ Features → Clients
✅ Features → Shared
✅ Features → ExternalDependency
✅ Features → ResourceKit
✅ Clients → Shared
✅ Clients → ExternalDependency
```

### 금지되는 의존성

```
❌ Features → Features (Feature 간 직접 의존)
❌ Clients → Features
❌ Shared → Features
❌ Shared → Clients
❌ Shared → ExternalDependency (제한적 허용)
```

### Feature 간 통신

Features끼리 직접 의존하지 않고 **부모 Feature에서 조율**:

```swift
// ❌ 잘못된 예: Feature A가 Feature B를 직접 의존
@Dependency(\.featureBClient) var featureBClient  // 없음!

// ✅ 올바른 예: 부모 Feature에서 조율
@Reducer
public struct ParentFeature {
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .featureA(.delegate(.dataChanged)):
                return .send(.featureB(.refresh))
            default:
                return .none
            }
        }
    }
}
```

---

## 데이터 흐름

### 데이터 읽기 (Query)

```
User Interaction
    ↓
View Action
    ↓
Reducer (Effect 실행)
    ↓
Client (비즈니스 로직)
    ↓
DataSource (Firebase/API)
    ↓
Response → Reducer
    ↓
State 업데이트
    ↓
View 자동 갱신
```

### 데이터 쓰기 (Command)

```
User Input
    ↓
View Action (.save)
    ↓
Reducer Validation
    ↓
Client (쓰기 로직)
    ↓
DataSource (Firebase/API)
    ↓
Success/Error → Reducer
    ↓
State 업데이트 (저장 완료 표시)
    ↓
View 업데이트
```

### 예시: 그룹 생성 플로우

```swift
// 1. View: 사용자 버튼 클릭
Button("그룹 생성") {
    store.send(.createButtonTapped)
}

// 2. Reducer: Effect 실행
case .createButtonTapped:
    state.isLoading = true
    return .run { [name = state.groupName] send in
        do {
            let group = try await groupClient.createGroup(name)
            await send(.groupCreated(group))
        } catch {
            await send(.errorOccurred(error))
        }
    }

// 3. Client: 비즈니스 로직
public func createGroup(_ name: String) async throws -> Group {
    let group = Group(
        id: UUID().uuidString,
        name: name,
        memberIds: [currentUserId],
        createdAt: Date()
    )
    try await dataSource.create(group)
    return group
}

// 4. DataSource: Firebase 저장
public func create(_ group: Group) async throws {
    try await firestore
        .collection("groups")
        .document(group.id)
        .setData(from: group)
}

// 5. Reducer: 성공 처리
case let .groupCreated(group):
    state.isLoading = false
    state.groups.append(group)
    return .send(.delegate(.groupCreated(group)))
```

---

## 베스트 프랙티스

### ✅ DO

- Feature는 단일 책임 원칙 준수
- State는 Equatable 구현
- Client는 @Sendable 준수
- 테스트에서 TestStore 사용
- Dependency Injection 활용

### ❌ DON'T

- Feature에서 Firebase 직접 호출
- Features 간 직접 의존
- State에 non-Equatable 타입 포함
- 전역 변수 사용
- Singleton 남용

---

## 참고 자료

- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)
- [Tuist 공식 문서](https://docs.tuist.io/)
- [.ai/PROJECT_CONTEXT.md](../.ai/PROJECT_CONTEXT.md) - 상세 컨벤션
- [.claude/CLAUDE.md](../.claude/CLAUDE.md) - AI 개발 가이드
