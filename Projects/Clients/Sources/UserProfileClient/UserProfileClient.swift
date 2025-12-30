import ComposableArchitecture
import Foundation
import Shared

// MARK: - Client

@DependencyClient
public struct UserProfileClient: Sendable {
  /// 사용자 프로필을 저장소에 저장 (Adapter가 Shared Model 반환)
  public var saveProfile: @Sendable (_ uid: String, _ profile: UserProfile) async throws -> UserModel

  /// 프로필 저장 + 이미지 처리 (Adapter가 Shared Model 반환)
  public var saveProfileWithImage: @Sendable (
    _ uid: String,
    _ profile: UserProfile,
    _ imageInput: UserProfileImageInput
  ) async throws -> UserModel

  /// 사용자 프로필을 저장소에서 가져오기 (Adapter가 Shared Model 반환)
  public var getProfile: @Sendable (_ uid: String) async throws -> UserModel?

  /// 프로필 이미지 업로드
  public var uploadProfileImage: @Sendable (_ uid: String, _ imageData: Data) async throws -> URL

  /// 프로필을 반환 (없으면 nil) (Adapter가 Shared Model 반환)
  public var hasProfile: @Sendable (_ uid: String) async throws -> UserModel?

  /// 닉네임 사용 가능 여부 확인
  public var isNicknameAvailable: @Sendable (_ nickname: String) async throws -> Bool

  /// 사용자 프로필 업데이트 (Adapter가 Shared Model 반환)
  public var updateProfile: @Sendable (_ uid: String, _ profile: UserProfile) async throws -> UserModel

  /// 사용자 프로필 삭제
  public var deleteProfile: @Sendable (_ uid: String) async throws -> Void
}

// MARK: - Test / Preview

extension UserProfileClient: TestDependencyKey {
  public static let previewValue = Self(
    saveProfile: { uid, profile in
      profile.toUserModel(uid: uid)
    },
    saveProfileWithImage: { uid, profile, _ in
      profile.toUserModel(uid: uid)
    },
    getProfile: { uid in
      let profile = UserProfile(
        name: "김민수",
        nickname: "kms",
        email: "minsu@example.com",
        provider: .init(uid: "preview-provider", type: "google"),
        profile: .init(type: .storagePath, url: "profile_images/preview.jpg")
      )
      return profile.toUserModel(uid: uid)
    },
    uploadProfileImage: { _, _ in
      URL(string: "https://storage.googleapis.com/example.jpg")!
    },
    hasProfile: { _ in nil },
    isNicknameAvailable: { _ in true },
    updateProfile: { uid, profile in
      profile.toUserModel(uid: uid)
    },
    deleteProfile: { _ in }
  )

  public static let testValue = Self(
    saveProfile: unimplemented("\(Self.self).saveProfile"),
    saveProfileWithImage: unimplemented("\(Self.self).saveProfileWithImage"),
    getProfile: unimplemented("\(Self.self).getProfile", placeholder: nil),
    uploadProfileImage: unimplemented("\(Self.self).uploadProfileImage"),
    hasProfile: unimplemented("\(Self.self).hasProfile", placeholder: nil),
    isNicknameAvailable: unimplemented("\(Self.self).isNicknameAvailable", placeholder: true),
    updateProfile: unimplemented("\(Self.self).updateProfile"),
    deleteProfile: unimplemented("\(Self.self).deleteProfile")
  )
}

// MARK: - Live

extension UserProfileClient: DependencyKey {
  public static let liveValue: UserProfileClient = {
    let dataSource = UserProfileRemoteDataSource()

    return Self(
      saveProfile: { uid, profile in
        try await dataSource.saveProfile(uid: uid, profile: profile)
        return profile.toUserModel(uid: uid)
      },
      saveProfileWithImage: { uid, profile, imageInput in
        try await dataSource.saveProfileWithImage(
          uid: uid,
          profile: profile,
          imageInput: imageInput
        )
      },

      getProfile: { uid in
        try await dataSource.getProfileModel(uid: uid)
      },

      uploadProfileImage: { uid, imageData in
        try await dataSource.uploadProfileImage(uid: uid, imageData: imageData)
      },

      hasProfile: { uid in
        try await dataSource.hasProfileModel(uid: uid)
      },

      isNicknameAvailable: { nickname in
        try await dataSource.isNicknameAvailable(nickname)
      },

      updateProfile: { uid, profile in
        try await dataSource.updateProfile(uid: uid, profile: profile)
        return profile.toUserModel(uid: uid)
      },

      deleteProfile: { uid in
        try await dataSource.deleteProfile(uid: uid)
      }
    )
  }()
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var userProfileClient: UserProfileClient {
    get { self[UserProfileClient.self] }
    set { self[UserProfileClient.self] = newValue }
  }
}
