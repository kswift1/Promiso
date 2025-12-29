# Domain Module

## 역할
**Shared Layer** - 비즈니스 로직 및 규칙을 정의합니다 (Framework 독립적).

## 책임
1. **Repository Protocols**: 데이터 접근 인터페이스 정의
2. **Shared Models**: 비즈니스 규칙을 표현하는 모델
3. **Business Rules**: 도메인 로직 및 검증 규칙

## 구조
```
Domain/
├── Repositories/
│   ├── PromiseRepositoryProtocol.swift
│   ├── GroupRepositoryProtocol.swift
│   └── UserRepositoryProtocol.swift
└── Models/
    ├── Promise/
    │   ├── PromiseModel.swift
    │   ├── PromiseStatus.swift
    │   └── LocationInfo.swift
    ├── Group/
    │   └── Group.swift
    └── User/
        └── User.swift
```

## 의존성
- ❌ **없음**: Domain은 어떤 외부 프레임워크에도 의존하지 않습니다
- ✅ **Pure Swift**: Foundation 라이브러리만 사용

## 핵심 원칙

### 1. Dependency Inversion Principle (DIP)
```
상위 레이어(Domain)가 하위 레이어(Infrastructure)를 의존하지 않고,
하위 레이어가 상위 레이어의 Protocol을 구현합니다.

Domain (Protocol) ← Core (Implementation)
```

### 2. Framework Independence
Domain 레이어는 특정 프레임워크에 종속되지 않습니다:
- ❌ Firebase, TCA, SwiftUI 등 의존성 없음
- ✅ 순수 Swift 타입만 사용

## 사용 예시

### Repository Protocol 정의
```swift
// Domain/Repositories/PromiseRepositoryProtocol.swift
public protocol PromiseRepositoryProtocol {
  func createPromise(_ promise: PromiseModel) async throws -> String
  func fetchPromise(by id: String) async throws -> PromiseModel?
  func updatePromise(_ promise: PromiseModel) async throws
  func deletePromise(by id: String) async throws
}
```

### Shared Model 정의
```swift
// Domain/Models/Promise/PromiseModel.swift
public struct PromiseModel: Equatable, Codable {
  public let id: String
  public let title: String
  public let emoji: String?
  public let description: String?
  public let minimumParticipants: Int
  public let requiredCount: Int
  public let isConfirmed: Bool
  public let host: User
  public let group: Group
  public let startAt: Date
  public let endAt: Date?
  public let status: PromiseStatus
  public let location: LocationInfo?

  // 비즈니스 규칙
  public var isActive: Bool {
    status == .active && !isConfirmed
  }

  public func canConfirm(participantCount: Int) -> Bool {
    participantCount >= minimumParticipants
  }
}
```

### Infrastructure에서 구현
```swift
// CoreInfrastructure/PromiseRepository.swift
import Shared

public final class PromiseRepository: PromiseRepositoryProtocol {
  private let db = Firestore.firestore()

  public func createPromise(_ promise: PromiseModel) async throws -> String {
    let ref = try await db.collection("promises").addDocument(from: promise)
    return ref.documentID
  }

  // ... 기타 메서드 구현
}
```

### Clients에서 사용
```swift
// Clients/PromiseClient.swift
import Shared

@DependencyClient
public struct PromiseClient {
  static let liveValue: PromiseClient = {
    // Protocol 타입으로 선언
    let repository: PromiseRepositoryProtocol = PromiseRepository()

    return Self(
      createPromise: { proposal, hostId in
        let domainModel = PromiseModel(...)
        return try await repository.createPromise(domainModel)
      }
    )
  }()
}
```

## 모델 설계 원칙

### 1. 완전성 (Completeness)
Shared Model은 비즈니스 규칙을 완전히 표현해야 합니다:
```swift
// ✅ 좋은 예: 비즈니스 규칙 명시
public struct PromiseModel {
  public let minimumParticipants: Int  // 최소 참가자 (필수)

  public func canConfirm(participantCount: Int) -> Bool {
    participantCount >= minimumParticipants
  }
}

// ❌ 나쁜 예: Optional로 인한 불명확성
public struct PromiseModel {
  public let minimumParticipants: Int?  // 왜 Optional?
}
```

### 2. 불변성 (Immutability)
가능한 한 불변 타입으로 설계:
```swift
// ✅ 좋은 예
public struct PromiseModel {
  public let id: String
  public let title: String

  public func withUpdatedTitle(_ newTitle: String) -> PromiseModel {
    var copy = self
    copy.title = newTitle
    return copy
  }
}
```

### 3. 도메인 언어 (Ubiquitous Language)
비즈니스 용어 그대로 사용:
```swift
// ✅ 좋은 예
public enum PromiseStatus {
  case active       // 활성
  case confirmed    // 확정
  case cancelled    // 취소
  case completed    // 완료
}

// ❌ 나쁜 예
public enum Status {
  case one, two, three, four
}
```

## 테스트

### Mock Repository 구현
```swift
// Tests/MockPromiseRepository.swift
import Shared

public final class MockPromiseRepository: PromiseRepositoryProtocol {
  public var createPromiseResult: Result<String, Error> = .success("mock-id")

  public func createPromise(_ promise: PromiseModel) async throws -> String {
    try createPromiseResult.get()
  }
}
```

### Shared Logic 테스트
```swift
@Test
func testPromiseCanConfirmWithEnoughParticipants() {
  let promise = PromiseModel(
    minimumParticipants: 3,
    // ...
  )

  #expect(promise.canConfirm(participantCount: 3) == true)
  #expect(promise.canConfirm(participantCount: 2) == false)
}
```

## 의존성 규칙 체크리스트

### ✅ Domain은 다음에 의존할 수 있습니다:
- Foundation (Date, UUID 등)
- Swift Standard Library

### ❌ Domain은 다음에 의존하면 안됩니다:
- Firebase / Firestore
- ComposableArchitecture
- SwiftUI / UIKit
- 다른 프로젝트 모듈 (Clients, Core, Features)

## 주의사항

⚠️ **Protocol은 Domain에, 구현은 Infrastructure에**
```swift
// ✅ Domain/PromiseRepositoryProtocol.swift
public protocol PromiseRepositoryProtocol { }

// ✅ CoreInfrastructure/PromiseRepository.swift
public class PromiseRepository: PromiseRepositoryProtocol { }
```

⚠️ **Shared Model은 외부에 노출하지 마세요**
- Feature는 Feature Model (PromiseProposal) 사용
- Shared Model은 Clients 내부에서만 사용
