import ComposableArchitecture
import Foundation

// MARK: - Types

/// 프로필 조회 대상
public enum UserTarget: Equatable, Sendable {
  /// 본인
  case me
  /// 특정 사용자
  case user(String)
}

/// 프로필 조회 결과
public enum UserProfile: Equatable, Sendable {
  /// 비공개 프로필 (본인 정보, email/provider 포함)
  case `private`(UserPrivateModel)
  /// 공개 프로필 (타인 정보, email/provider 제외)
  case `public`(UserPublicModel)

  /// 공개 프로필로 변환
  public var asPublic: UserPublicModel {
    switch self {
    case .private(let user):
      return user.toPublic()
    case .public(let user):
      return user
    }
  }

  /// 비공개 프로필로 변환 (공개 프로필인 경우 nil)
  public var asPrivate: UserPrivateModel? {
    switch self {
    case .private(let user):
      return user
    case .public:
      return nil
    }
  }
}

// MARK: - Client

@DependencyClient
public struct UserProfileClient: Sendable {
  /// 프로필 이미지와 함께 사용자 생성 (회원가입 전체 플로우)
  /// - Parameters:
  ///   - name: 실명 (nil이면 닉네임으로 대체됨)
  ///   - nickname: 닉네임
  ///   - providerType: OAuth 제공자 타입
  ///   - providerUid: OAuth 제공자 UID
  ///   - email: 이메일
  ///   - profileImageData: 프로필 이미지 (선택)
  /// - Returns: 생성된 사용자 프로필
  public var createUserWithProfile: @Sendable (
    _ name: String?,
    _ nickname: String,
    _ providerType: String,
    _ providerUid: String,
    _ email: String,
    _ profileImageData: Data?
  ) async throws -> UserPrivateModel

  /// 비공개 프로필 조회 (email/provider 포함, 2회 읽기)
  /// - Parameter target: 조회 대상 (.me: 본인, .user(id): 특정 사용자)
  /// - Returns: 비공개 프로필
  public var getPrivateProfile: @Sendable (_ target: UserTarget) async throws -> UserPrivateModel

  /// 공개 프로필 조회 (email/provider 제외, 1회 읽기)
  /// - Parameter target: 조회 대상 (.me: 본인, .user(id): 특정 사용자)
  /// - Returns: 공개 프로필
  public var getPublicProfile: @Sendable (_ target: UserTarget) async throws -> UserPublicModel

  /// 여러 사용자의 공개 프로필 배치 조회
  /// - Parameter userIds: 사용자 ID 목록
  /// - Returns: 공개 프로필 배열 (조회 실패한 사용자는 제외됨)
  public var getUsersByIds: @Sendable (_ userIds: [String]) async throws -> [UserPublicModel]

  /// 닉네임 사용 가능 여부 확인
  /// - Parameter nickname: 확인할 닉네임
  /// - Returns: 사용 가능 여부
  public var isNicknameAvailable: @Sendable (_ nickname: String) async throws -> Bool

  /// 프로필 업데이트
  /// - Parameter nickname: 변경할 닉네임
  public var updateProfile: @Sendable (_ nickname: String) async throws -> Void

  /// 프로필 이미지 업데이트
  /// - Parameter imageData: 새 프로필 이미지 데이터
  /// - Returns: 업로드된 이미지 URL
  public var updateProfileImage: @Sendable (_ imageData: Data) async throws -> URL

  /// 사용자 설정 조회
  /// - Returns: 사용자 설정
  public var getUserSettings: @Sendable () async throws -> UserSettings
}

// MARK: - Test / Preview

