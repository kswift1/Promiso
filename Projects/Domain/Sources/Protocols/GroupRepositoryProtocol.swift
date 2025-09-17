import Foundation

// MARK: - Group Repository Protocol

public protocol GroupRepositoryProtocol {
  // MARK: - CRUD Operations
  func createGroup(_ group: Group) async throws -> String
  func updateGroup(_ group: Group) async throws
  func deleteGroup(id: String) async throws
  func getGroup(id: String) async throws -> Group?
  
  // MARK: - Query Operations
  func getUserGroups(userId: String) async throws -> [Group]
  func searchGroups(query: String) async throws -> [Group]
  func getPublicGroups(limit: Int) async throws -> [Group]
}

// MARK: - Group Role

public enum GroupRole: String, CaseIterable {
  case admin = "admin"
  case member = "member"
  case guest = "guest"
}
