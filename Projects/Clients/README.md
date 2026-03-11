# Clients Module

## 역할
**Adapter Layer** - TCA 의존성 클라이언트 제공 및 모델 변환을 담당합니다.

## 책임
1. **@DependencyClient 정의**: Feature에서 사용할 TCA 의존성 제공
2. **모델 변환**: Feature Model ↔ Shared Model 간 변환
3. **데이터 접근**: Networking/Infrastructure 구현체를 통해 외부 시스템 연동

## 구조
```
Clients/
├── AuthClient/
├── GroupClient/
├── ScheduleClient/
├── UserProfileClient/
├── Infrastructure/
└── Networking/
```

## 의존성
- ✅ **Shared**: 공통 모델/프로토콜 사용
- ✅ **ExternalDependency**: 외부 라이브러리 집약 모듈 사용
- ✅ **ComposableArchitecture**: @DependencyClient 매크로

## 사용 예시

### Feature에서 사용
```swift
// GroupFeature/CreateGroupFeature.swift
import Clients
import ComposableArchitecture

@Reducer
public struct Feature {
  @Dependency(\.scheduleClient) var scheduleClient

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      case .createSchedule:
        return .run { [proposal = state.scheduleProposal] send in
          let id = try await scheduleClient.createSchedule(proposal, "userId")
          await send(._response(.success(id)))
        }
    }
  }
}
```

### Client 정의
```swift
// Clients/ScheduleClient/ScheduleClient.swift
import ComposableArchitecture
import Shared

@DependencyClient
public struct ScheduleClient: Sendable {
  public var createSchedule: @Sendable (_ proposal: ScheduleProposal, _ hostId: String) async throws -> String
}

extension ScheduleClient: DependencyKey {
  public static let liveValue: ScheduleClient = {
    let repository: ScheduleRepositoryProtocol = ScheduleRepository()

    return Self(
      createSchedule: { proposal, hostId in
        // Feature Model → Shared Model 변환
        let model = ScheduleModel(
          id: UUID().uuidString,
          title: proposal.title,
          emoji: proposal.emoji
        )

        // Repository 호출
        return try await repository.createSchedule(model)
      }
    )
  }()
}
```

## 모델 변환 규칙

### Feature Model vs Shared Model
- **Feature Model** (ScheduleProposal): UI 친화적, Optional 많음, Partial 상태
- **Shared Model** (ScheduleModel): 비즈니스 규칙 반영, 완전한 데이터

### 변환 시점
- **Feature → Shared**: Client의 liveValue에서 변환
- **Shared → Feature**: Repository 응답을 Feature 모델로 변환

## 테스트

### TestDependency 사용
```swift
// Feature Tests에서
import Clients

@Test
func testCreateSchedule() async {
  await withDependencies {
    $0.scheduleClient.createSchedule = { _, _ in "test-id" }
  } operation: {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.createSchedule)
    await store.receive(._response(.success("test-id")))
  }
}
```

## 주의사항
⚠️ **외부 라이브러리는 ExternalDependency를 통해서만 사용**
- ❌ 각 모듈에서 직접 SPM 라이브러리 추가
- ✅ ExternalDependency 모듈 의존

⚠️ **Shared Model을 Feature에 직접 노출하지 않도록 주의**
- Feature는 ScheduleProposal 사용
- Shared의 ScheduleModel은 Client 내부에서만 사용
