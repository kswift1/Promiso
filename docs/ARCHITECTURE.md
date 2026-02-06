# 아키텍처 가이드

Promiso는 **The Composable Architecture (TCA)** 기반의 모듈형 iOS 애플리케이션입니다.

## 문서 메타

- 목적: 모듈 구조와 의존성 규칙, 데이터 흐름의 기준 제공
- 대상 독자: iOS 개발자, 아키텍처 변경 작업자
- 최종 수정일: 2026-02-06
- 관련 문서: [README.md](README.md) · [DEVELOPMENT.md](DEVELOPMENT.md)

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
│       (앱 조립 및 통합)               │
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
│        (공통 요소)                   │
│                                    │
│  - Models                          │
│  - DesignSystem                    │
│  - UI Components                   │
│  - Extensions                      │
│  - Constants                       │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    ExternalDependency              │
│        (외부 라이브러리 집약)           │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│        ResourceKit                 │
│         (리소스 관리)                 │
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

**Feature 구조 (Namespace 패턴)**:
```
GroupFeature/
├── Sources/
│   ├── GroupFeature.swift         # Namespace + Reducer + View
│   ├── ExportedImports.swift      # 재수출 의존성
│   └── Components/                 # View Components (선택)
│       ├── GroupCard.swift
│       └── MemberRow.swift
└── Tests/
    └── GroupFeatureTests.swift    # 단위 테스트
```

**Namespace 패턴**:

모든 Feature는 `enum` Namespace를 사용해 구조화합니다:

```swift
// 구조
public enum GroupFeature {}

extension GroupFeature {
    @Reducer
    public struct Feature {
        // State, Action, Dependencies, Reducer 구현
    }
}

extension GroupFeature {
    public struct RootView: View {
        // SwiftUI View 구현
    }
}
```

**구성 요소**:
- **State**: `@ObservableState`로 표시된 상태 구조체
- **Action**: View/Internal/Delegate로 계층화된 액션
- **Dependencies**: `@Dependency`로 주입된 외부 의존성
- **Reducer**: `body` 내에서 상태 변경 로직 구현

