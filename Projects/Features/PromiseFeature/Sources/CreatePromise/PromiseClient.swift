import ComposableArchitecture
import Foundation
import Combine
import Domain

/// 약속 API 에러
public enum PromiseClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData
  case unknown

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "약속을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .invalidData:
      return "잘못된 데이터입니다"
    case .unknown:
      return "알 수 없는 오류가 발생했습니다"
    }
  }
}

/// 약속 클라이언트 프로토콜
@DependencyClient
public struct PromiseClient: Sendable {
  /// 약속 생성
  public var createPromise: @Sendable (_ proposal: PromiseProposal, _ hostId: String) async throws -> String = { _, _ in "" }

  /// 약속 수정
  public var updatePromise: @Sendable (_ promiseId: String, _ proposal: PromiseProposal) async throws -> Void

  /// 약속 삭제
  public var deletePromise: @Sendable (_ promiseId: String) async throws -> Void

  /// 약속 조회
  public var getPromise: @Sendable (_ promiseId: String) async throws -> PromiseModel?

  /// 오늘의 약속 조회
  public var getTodayPromises: @Sendable (_ userId: String, _ groupId: String?) async throws -> [PromiseModel]

  /// 다가오는 약속 조회
  public var getUpcomingPromises: @Sendable (_ userId: String, _ limit: Int) async throws -> [PromiseModel]
}

// MARK: - Dependency Values

extension PromiseClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    createPromise: { proposal, hostId in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updatePromise: { promiseId, proposal in
      try await Task.sleep(for: .seconds(1))
    },
    deletePromise: { promiseId in
      try await Task.sleep(for: .seconds(0.5))
    },
    getPromise: { promiseId in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getTodayPromises: { userId, groupId in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getUpcomingPromises: { userId, limit in
      try await Task.sleep(for: .seconds(1))
      return []
    }
  )
}

extension DependencyValues {
  public var promiseClient: PromiseClient {
    get { self[PromiseClient.self] }
    set { self[PromiseClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension PromiseClient: DependencyKey {
  public static let liveValue: PromiseClient = {
    @Dependency(\.promiseRepository) var repository

    return Self(
      createPromise: { proposal, hostId in
        // PromiseProposal -> PromiseModel 변환
        guard let group = proposal.group else {
          throw PromiseClientError.invalidData
        }

        let promiseModel = PromiseModel(
          id: UUID().uuidString,
          emoji: proposal.emoji,
          title: proposal.title,
          description: proposal.details,
          minimumParticipants: proposal.minimumParticipants ?? 2,
          requiredCount: proposal.minimumParticipants ?? 2,
          isConfirmed: false,
          host: User(id: hostId, email: "", nickname: ""),
          group: Group(id: group.id, name: group.title),
          startAt: proposal.startedAt,
          endAt: proposal.endedAt,
          status: .active,
          location: proposal.place.map { LocationInfo(name: $0) }
        )

        return try await repository.createPromise(promiseModel)
      },
      updatePromise: { promiseId, proposal in
        // TODO: 실제 업데이트 로직 구현
        try await Task.sleep(for: .seconds(1))
      },
      deletePromise: { promiseId in
        try await repository.deletePromise(id: promiseId)
      },
      getPromise: { promiseId in
        try await repository.getPromise(id: promiseId)
      },
      getTodayPromises: { userId, groupId in
        try await repository.getTodayPromises(userId: userId, groupId: groupId)
      },
      getUpcomingPromises: { userId, limit in
        try await repository.getUpcomingPromises(userId: userId, limit: limit)
      }
    )
  }()
}

// MARK: - Helper: PromiseRepository Dependency

extension DependencyValues {
  var promiseRepository: PromiseRepositoryProtocol {
    get { self[PromiseRepositoryKey.self] }
    set { self[PromiseRepositoryKey.self] = newValue }
  }
}

private enum PromiseRepositoryKey: DependencyKey {
  static let liveValue: PromiseRepositoryProtocol = {
    // Core 모듈의 PromiseRepository를 사용
    // 실제 앱에서는 Dependency Injection을 통해 주입됨
    // 현재는 임시로 Mock 반환
    MockPromiseRepository()
  }()
}

// MARK: - Mock Repository (임시)

private class MockPromiseRepository: PromiseRepositoryProtocol {
  func createPromise(_ promise: PromiseModel) async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return UUID().uuidString
  }

  func updatePromise(_ promise: PromiseModel) async throws {
    try await Task.sleep(for: .seconds(1))
  }

  func deletePromise(id: String) async throws {
    try await Task.sleep(for: .seconds(0.5))
  }

  func getPromise(id: String) async throws -> PromiseModel? {
    try await Task.sleep(for: .seconds(0.5))
    return nil
  }

  func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel] {
    try await Task.sleep(for: .seconds(1))
    return []
  }

  func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel] {
    try await Task.sleep(for: .seconds(1))
    return []
  }

  func getPendingProposals(userId: String, limit: Int) async throws -> [PromiseModel] {
    try await Task.sleep(for: .seconds(1))
    return []
  }

  func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    try await Task.sleep(for: .seconds(1))
    return []
  }

  func observeTodayPromises(userId: String, groupId: String?) -> AnyPublisher<[PromiseModel], Error> {
    Just([])
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }

  func observePromise(id: String) -> AnyPublisher<PromiseModel?, Error> {
    Just(nil)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