extension UserProfileClient: TestDependencyKey {
  public static let previewValue = Self(
    createUserWithProfile: { name, nickname, _, _, email, _ in
      UserPrivateModel(
        userId: "preview-user-id",
        name: name ?? nickname,
        nickname: nickname,
        email: email,
        provider: "google",
        profile: ProfileImage(
          url: "https://example.com/profile.jpg",
          thumbUrl: nil,
          updatedAt: Date()
        ),
        metadata: Metadata(createdAt: Date(), updatedAt: Date())
      )
    },
    getPrivateProfile: { target in
      switch target {
      case .me:
        return UserPrivateModel(
          userId: "preview-uid",
          name: "김민수",
          nickname: "kms",
          email: "minsu@example.com",
          provider: "google",
          profile: ProfileImage(
            url: "https://example.com/profile.jpg",
            thumbUrl: nil,
            updatedAt: Date()
          ),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      case .user(let userId):
        return UserPrivateModel(
          userId: userId,
          name: "이영희",
          nickname: "yhlee",
          email: "yhlee@example.com",
          provider: "google",
          profile: ProfileImage(
            url: "https://example.com/profile2.jpg",
            thumbUrl: nil,
            updatedAt: Date()
          ),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      }
    },
    getPublicProfile: { target in
      switch target {
      case .me:
        return UserPublicModel(
          userId: "preview-uid",
          name: "김민수",
          nickname: "kms",
          profile: ProfileImage(
            url: "https://example.com/profile.jpg",
            thumbUrl: nil,
            updatedAt: Date()
          ),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      case .user(let userId):
        return UserPublicModel(
          userId: userId,
          name: "이영희",
          nickname: "yhlee",
          profile: ProfileImage(
            url: "https://example.com/profile2.jpg",
            thumbUrl: nil,
            updatedAt: Date()
          ),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      }
    },
    getUsersByIds: { userIds in
      return userIds.enumerated().map { index, userId in
        UserPublicModel(
          userId: userId,
          name: "사용자\(index + 1)",
          nickname: "user\(index + 1)",
          profile: ProfileImage(
            url: "https://example.com/profile\(index + 1).jpg",
            thumbUrl: nil,
            updatedAt: Date()
          ),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      }
    },
    isNicknameAvailable: { _ in true },
    updateProfile: { _ in },
    updateProfileImage: { _ in
      URL(string: "https://storage.googleapis.com/example.jpg")!
    },
    getUserSettings: {
      UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
    }
  )

  public static let testValue = Self(
    createUserWithProfile: unimplemented("\(Self.self).createUserWithProfile"),
    getPrivateProfile: unimplemented("\(Self.self).getPrivateProfile"),
    getPublicProfile: unimplemented("\(Self.self).getPublicProfile"),
    getUsersByIds: unimplemented("\(Self.self).getUsersByIds", placeholder: []),
    isNicknameAvailable: unimplemented("\(Self.self).isNicknameAvailable", placeholder: true),
    updateProfile: unimplemented("\(Self.self).updateProfile"),
    updateProfileImage: unimplemented("\(Self.self).updateProfileImage"),
    getUserSettings: unimplemented("\(Self.self).getUserSettings")
  )
}

// MARK: - Live

extension UserProfileClient: DependencyKey {
  public static let liveValue: UserProfileClient = {
    @Dependency(\.authClient) var authClient
    let rustDataSource = UserRustDataSource(
      api: RustAPIClient()
    )
    let rustSettingsDataSource = UserSettingsRustDataSource(
      api: RustAPIClient()
    )

    return Self(
      createUserWithProfile: { name, nickname, providerType, providerUid, email, profileImageData in
        _ = try await rustDataSource.createUser(
          name: name,
          nickname: nickname,
          providerType: providerType,
          providerUid: providerUid,
          email: email
        )

        if let imageData = profileImageData {
          _ = try await rustDataSource.uploadProfileImageData(imageData)
        }

        return try await rustDataSource.getMyProfile()
      },

      getPrivateProfile: { target in
        switch target {
        case .me:
          return try await rustDataSource.getMyProfile()
        case .user:
          throw UserProfileError.permissionDenied
        }
      },

      getPublicProfile: { target in
        switch target {
        case .me:
          let private_ = try await rustDataSource.getMyProfile()
          return private_.toPublic()
        case .user(let userId):
          return try await rustDataSource.getUserPublic(userId: userId)
        }
      },

      getUsersByIds: { userIds in
        return try await rustDataSource.getUsersByIds(userIds)
      },

      isNicknameAvailable: { nickname in
        return try await rustDataSource.checkNicknameAvailable(nickname)
      },

      updateProfile: { nickname in
        try await rustDataSource.updateNickname(nickname)
      },

      updateProfileImage: { imageData in
        return try await rustDataSource.uploadProfileImageData(imageData)
      },

      getUserSettings: {
        guard let currentUser = await authClient.currentUser() else {
          throw UserProfileError.authenticationRequired
        }
        return try await rustSettingsDataSource.fetchSettings(userId: currentUser.uid)
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
