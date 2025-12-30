import Foundation
import Shared

/// Firebase를 통한 사용자 프로필 데이터 관리
public final class UserProfileRemoteDataSource: @unchecked Sendable {
  private let repository: UserRepositoryProtocol

  public init(
    repository: UserRepositoryProtocol = FirebaseUserRepository()
  ) {
    self.repository = repository
  }

  public func saveProfile(uid: String, profile: UserProfile) async throws {
    try await repository.saveProfile(uid: uid, profile: profile)
  }

  public func saveProfileWithImage(
    uid: String,
    profile: UserProfile,
    imageInput: UserProfileImageInput
  ) async throws -> UserModel {
    var profileInfo: ProfileInfo?
    var didUploadImage = false

    do {
      switch imageInput {
      case .skip:
        profileInfo = nil
      case .data(let data):
        if let imageData = data {
          _ = try await repository.uploadProfileImage(uid: uid, imageData: imageData)
          didUploadImage = true
          profileInfo = ProfileInfo(type: .storagePath, url: "profile_images/\(uid).jpg")
        }
      case .url(let url):
        profileInfo = ProfileInfo(type: .externalURL, url: url.absoluteString)
      case .none:
        profileInfo = nil
      }

      let finalProfile = UserProfile(
        name: profile.name,
        nickname: profile.nickname,
        email: profile.email,
        provider: profile.provider,
        profile: profileInfo,
        pinnedGroupId: profile.pinnedGroupId,
        notificationSettings: profile.notificationSettings,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt
      )

      try await repository.saveProfile(uid: uid, profile: finalProfile)
      return finalProfile.toUserModel(uid: uid)
    } catch {
      if didUploadImage {
        try? await repository.deleteProfileImage(uid: uid)
      }
      throw error
    }
  }

  public func getProfile(uid: String) async throws -> UserProfile? {
    try await repository.getProfile(uid: uid)
  }

  public func getProfileModel(uid: String) async throws -> UserModel? {
    guard let profile = try await repository.getProfile(uid: uid) else {
      return nil
    }
    return profile.toUserModel(uid: uid)
  }

  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    try await repository.uploadProfileImage(uid: uid, imageData: imageData)
  }

  public func hasProfile(uid: String) async throws -> UserProfile? {
    try await repository.hasProfile(uid: uid)
  }

  public func hasProfileModel(uid: String) async throws -> UserModel? {
    guard let profile = try await repository.hasProfile(uid: uid) else {
      return nil
    }
    return profile.toUserModel(uid: uid)
  }

  public func isNicknameAvailable(_ nickname: String) async throws -> Bool {
    try await repository.isNicknameAvailable(nickname)
  }

  public func updateProfile(uid: String, profile: UserProfile) async throws {
    try await repository.updateProfile(uid: uid, profile: profile)
  }

  public func deleteProfile(uid: String) async throws {
    try await repository.deleteProfile(uid: uid)
  }
}
