import ComposableArchitecture
import Shared
import XCTestDynamicOverlay

public struct CreateGroupUseCaseClient: Sendable {
  public var execute: @Sendable (CreateGroupUseCaseInput) async throws -> CreateGroupUseCaseOutput

  public init(
    execute: @escaping @Sendable (CreateGroupUseCaseInput) async throws -> CreateGroupUseCaseOutput
  ) {
    self.execute = execute
  }
}

private enum CreateGroupUseCaseClientKey: DependencyKey {
  static let liveValue: CreateGroupUseCaseClient = {
    @Dependency(\.groupRepository) var repository
    let useCase = DefaultCreateGroupUseCase(repository: repository)

    return CreateGroupUseCaseClient { input in
      try await useCase.execute(input)
    }
  }()

  static let testValue: CreateGroupUseCaseClient = .init { _ in
    XCTFail("Unimplemented: CreateGroupUseCaseClient.execute")
    return .init(id: "", inviteCode: "", photoPath: nil)
  }
}

public extension DependencyValues {
  var createGroupUseCase: CreateGroupUseCaseClient {
    get { self[CreateGroupUseCaseClientKey.self] }
    set { self[CreateGroupUseCaseClientKey.self] = newValue }
  }
}
