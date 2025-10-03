# Clients Module

## 역할
**Adapter Layer** - TCA 의존성 클라이언트 제공 및 모델 변환을 담당합니다.

## 책임
1. **@DependencyClient 정의**: Feature에서 사용할 TCA 의존성 제공
2. **모델 변환**: Feature Model ↔ Domain Model 간 변환
3. **Domain Repository 호출**: Infrastructure 레이어의 구현체 사용

## 구조
```
Clients/
├── PromiseClient/
│   ├── PromiseClient.swift         # TCA Dependency Client
│   ├── Models/
│   │   └── PromiseProposal.swift   # Feature-Layer 모델
│   └── PromiseClientError.swift    # 에러 정의
└── GroupClient/
    ├── GroupClient.swift
    └── Models/
        └── GroupModel.swift
```

## 의존성
- ✅ **Domain**: Repository Protocol 사용
- ✅ **ComposableArchitecture**: @DependencyClient 매크로
- ✅ **CoreNetworking**: 네트워크 유틸리티 (필요시)

## 사용 예시

### Feature에서 사용
```swift
// PromiseFeature/CreatePromiseFeature.swift
import Clients
import ComposableArchitecture

@Reducer
public struct Feature {
  @Dependency(\.promiseClient) var promiseClient

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      case .createPromise:
        return .run { [proposal = state.promiseProposal] send in
          let id = try await promiseClient.createPromise(proposal, "userId")
          await send(._response(.success(id)))
        }
    }
  }
}
```

### Client 정의
```swift
// Clients/PromiseClient/PromiseClient.swift
import ComposableArchitecture
import Domain

@DependencyClient
public struct PromiseClient: Sendable {
  public var createPromise: @Sendable (_ proposal: PromiseProposal, _ hostId: String) async throws -> String
}

extension PromiseClient: DependencyKey {
  public static let liveValue: PromiseClient = {
    let repository: PromiseRepositoryProtocol = PromiseRepository()

    return Self(
      createPromise: { proposal, hostId in
        // Feature Model → Domain Model 변환
        let domainModel = PromiseModel(
          id: UUID().uuidString,
          title: proposal.title,
          emoji: proposal.emoji,
          // ...
        )

        // Domain Repository 호출
        return try await repository.createPromise(domainModel)
      }
    )
  }()
}
```

## 모델 변환 규칙

### Feature Model vs Domain Model
- **Feature Model** (PromiseProposal): UI 친화적, Optional 많음, Partial 상태
- **Domain Model** (PromiseModel): 비즈니스 규칙 반영, 완전한 데이터

### 변환 시점
- **Feature → Domain**: Client의 liveValue에서 변환
- **Domain → Feature**: Repository 응답을 Feature 모델로 변환

## 테스트

### TestDependency 사용
```swift
// Feature Tests에서
import Clients

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

## 주의사항
⚠️ **Infrastructure를 직접 import하지 마세요**
- ❌ `import CoreInfrastructure`
- ✅ `import Domain` (Protocol만 사용)

⚠️ **Domain Model을 Feature에 노출하지 마세요**
- Feature는 PromiseProposal 사용
- Domain의 PromiseModel은 Client 내부에서만 사용
