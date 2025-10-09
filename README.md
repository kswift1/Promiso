# Promiso

약속 관리 iOS 애플리케이션

## 🏗️ 아키텍처

이 프로젝트는 **TCA + Clean Architecture** 기반의 4-Layer 아키텍처를 따릅니다.

### 레이어 구조

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│    (Features - TCA Reducers & Views)    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Adapter Layer                  │
│       (Clients - TCA Dependencies)      │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Domain Layer                    │
│    (Business Logic & Protocols)         │
└─────────────────────────────────────────┘
                    ↑
┌─────────────────────────────────────────┐
│      Infrastructure Layer               │
│    (Core - Firebase Implementation)     │
└─────────────────────────────────────────┘
```

### 주요 모듈

- **Features/**: Presentation Layer - TCA 기반 UI 로직
- **Clients/**: Adapter Layer - TCA Dependency 클라이언트
- **Domain/**: Business Logic - Framework 독립적인 도메인 로직
- **Core/**: Infrastructure - Firebase 구현체

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
├── App/                    # 메인 애플리케이션
├── Features/              # 피쳐 모듈 (Presentation)
│   ├── HomeFeature/
│   ├── PromiseFeature/
│   └── RootTabFeature/
├── Clients/               # TCA Dependencies (Adapter)
│   ├── PromiseClient/
│   └── GroupClient/
├── Domain/                # 비즈니스 로직
│   ├── Repositories/
│   └── Models/
└── Core/                  # Infrastructure
    ├── CoreInfrastructure/
    └── CoreNetworking/
```

## 🛠️ 개발 워크플로우

### 새 피쳐 생성

```bash
make feature FEATURE_NAME=YourFeature
```

이 명령어는 자동으로:
1. 피쳐 스캐폴드 생성
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

# 특정 피쳐 빌드
tuist build PromiseFeature

# 테스트 실행
tuist test
```

## 📚 문서

자세한 내용은 다음 문서를 참고하세요:

- [Architecture Decision Record](./docs/architecture/001-dependency-architecture.md) - 아키텍처 결정 문서
- [Clients Layer](./Projects/Clients/README.md) - Adapter Layer 가이드
- [Domain Layer](./Projects/Domain/README.md) - Domain Layer 가이드

## 🔑 핵심 개념

### 의존성 흐름

```swift
// Feature (Presentation)
@Dependency(\.promiseClient) var promiseClient
let id = try await promiseClient.createPromise(proposal, userId)

// ↓

// Clients (Adapter)
@DependencyClient
public struct PromiseClient {
  public var createPromise: @Sendable (PromiseProposal, String) async throws -> String

  static let liveValue: PromiseClient = {
    let repository: PromiseRepositoryProtocol = PromiseRepository()

    return Self(
      createPromise: { proposal, hostId in
        // Feature Model → Domain Model 변환
        let domainModel = PromiseModel(...)
        return try await repository.createPromise(domainModel)
      }
    )
  }()
}

// ↓

// Domain (Business Logic)
public protocol PromiseRepositoryProtocol {
  func createPromise(_ promise: PromiseModel) async throws -> String
}

// ↑

// Core (Infrastructure)
public final class PromiseRepository: PromiseRepositoryProtocol {
  public func createPromise(_ promise: PromiseModel) async throws -> String {
    // Firebase/Firestore 저장
  }
}
```

## 🧪 테스트

```bash
# 모든 테스트 실행
tuist test

# 특정 피쳐 테스트
tuist test PromiseFeatureTests
```

### TCA 테스트 예시

```swift
@Test
func testCreatePromise() async {
  await withDependencies {
    $0.promiseClient.createPromise = { _, _ in "test-id" }
  } operation: {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.createPromise)
    await store.receive(._response(.success("test-id")))
  }
}
```

## 📋 Make 명령어

```bash
make help                                    # 도움말 표시
make feature FEATURE_NAME=Login             # Login 피쳐 생성
make remove-feature FEATURE_NAME=Login      # Login 피쳐 삭제
make deps                                   # 의존성 그래프 시각화
```

## 🙋‍♂️ 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해주세요.
