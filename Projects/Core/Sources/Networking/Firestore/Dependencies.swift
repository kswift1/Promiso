import Foundation
import ComposableArchitecture
import Domain
import Combine

// MARK: - Repository Dependencies

extension DependencyValues {
  var groupRepository: GroupRepositoryProtocol {
    get { self[GroupRepositoryKey.self] }
    set { self[GroupRepositoryKey.self] = newValue }
  }
  
  var promiseRepository: PromiseRepositoryProtocol {
    get { self[PromiseRepositoryKey.self] }
    set { self[PromiseRepositoryKey.self] = newValue }
  }
}

// MARK: - Group Repository Dependency

private enum GroupRepositoryKey: DependencyKey {
  public static let liveValue: GroupRepositoryProtocol = {
    // 실제 앱에서는 GroupRepository 사용
    // 현재는 MockGroupRepository 사용
    MockGroupRepository()
  }()
  public static let testValue: GroupRepositoryProtocol = MockGroupRepository()
  public static let previewValue: GroupRepositoryProtocol = MockGroupRepository()
}

// MARK: - Promise Repository Dependency

private enum PromiseRepositoryKey: DependencyKey {
  public static let liveValue: PromiseRepositoryProtocol = {
    // 실제 앱에서는 PromiseRepository 사용
    // 현재는 MockPromiseRepository 사용
    MockPromiseRepository()
  }()
  public static let testValue: PromiseRepositoryProtocol = MockPromiseRepository()
  public static let previewValue: PromiseRepositoryProtocol = MockPromiseRepository()
}

// MARK: - Mock Implementations

private class MockGroupRepository: GroupRepositoryProtocol {
  func createGroup(_ group: Group) async throws -> String {
    // Mock implementation
    return "mock-group-id"
  }
  
  func updateGroup(_ group: Group) async throws {
    // Mock implementation
  }
  
  func deleteGroup(id: String) async throws {
    // Mock implementation
  }
  
  func getGroup(id: String) async throws -> Group? {
    // Mock implementation
    return nil
  }
  
  func getUserGroups(userId: String) async throws -> [Group] {
    // Mock implementation
    return []
  }
  
  func searchGroups(query: String) async throws -> [Group] {
    // Mock implementation
    return []
  }
  
  func getPublicGroups(limit: Int) async throws -> [Group] {
    // Mock implementation
    return []
  }
}

private class MockPromiseRepository: PromiseRepositoryProtocol {
  func createPromise(_ promise: PromiseModel) async throws -> String {
    // Mock implementation
    return "mock-promise-id"
  }
  
  func updatePromise(_ promise: PromiseModel) async throws {
    // Mock implementation
  }
  
  func deletePromise(id: String) async throws {
    // Mock implementation
  }
  
  func getPromise(id: String) async throws -> PromiseModel? {
    // Mock implementation
    return nil
  }
  
  func getUserPromises(userId: String) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func getGroupPromises(groupId: String) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func getPendingProposals(userId: String, limit: Int) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    // Mock implementation
    return []
  }
  
  func observeTodayPromises(userId: String, groupId: String?) -> AnyPublisher<[PromiseModel], Error> {
    // Mock implementation
    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
  
  func observePromise(id: String) -> AnyPublisher<PromiseModel?, Error> {
    // Mock implementation
    return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
}