> 📘 **상세 예시**: [DEVELOPMENT.md - Feature 개발 가이드](DEVELOPMENT.md#22-tca-feature-구조)

**Feature 계층 구조**:

```
AppEntryFeature (Root Coordinator)
├── AuthFeature
├── ProfileSetupFeature
└── RootTabFeature (Tab Coordinator)
    ├── HomeFeature
    ├── GroupFeature
    ├── PromiseFeature
    └── SettingsFeature
```

**계층 규칙**:
- **Coordinator Feature**: 네비게이션/화면 전환 담당 (자식 Feature 의존 가능)
- **Leaf Feature**: 실제 비즈니스 로직 담당 (서로 의존 불가)
- Feature 간 통신은 **Delegate 패턴**으로만

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

**Client 구조**:

```swift
@DependencyClient
public struct GroupClient {
    // 메서드 시그니처 정의 (@Sendable 필수)
    public var fetchGroups: @Sendable () async throws -> [Group]
    public var createGroup: @Sendable (String) async throws -> Group
}

extension GroupClient: DependencyKey {
    // Live: 실제 구현 (Firebase/API)
    public static let liveValue = Self(...)

    // Test: 테스트용 Mock
    public static let testValue = Self()

    // Preview: SwiftUI Preview용
    public static let previewValue = Self(...)
}

extension DependencyValues {
    // Feature에서 사용할 수 있도록 등록
    public var groupClient: GroupClient { ... }
}
```

**역할**:
- Feature와 외부 시스템(Firebase, API) 사이의 추상화 레이어
- 테스트 가능하도록 Mock 제공
- `@Sendable` 프로토콜 준수로 Thread-safe 보장

> 📘 **상세 예시**: [DEVELOPMENT.md - 의존성 주입](DEVELOPMENT.md#24-의존성-주입)

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
    @Presents var detail: DetailFeature.Feature.State?
}
```

### Action 계층화 (필수)

모든 Feature는 Action을 3가지 계층으로 분리합니다:

```swift
public enum Action {
    case view(ViewAction)              // 사용자 인터랙션
    case `internal`(InternalAction)    // 내부 상태 변경 & 비동기 응답
    case delegate(DelegateAction)      // 부모 Feature와 통신
}
```

**계층별 역할**:

| 계층 | 역할 | 프로토콜 | 예시 |
|------|------|---------|------|
| **ViewAction** | 사용자 이벤트 처리 | `Sendable` | onAppear, buttonTapped |
| **InternalAction** | 내부 로직 & 비동기 응답 | `Sendable` | dataResponse, timerTicked |
| **DelegateAction** | 부모에게 이벤트 전달 | `Equatable` | itemSelected, completed |

**흐름**:
```
User Input → ViewAction → Effect 실행 → InternalAction → State 변경 → DelegateAction (선택)
```

> 📘 **상세 예시**: [DEVELOPMENT.md - Action 계층 구조](DEVELOPMENT.md#227-action-계층-구조-필수)

### Reducer Composition

**Parent-Child 구조**:

Parent Feature는 자식 Feature들을 조합하고 조율합니다:

```swift
public var body: some ReducerOf<Self> {
    // 1. Child Reducers 통합
    Scope(state: \.child1, action: \.child1) {
        Child1.Feature()
    }

    // 2. Parent Reducer - 자식 간 조율
    Reduce { state, action in
        // Child Delegate 처리
        // Child 간 통신 중계
    }

    // 3. Destination Reducer (선택)
    .ifLet(\.$destination, action: \.destination)
}
```

**Navigation 패턴**:

| 패턴 | 용도 | 사용법 |
|------|------|--------|
| **@Presents** | 모달/시트/팝오버 | `@Presents var destination: Feature.State?` |
| **Destination** | 여러 화면 중 하나 | `@Reducer enum Destination { ... }` |
| **Scope** | 자식 Reducer 통합 | `Scope(state: \.child, action: \.child) { }` |

> 📘 **상세 예시**: [DEVELOPMENT.md - Feature 간 통신](DEVELOPMENT.md#25-feature-간-통신-delegate-패턴)

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

**기본 원칙**:
- ❌ Sibling Features 간 직접 의존 금지 (HomeFeature ↔ GroupFeature)
- ✅ Parent-Child 계층 구조만 허용 (AppEntryFeature → AuthFeature)
- ✅ 모든 통신은 Delegate 패턴으로

**통신 흐름**:

```
Child Feature A → Delegate Action → Parent Feature → Child Feature B
```

**통신 예시**:

```swift
// Parent Reducer에서 자식 간 조율
Reduce { state, action in
    switch action {
    // Child A의 Delegate → Child B로 전달
    case .childA(.delegate(.dataChanged(let data))):
        return .send(.childB(.view(.update(data))))

    // Child B의 Delegate → Child A로 전달
    case .childB(.delegate(.completed)):
        return .send(.childA(.view(.refresh)))

    default:
        return .none
    }
}
```

**원칙**:
1. Child Feature는 Delegate로만 상위에 이벤트 전달
2. Parent Feature가 Delegate를 받아서 다른 Child에게 액션 전송
3. Child끼리 직접 통신 절대 금지

**❌ 하지 말아야 할 것**:

```swift
// Feature A에서 Feature B 직접 호출 (불가능)
@Dependency(\.featureBClient) var featureBClient  // 이런 건 없음!

// Features 간 직접 import
import GroupFeature  // Sibling Feature import 금지
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

### 예시: 데이터 생성 플로우

```
1. View
   User Tap → store.send(.view(.createButtonTapped))

2. Reducer (ViewAction 처리)
   state.isLoading = true
   return .run { send in
       await send(.internal(.createResponse(...)))
   }

3. Client
   비즈니스 로직 실행 (Validation, Firebase 저장 등)

4. Reducer (InternalAction 처리)
   case .success: state에 데이터 추가, Delegate 전송
   case .failure: 에러 메시지 표시

5. Parent Reducer (Delegate 처리)
   다른 Child Feature 갱신 또는 네비게이션
```

**핵심 원칙**:
- View → ViewAction → Effect → InternalAction → State 변경
- 에러는 InternalAction에서 처리
- 성공 시 Delegate로 부모에게 알림

> 📘 **상세 예시**: [DEVELOPMENT.md - Feature 개발 가이드](DEVELOPMENT.md#22-tca-feature-구조)

---

## 구조 규칙 요약

### Feature 구조

✅ **필수**:
- Namespace 패턴 (`enum FeatureName {}`)
- Action 계층화 (ViewAction / InternalAction / DelegateAction)
- `@ObservableState` 사용
- Delegate 패턴으로 부모와 통신

❌ **금지**:
- Sibling Features 간 직접 의존
- Client 없이 Firebase 직접 호출
- State에 non-Equatable 타입 포함

### Client 구조

✅ **필수**:
- `@DependencyClient` 사용
- `@Sendable` 준수
- liveValue / testValue / previewValue 제공

### 모듈 의존성

```
App → Features → Clients → Shared
         ↓           ↓
   ExternalDependency
```

- 화살표 방향으로만 의존 가능
- Features끼리는 Parent-Child만 허용

---

## 참고 자료

### 외부 문서
- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)
- [Tuist 공식 문서](https://docs.tuist.io/)
- [Swift Testing](https://developer.apple.com/documentation/testing)

### 프로젝트 문서
- [.ai/PROJECT_CONTEXT.md](../.ai/PROJECT_CONTEXT.md) - 코딩 컨벤션 및 세부 규칙
- [.ai/FIRESTORE_SCHEMA.md](../.ai/FIRESTORE_SCHEMA.md) - 데이터베이스 스키마
- [.claude/CLAUDE.md](../.claude/CLAUDE.md) - AI 개발 가이드

---

**마지막 업데이트**: 2025-02-06
**문서 버전**: 1.1.0
