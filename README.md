# Promiso

약속 관리 iOS 애플리케이션

## 🏗️ 아키텍처

이 프로젝트는 **The Composable Architecture (TCA)** 기반으로 구성되어 있습니다.

### 아키텍처 구조

```
┌─────────────────────────────────────────┐
│            App Layer                    │
│     (앱 조립 및 Feature 통합)               │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│        Features Layer                   │
│  (TCA Reducers & Views - 비즈니스 로직)    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Clients Layer                   │
│   (TCA Dependencies - 외부 의존성)         │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Shared Layer                    │
│    (공통 모델, UI 컴포넌트, 유틸리티)          │
└─────────────────────────────────────────┘
```

### 핵심 원칙

- **Features**: 각 화면/기능은 독립적인 TCA Feature로 구성
- **Clients**: Firebase, API 등 외부 의존성은 TCA Dependency로 추상화
- **Shared**: 여러 Feature가 공유하는 모델과 UI 컴포넌트
- **단방향 의존성**: App → Features → Clients → Shared

## 🚀 시작하기

### 요구사항

- Xcode 15.0+
- Swift 6.0+
- iOS 17.0+
- Tuist 4.0+

### 설치

```bash
# 1. 저장소 클론
git clone https://github.com/kswift1/Promiso.git
cd Promiso

# 2. Tuist 의존성 설치 및 프로젝트 생성
tuist install
tuist generate

# 3. Xcode에서 열기
open Promiso.xcworkspace
```

## 📦 프로젝트 구조

```
Projects/
├── App/                           # 메인 애플리케이션
│   └── Sources/
│       └── PromisoApp.swift       # 앱 진입점 & Root Feature
│
├── Features/                      # 기능별 TCA Features
│   ├── HomeFeature/
│   │   ├── HomeFeature.swift      # Reducer (비즈니스 로직)
│   │   ├── HomeView.swift         # SwiftUI View
│   │   └── Models/                # Feature 전용 모델
│   ├── GroupFeature/
│   │   ├── GroupFeature.swift
│   │   ├── GroupView.swift
│   │   └── Subfeatures/           # 하위 기능
│   │       └── GroupDetailFeature/
│   └── RootTabFeature/
│       └── RootTabFeature.swift   # 탭 네비게이션
│
├── Clients/                       # TCA Dependencies (외부 의존성)
│   ├── FirebaseClient/
│   │   ├── FirebaseClient.swift           # DependencyClient 인터페이스
│   │   └── FirebaseClient+Live.swift      # Firebase 구현체
│   ├── AuthClient/
│   │   ├── AuthClient.swift
│   │   └── AuthClient+Live.swift
│   └── LiveActivityClient/
│       ├── LiveActivityClient.swift
│       └── LiveActivityClient+Live.swift
│
└── Shared/                        # 공통 요소
    ├── Models/                    # 도메인 모델
    │   ├── Promise.swift
    │   ├── Group.swift
    │   └── User.swift
    ├── DesignSystem/              # UI 컴포넌트
    │   ├── Components/
    │   └── Styles/
    └── Extensions/
```

## 🛠️ 개발 워크플로우

### 새 Feature 생성

```bash
make feature FEATURE_NAME=YourFeature
```

이 명령어는 자동으로:
1. Feature 스캐폴드 생성 (Reducer + View)
2. 의존성 자동 추가
3. 프로젝트 재생성

### 의존성 그래프 확인

```bash
make deps
```

현재 프로젝트의 의존성 구조를 시각화하여 보여줍니다.

### 빌드 및 테스트

```bash
# 전체 프로젝트 빌드
tuist build

# 특정 Feature 빌드
tuist build GroupFeature

# 테스트 실행
tuist test
```

## 🔑 핵심 개념

### TCA Feature 구조

```swift
// Features/PromiseListFeature/PromiseListFeature.swift
import ComposableArchitecture
import FirebaseClient
import SharedModels

@Reducer
public struct PromiseListFeature {
    @ObservableState
    public struct State: Equatable {
        var promises: [Promise] = []
        var isLoading = false
    }
    
    public enum Action {
        case onAppear
        case createPromiseButtonTapped
        case promisesResponse([Promise])
    }
    
    @Dependency(\.firebaseClient) var firebaseClient
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    // 비즈니스 로직은 Reducer에서 처리
                    let promises = try await firebaseClient.fetchPromises()
                    await send(.promisesResponse(promises))
                }
                
            case .createPromiseButtonTapped:
                return .run { [promise = state.newPromise] send in
                    try await firebaseClient.createPromise(promise)
                    await send(.onAppear) // 목록 새로고침
                }
                
            case let .promisesResponse(promises):
                state.isLoading = false
                state.promises = promises
                return .none
            }
        }
    }
}
```

