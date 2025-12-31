import Foundation
import FirebaseFirestore
import FirebaseStorage
import Shared

/// Firebase를 통한 사용자 프로필 데이터 관리
public final class UserProfileRemoteDataSource: @unchecked Sendable {
  private let db: Firestore
  private let storage: Storage

  public init(
    db: Firestore = Firestore.firestore(),
    storage: Storage = Storage.storage()
  ) {
    self.db = db
    self.storage = storage
  }

  public func saveProfile(uid: String, profile: UserProfile) async throws {
    let data = profile.toFirestoreData()
    try await
    db.environmentCollection("users").document(uid).setData(data, merge: true)
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
          _ = try await uploadProfileImage(uid: uid, imageData: imageData)
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

      try await saveProfile(uid: uid, profile: finalProfile)
      return finalProfile.toUserModel(uid: uid)
    } catch {
      if didUploadImage {
        try? await deleteProfileImage(uid: uid)
      }
      throw error
    }
  }

  public func getProfile(uid: String) async throws -> UserProfile? {
    let document = try await db.environmentCollection("users").document(uid).getDocument()

    guard document.exists, let data = document.data() else {
      return nil
    }

    return try UserProfile.fromFirestoreData(data)
  }

  public func getProfileModel(uid: String) async throws -> UserModel? {
    guard let profile = try await getProfile(uid: uid) else {
      return nil
    }
    return profile.toUserModel(uid: uid)
  }

  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    let profileImageRef = storage.reference().child("profile_images/\(uid).jpg")

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    let uploadData = compressImageDataForUpload(imageData) ?? imageData
    _ = try await profileImageRef.putDataAsync(uploadData, metadata: metadata)
    return try await profileImageRef.downloadURL()
  }

  public func deleteProfileImage(uid: String) async throws {
    let profileImageRef = storage.reference().child("profile_images/\(uid).jpg")
    try await profileImageRef.delete()
  }

  public func hasProfile(uid: String) async throws -> UserProfile? {
    try await getProfile(uid: uid)
  }

  public func hasProfileModel(uid: String) async throws -> UserModel? {
    guard let profile = try await getProfile(uid: uid) else {
      return nil
    }
    return profile.toUserModel(uid: uid)
  }

  public func isNicknameAvailable(_ nickname: String) async throws -> Bool {
    let snapshot = try await db.environmentCollection("users")
      .whereField("nickname", isEqualTo: nickname)
      .limit(to: 1)
      .getDocuments()
    return snapshot.documents.isEmpty
  }

  public func updateProfile(uid: String, profile: UserProfile) async throws {
    let updatedProfile = UserProfile(
      name: profile.name,
      nickname: profile.nickname,
      email: profile.email,
      provider: profile.provider,
      profile: profile.profile,
      pinnedGroupId: profile.pinnedGroupId,
      notificationSettings: profile.notificationSettings,
      createdAt: profile.createdAt,
      updatedAt: Date()
    )

    let data = updatedProfile.toFirestoreData()
    try await db.environmentCollection("users").document(uid).updateData(data)
  }

  public func deleteProfile(uid: String) async throws {
    try await db.environmentCollection("users").document(uid).delete()
    try? await deleteProfileImage(uid: uid)
  }
}

// MARK: - StorageReference Extension

private extension StorageReference {
  func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
    try await withCheckedThrowingContinuation { continuation in
      putData(data, metadata: metadata) { metadata, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let metadata {
          continuation.resume(returning: metadata)
        } else {
          continuation.resume(throwing: UserProfileError.uploadFailed)
        }
      }
    }
  }
}
