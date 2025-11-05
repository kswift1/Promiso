import Foundation

// MARK: - User Repository Protocol

public protocol UserRepositoryProtocol {
  // MARK: - CRUD Operations
  func createUser(_ user: UserModel) async throws -> String
  func updateUser(_ user: UserModel) async throws
  func deleteUser(id: String) async throws
  func getUser(id: String) async throws -> UserModel?
  
  // MARK: - Query Operations
  func getUsersByIds(_ ids: [String]) async throws -> [UserModel]
  func searchUsers(query: String) async throws -> [UserModel]
}
