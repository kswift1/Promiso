import Foundation

// MARK: - User Protocols

/// 사용자 식별 정보
public protocol UserIdentifiable {
  var userId: String { get }
}

/// 사용자 기본 정보
public protocol UserBasicInfo: UserIdentifiable {
  var name: String { get }
  var nickname: String { get }
}

/// 사용자 프로필 이미지 정보
public protocol UserProfileInfo {
  var profile: ProfileImage? { get }
}

/// 사용자 메타데이터
public protocol UserMetadataInfo {
  var metadata: Metadata { get }
}

/// 공개 사용자 정보 (타인 조회 시)
public protocol UserPublicInfo: UserBasicInfo, UserProfileInfo, UserMetadataInfo {
}

/// 비공개 사용자 정보 (본인 조회 시)
public protocol UserPrivateInfo: UserPublicInfo {
  var email: String { get }
  var provider: String { get }
}

// MARK: - ProfileImage

/// 프로필 이미지 정보
public struct ProfileImage: Codable, Equatable, Hashable, Sendable {
  /// 원본 이미지 URL
  public let url: String

  /// 썸네일 URL
  public let thumbUrl: String?

  /// 업데이트 시각
  public let updatedAt: Date

  public init(url: String, thumbUrl: String? = nil, updatedAt: Date = Date()) {
    self.url = url
    self.thumbUrl = thumbUrl
    self.updatedAt = updatedAt
  }
}

// MARK: - Metadata

/// 사용자 메타데이터
public struct Metadata: Codable, Equatable, Hashable, Sendable {
  /// 생성 시각
  public let createdAt: Date

  /// 수정 시각
  public let updatedAt: Date

  public init(createdAt: Date = Date(), updatedAt: Date = Date()) {
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - GroupRole

/// 그룹 내 사용자 역할
public enum GroupRole: String, Codable, Equatable, Hashable, Sendable {
  /// 그룹 관리자 (생성자)
  case admin
  /// 일반 멤버
  case member
}

// MARK: - UserGroupInfo

/// 사용자별 그룹 정보 (users/{userId}.groups Map의 값)
public struct UserGroupInfo: Codable, Equatable, Hashable, Sendable {
  /// 그룹 이름 (캐시)
  public let groupName: String

  /// 사용자 역할
  public let role: GroupRole

  /// 그룹 가입 시각
  public let joinedAt: Date

  /// 알림 활성화 여부
  public let notifications: Bool

  public init(
    groupName: String,
    role: GroupRole,
    joinedAt: Date = Date(),
    notifications: Bool = true
  ) {
    self.groupName = groupName
    self.role = role
    self.joinedAt = joinedAt
    self.notifications = notifications
  }
}

// MARK: - UserPublicModel

/// 공개 사용자 정보 모델 (타인 조회용)
public struct UserPublicModel: UserPublicInfo, Identifiable, Equatable, Hashable, Sendable {
  public let userId: String
  public let name: String
  public let nickname: String
  public let profile: ProfileImage?
  public let metadata: Metadata

  public var id: String { userId }

  public init(
    userId: String,
    name: String,
    nickname: String,
    profile: ProfileImage? = nil,
    metadata: Metadata
  ) {
    self.userId = userId
    self.name = name
    self.nickname = nickname
    self.profile = profile
    self.metadata = metadata
  }
}

// MARK: - UserPrivateModel

/// 비공개 사용자 정보 모델 (본인 조회용)
public struct UserPrivateModel: UserPrivateInfo, Identifiable, Equatable, Hashable, Sendable {
  public let userId: String
  public let name: String
  public let nickname: String
  public let profile: ProfileImage?
  public let metadata: Metadata
  public let email: String
  public let provider: String
  /// 사용자가 속한 그룹 목록 (groupId -> UserGroupInfo)
  public let groups: [String: UserGroupInfo]

  public var id: String { userId }

  public init(
    userId: String,
    name: String,
    nickname: String,
    email: String,
    provider: String,
    profile: ProfileImage? = nil,
    metadata: Metadata,
    groups: [String: UserGroupInfo] = [:]
  ) {
    self.userId = userId
    self.name = name
    self.nickname = nickname
    self.email = email
    self.provider = provider
    self.profile = profile
    self.metadata = metadata
    self.groups = groups
  }
}

// MARK: - UserModel (Type Alias for Compatibility)

// MARK: - Common Extensions

extension UserPublicInfo {
  /// 사용자의 표시 이름 (닉네임)
  public var displayName: String {
    nickname
  }

  /// 프로필 이미지 URL (썸네일 우선)
  public var profileImageUrl: String? {
    profile?.thumbUrl ?? profile?.url
  }
}

// MARK: - Validation (Shared Logic)

extension UserPublicModel {
  /// 닉네임 유효성 검증 (도메인 로직)
  /// - Parameter nickname: 검증할 닉네임
  /// - Returns: 유효하지 않으면 에러, 유효하면 nil
  public static func validateNickname(_ nickname: String) -> NicknameValidationError? {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.count < 2 {
      return .tooShort(minimum: 2)
    }

    if trimmed.count > 12 {
      return .tooLong(maximum: 12)
    }

    if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
      return .containsWhitespace
    }

    if trimmed != nickname {
      return .hasLeadingOrTrailingWhitespace
    }

    return nil  // 유효함
  }

  /// 닉네임 유효성 검증 에러
  public enum NicknameValidationError: Error, Equatable {
    case tooShort(minimum: Int)
    case tooLong(maximum: Int)
    case containsWhitespace
    case hasLeadingOrTrailingWhitespace

    /// 사용자에게 표시할 에러 메시지
    public var message: String {
      switch self {
      case .tooShort(let min):
        return "\(min)자 이상 입력해주세요"
      case .tooLong(let max):
        return "\(max)자 이하로 입력해주세요"
      case .containsWhitespace:
        return "닉네임엔 공백을 넣을 수 없어요"
      case .hasLeadingOrTrailingWhitespace:
        return "앞뒤 공백 없이 입력해주세요"
      }
    }
  }
}

// MARK: - Conversion Extensions

extension UserPrivateModel {
  /// UserPrivateModel → UserPublicModel 변환 (이메일 제거)
  public func toPublic() -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: name,
      nickname: nickname,
      profile: profile,
      metadata: metadata
    )
  }

  /// groups Map을 GroupSummary 배열로 변환 (joinedAt 내림차순 정렬)
  public var groupSummaries: [GroupSummary] {
    groups.map { (groupId, info) in
      GroupSummary(
        id: groupId,
        name: info.groupName,
        role: info.role,
        joinedAt: info.joinedAt,
        notifications: info.notifications
      )
    }.sorted { ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast) }
  }
}
