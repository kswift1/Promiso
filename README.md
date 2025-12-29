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

┌─────────────────────────────────────────┐
│   ExternalDependency / ResourceKit      │
│ (외부 라이브러리 집약 / 리소스 관리)        │
└─────────────────────────────────────────┘
```

### 핵심 원칙

- **Features**: 각 화면/기능은 독립적인 TCA Feature로 구성
- **Clients**: Firebase, API 등 외부 의존성은 TCA Dependency로 추상화
- **Shared**: 여러 Feature가 공유하는 모델과 UI 컴포넌트
- **ExternalDependency**: 외부 라이브러리를 단일 모듈로 집약해 재노출
- **ResourceKit**: 디자인 리소스/생성 코드 관리
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
│       ├── AppMain.swift          # 앱 진입점
│       └── LiveDependencies.swift # 의존성 주입
│
├── Features/                      # 기능별 TCA Features
│   ├── AppEntryFeature/
│   ├── AuthFeature/
│   ├── GroupFeature/
│   ├── HomeFeature/
│   └── RootTabFeature/
│
├── Clients/                       # TCA Dependencies (외부 의존성)
│   ├── AuthClient/
│   ├── GroupClient/
│   ├── PromiseClient/
│   ├── UserProfileClient/
│   ├── Infrastructure/
│   └── Networking/
│
├── Shared/                        # 공통 요소
│   ├── Models/
│   ├── UseCases/
│   ├── Protocols/
│   ├── Errors/
│   ├── DesignSystem/
│   ├── UI/
│   ├── Services/
│   ├── Extensions/
│   ├── Constants/
│   ├── Common/
│   └── Emoji/
│
├── ResourceKit/                   # 리소스/생성 코드
│   ├── Resources/
│   └── Sources/Generated/
│
└── ExternalDependency/            # 외부 라이브러리 집약
    └── Sources/ExternalDependency.swift
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
import Clients
import Shared

@Reducer
public struct PromiseListFeature {
    @ObservableState
    public struct State: Equatable {
        var promises: [PromiseModel] = []
        var isLoading = false
    }
    
    public enum Action {
        case onAppear
        case promisesResponse([PromiseModel])
    }
    
    @Dependency(\.promiseClient) var promiseClient
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let promises = try await promiseClient.fetchPromises()
                    await send(.promisesResponse(promises))
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
// Clients/PromiseClient/PromiseClient.swift
import ComposableArchitecture
import Shared

@DependencyClient
public struct PromiseClient {
    public var fetchPromises: @Sendable () async throws -> [PromiseModel]
}

extension PromiseClient: DependencyKey {
    public static let liveValue: PromiseClient = {
        Self(
            fetchPromises: {
                // Networking/Repository 등을 통해 데이터 로딩
                []
            }
        )
    }()
}

extension DependencyValues {
    public var promiseClient: PromiseClient {
        get { self[PromiseClient.self] }
        set { self[PromiseClient.self] = newValue }
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
        var featureA: FeatureA.State
        var featureB: FeatureB.State
    }
    
    public enum Action {
        case featureA(FeatureA.Action)
        case featureB(FeatureB.Action)
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.featureA, action: \.featureA) { FeatureA() }
        Scope(state: \.featureB, action: \.featureB) { FeatureB() }
        
        Reduce { state, action in
            switch action {
            case .featureA(.delegate(.didComplete)):
                return .send(.featureB(.refresh))
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
        $0.promiseClient.fetchPromises = { [promise] }
    }
    
    await store.send(.onAppear) {
        $0.isLoading = true
    }
    
    await store.receive(\.promisesResponse) {
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
  ↓       ↓         ↓
 통합     로직        구현
```

- Features끼리는 서로 의존하지 않음
- 모든 외부 의존성은 ExternalDependency 모듈로 집약
- Shared는 ExternalDependency/ResourceKit 외 내부 모듈에 의존하지 않음

---
