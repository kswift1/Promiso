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

  // MARK: - Profile Operations
  /// 프로필 이미지 업로드
  func uploadProfileImage(uid: String, imageData: Data) async throws -> URL

  /// 프로필 존재 여부 확인
  func hasProfile(uid: String) async throws -> Bool
  
  /// 닉네임 사용 가능 여부 확인
  func isNicknameAvailable(_ nickname: String) async throws -> Bool
}
