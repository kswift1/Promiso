# ADR 001: 의존성 아키텍처 (Dependency Architecture)

## 상태
채택됨 (Accepted) - 2025-10-03

## 맥락 (Context)
Promiso 프로젝트는 TCA를 사용한 iOS 앱으로, 백엔드는 Firebase를 사용합니다.
초기에는 Client-Repository-Domain의 3-Layer로 시작했으나 복잡도가 증가하여 재구조화가 필요했습니다.

## 결정 (Decision)
**4-Layer Clean Architecture + TCA 패턴**을 채택합니다:

```
Presentation (Features)
    ↓
Adapter (Clients)
    ↓
Domain (Business Logic)
    ↑
Infrastructure (Core)
```

## 각 레이어 역할

### 1. Presentation Layer (`Projects/Features/`)
- **역할**: UI 로직 및 사용자 인터랙션
- **기술**: SwiftUI + TCA (Reducer, State, Action)
- **의존성**: Clients, Domain (모델 참조), Shared
- **예시**: `GroupFeature`, `HomeFeature`

### 2. Adapter Layer (`Projects/Clients/`)
- **역할**: TCA 의존성 제공 및 모델 변환
- **기술**: @DependencyClient (TCA)
- **의존성**: Domain (Repository Protocol), ComposableArchitecture
- **책임**:
  - Feature Model ↔ Domain Model 변환
  - Domain Repository 호출
  - TCA 의존성 시스템과 통합
- **예시**: `PromiseClient`, `GroupClient`

### 3. Domain Layer (`Projects/Domain/`)
- **역할**: 비즈니스 로직 및 규칙 (Framework 독립적)
- **기술**: Pure Swift (외부 프레임워크 의존성 없음)
- **의존성**: 없음 (최상위 추상화)
- **내용**:
  - Repository Protocols
  - Domain Models (PromiseModel, User, Group 등)
  - Business Rules
- **예시**: `PromiseRepositoryProtocol`

### 4. Infrastructure Layer (`Projects/Core/`)
- **역할**: 외부 서비스 통합 및 구현
- **기술**: Firebase, Firestore
- **의존성**: Domain (Protocol 구현)
- **책임**:
  - Repository Protocol 구체 구현
  - Firebase/Firestore 연동
  - 네트워크 통신
- **예시**: `PromiseRepository` (CoreInfrastructure)

## 데이터 플로우 예시

### 약속 생성 (Create Promise)

```swift
// 1️⃣ Feature Layer
// File: GroupFeature/CreateGroupFeature.swift
case .createPromise:
  @Dependency(\.promiseClient) var promiseClient
  return .run { [proposal = state.promiseProposal] send in
    let id = try await promiseClient.createPromise(proposal, "userId")
    await send(._createPromiseResponse(.success(id)))
  }

// 2️⃣ Adapter Layer
// File: Clients/PromiseClient.swift
@DependencyClient
public struct PromiseClient {
  public var createPromise: @Sendable (PromiseProposal, String) async throws -> String

  static let liveValue: PromiseClient = {
    let repository: PromiseRepositoryProtocol = PromiseRepository()

    return Self(
      createPromise: { proposal, hostId in
        // 🔄 모델 변환: PromiseProposal → PromiseModel
        let domainModel = PromiseModel(
          id: UUID().uuidString,
          title: proposal.title,
          emoji: proposal.emoji,
          // ... 기타 필드
        )

        // Domain Repository 호출
        return try await repository.createPromise(domainModel)
      }
    )
  }()
}

// 3️⃣ Domain Layer
// File: Domain/Repositories/PromiseRepositoryProtocol.swift
public protocol PromiseRepositoryProtocol {
  func createPromise(_ promise: PromiseModel) async throws -> String
}

// 4️⃣ Infrastructure Layer
// File: CoreInfrastructure/PromiseRepository.swift
public final class PromiseRepository: PromiseRepositoryProtocol {
  public func createPromise(_ promise: PromiseModel) async throws -> String {
    // Firestore 저장
    let ref = try await db.collection("promises").addDocument(from: promise)
    return ref.documentID
  }
}
```

## 의존성 규칙

### ✅ 허용되는 의존성 방향
- Feature → Clients ✅
- Feature → Domain (모델 참조) ✅
- Feature → Shared ✅
- Clients → Domain ✅
- Core → Domain (구현) ✅

### ❌ 금지되는 의존성 방향
- Domain → Core ❌ (역방향 의존)
- Domain → Clients ❌ (하위 레이어 의존)
- Domain → Feature ❌ (하위 레이어 의존)
- Clients → Core ❌ (직접 Infrastructure 접근)

## 결과 (Consequences)

### 장점 ✅
1. **관심사의 분리**: 각 레이어가 명확한 책임을 가짐
2. **테스트 용이성**: 각 레이어 독립적으로 테스트 가능
3. **유지보수성**: 레이어별 독립적인 변경 가능
4. **확장성**: 새로운 백엔드/UI 프레임워크 교체 용이

### 단점 ⚠️
1. **초기 복잡도**: 4개 레이어로 인한 파일 증가
2. **모델 변환 오버헤드**: Feature ↔ Domain 간 변환 필요
3. **학습 곡선**: 신규 개발자의 구조 이해 필요

### 완화 방안 💡
1. **문서화**: ADR 및 다이어그램으로 구조 명시
2. **자동화**: Tuist 템플릿으로 보일러플레이트 감소
3. **컨벤션**: 명확한 네이밍 및 파일 구조 규칙

## 참고 자료
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
