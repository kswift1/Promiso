import Foundation

// MARK: - User Repository Protocol

public protocol UserRepositoryProtocol {
  // MARK: - CRUD Operations
  func createUser(_ user: User) async throws -> String
  func updateUser(_ user: User) async throws
  func deleteUser(id: String) async throws
  func getUser(id: String) async throws -> User?
  
  // MARK: - Query Operations
  func getUsersByIds(_ ids: [String]) async throws -> [User]
  func searchUsers(query: String) async throws -> [User]
}
