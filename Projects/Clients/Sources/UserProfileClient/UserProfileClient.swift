import ComposableArchitecture
import Foundation

// MARK: - Client

@DependencyClient
public struct UserProfileClient: Sendable {
  /// 사용자 프로필을 저장소에 저장
  public var saveProfile: @Sendable (_ uid: String, _ profile: UserProfile) async throws -> Void

  /// 사용자 프로필을 저장소에서 가져오기
  public var getProfile: @Sendable (_ uid: String) async throws -> UserProfile?

  /// 프로필 이미지 업로드
  public var uploadProfileImage: @Sendable (_ uid: String, _ imageData: Data) async throws -> URL

  /// 프로필이 존재하는지 확인
  public var hasProfile: @Sendable (_ uid: String) async throws -> Bool

  /// 사용자 프로필 업데이트
  public var updateProfile: @Sendable (_ uid: String, _ profile: UserProfile) async throws -> Void

  /// 사용자 프로필 삭제
  public var deleteProfile: @Sendable (_ uid: String) async throws -> Void
}

// MARK: - Test / Preview

extension UserProfileClient: TestDependencyKey {
  public static let previewValue = Self(
    saveProfile: { _, _ in },
    getProfile: { _ in
      UserProfile(
        name: "김민수",
        nickname: "kms",
        email: "minsu@example.com",
        profileType: .url,
        profileImageUrl: "https://storage.googleapis.com/example.jpg"
      )
    },
    uploadProfileImage: { _, _ in
      URL(string: "https://storage.googleapis.com/example.jpg")!
    },
    hasProfile: { _ in true },
    updateProfile: { _, _ in },
    deleteProfile: { _ in }
  )

  public static let testValue = Self(
    saveProfile: unimplemented("\(Self.self).saveProfile"),
    getProfile: unimplemented("\(Self.self).getProfile", placeholder: nil),
    uploadProfileImage: unimplemented("\(Self.self).uploadProfileImage"),
    hasProfile: unimplemented("\(Self.self).hasProfile", placeholder: false),
    updateProfile: unimplemented("\(Self.self).updateProfile"),
    deleteProfile: unimplemented("\(Self.self).deleteProfile")
  )
}

// MARK: - Live

extension UserProfileClient: DependencyKey {
  public static let liveValue: UserProfileClient = {
    let repository: UserRepositoryProtocol = FirebaseUserRepository()

    return Self(
      saveProfile: { uid, profile in
        try await repository.saveProfile(uid: uid, profile: profile)
      },

      getProfile: { uid in
        try await repository.getProfile(uid: uid)
      },

      uploadProfileImage: { uid, imageData in
        try await repository.uploadProfileImage(uid: uid, imageData: imageData)
      },

      hasProfile: { uid in
        try await repository.hasProfile(uid: uid)
      },

      updateProfile: { uid, profile in
        try await repository.updateProfile(uid: uid, profile: profile)
      },

      deleteProfile: { uid in
        try await repository.deleteProfile(uid: uid)
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