### Client 구조 (외부 의존성 추상화)

```swift
// Clients/FirebaseClient/FirebaseClient.swift
import ComposableArchitecture
import SharedModels

@DependencyClient
public struct FirebaseClient {
    public var createPromise: @Sendable (Promise) async throws -> String
    public var fetchPromises: @Sendable () async throws -> [Promise]
    public var observePromises: @Sendable (String) -> AsyncStream<[Promise]>
}

extension FirebaseClient: DependencyKey {
    public static let liveValue: FirebaseClient = {
        // Clients/FirebaseClient/FirebaseClient+Live.swift
        Self(
            createPromise: { promise in
                let db = Firestore.firestore()
                let docRef = db.collection("promises").document()
                try await docRef.setData([
                    "title": promise.title,
                    "date": promise.date,
                    // ...
                ])
                return docRef.documentID
            },
            fetchPromises: {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("promises").getDocuments()
                return snapshot.documents.compactMap { doc in
                    try? doc.data(as: Promise.self)
                }
            },
            observePromises: { userId in
                AsyncStream { continuation in
                    let db = Firestore.firestore()
                    let listener = db.collection("promises")
                        .whereField("participants", arrayContains: userId)
                        .addSnapshotListener { snapshot, error in
                            guard let documents = snapshot?.documents else { return }
                            let promises = documents.compactMap { 
                                try? $0.data(as: Promise.self) 
                            }
                            continuation.yield(promises)
                        }
                    
                    continuation.onTermination = { _ in
                        listener.remove()
                    }
                }
            }
        )
    }()
    
    // 테스트용 Mock
    public static let testValue = Self()
    
    // Preview용
    public static let previewValue = Self(
        createPromise: { _ in "preview-id" },
        fetchPromises: { Promise.mocks },
        observePromises: { _ in AsyncStream { $0.yield(Promise.mocks) } }
    )
}

extension DependencyValues {
    public var firebaseClient: FirebaseClient {
        get { self[FirebaseClient.self] }
        set { self[FirebaseClient.self] = newValue }
    }
}
```

### Feature 간 통신 (부모 Feature에서 조율)

```swift
// App/Sources/RootFeature.swift
@Reducer
public struct RootFeature {
    @ObservableState
    public struct State {
        var promiseList: PromiseListFeature.State
        var userProfile: UserProfileFeature.State
    }
    
    public enum Action {
        case promiseList(PromiseListFeature.Action)
        case userProfile(UserProfileFeature.Action)
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.promiseList, action: \.promiseList) {
            PromiseListFeature()
        }
        Scope(state: \.userProfile, action: \.userProfile) {
            UserProfileFeature()
        }
        
        // Feature 간 통신 중재
        Reduce { state, action in
            switch action {
            case .promiseList(.delegate(.promiseCreated)):
                // 약속 생성 시 프로필 업데이트
                return .send(.userProfile(.refreshPromiseCount))
                
            default:
                return .none
            }
        }
    }
}
```

## 🧪 테스트

### TCA 테스트 예시

```swift
import ComposableArchitecture
import Testing

@testable import PromiseListFeature

@Test
func testCreatePromise() async {
    let promise = Promise.mock
    
    let store = TestStore(initialState: PromiseListFeature.State()) {
        PromiseListFeature()
    } withDependencies: {
        // Mock 의존성 주입
        $0.firebaseClient.createPromise = { _ in "test-id" }
    }
    
    await store.send(.createPromiseButtonTapped) {
        $0.isLoading = true
    }
    
    await store.receive(\.promiseCreated) {
        $0.isLoading = false
        $0.promises.append(promise)
    }
}
```

### 전체 테스트 실행

```bash
# 모든 테스트 실행
tuist test

# 특정 Feature 테스트
tuist test PromiseListFeatureTests
```

## 📋 Make 명령어

```bash
make help                                    # 도움말 표시
make feature FEATURE_NAME=Login             # Login Feature 생성
make remove-feature FEATURE_NAME=Login      # Login Feature 삭제
make deps                                   # 의존성 그래프 시각화
make clean                                  # 빌드 캐시 정리
```

## 📚 추가 문서

- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)

### 의존성 규칙

```
App → Features → Clients → Shared
  ↓       ↓         ↓         ↓
 통합     로직        구현       공통
```

- Features끼리는 서로 의존하지 않음
- 모든 외부 의존성은 Client로 추상화
- Shared는 누구에게도 의존하지 않음

---
