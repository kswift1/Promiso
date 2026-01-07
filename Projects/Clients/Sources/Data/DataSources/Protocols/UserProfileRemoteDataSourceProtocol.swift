import Foundation

// MARK: - User Profile Remote Data Source Protocol

public protocol UserProfileRemoteDataSourceProtocol {
  // MARK: - User CRUD Operations

  /// 사용자 생성 (회원가입)
  func createUser(
    name: String?,
    nickname: String,
    provider: ProviderInfo
  ) async throws -> String

  /// 사용자 프로필 조회
  func getProfileModel(uid: String?, isPublic: Bool) async throws -> UserProfile

  /// 여러 사용자의 공개 프로필 조회 (배치)
  func getUsersByIds(userIds: [String]) async throws -> [UserPublicModel]

  /// 사용자 프로필 업데이트
  func updateProfile(uid: String, nickname: String) async throws

  // MARK: - Profile Image Operations

  /// 프로필 이미지 업로드
  func uploadProfileImage(uid: String, imageData: Data) async throws -> URL

  /// 프로필 이미지 삭제
  func deleteProfileImage(uid: String) async throws

  // MARK: - Settings Operations

  /// 사용자 설정 조회
  func getUserSettings() async throws -> Bool

  /// 사용자 설정 업데이트
  func updateUserSettings(notificationEnabled: Bool) async throws

  // MARK: - Utility Operations

  /// 닉네임 사용 가능 여부 확인
  func isNicknameAvailable(_ nickname: String) async throws -> Bool
}
