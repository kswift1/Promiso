import Foundation

// MARK: - User Shared Model

public struct UserModel: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let email: String
  public let nickname: String
  public let pinnedGroupId: String?
  public let profileImageUrl: String?
  public let profileType: ProfileType
  public let providerId: String?
  public let providerUid: String?
  public let providerType: String?
  public let notificationEnabled: Bool
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: String,
    email: String,
    nickname: String,
    pinnedGroupId: String? = nil,
    profileImageUrl: String? = nil,
    profileType: ProfileType = .firebase,
    providerId: String? = nil,
    providerUid: String? = nil,
    providerType: String? = nil,
    notificationEnabled: Bool = true,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.email = email
    self.nickname = nickname
    self.pinnedGroupId = pinnedGroupId
    self.profileImageUrl = profileImageUrl
    self.profileType = profileType
    self.providerId = providerId
    self.providerUid = providerUid
    self.providerType = providerType
    self.notificationEnabled = notificationEnabled
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - ProfileType

public enum ProfileType: String, Codable, Equatable, Hashable, Sendable {
  case url = "URL"
  case firebase = "FIREBASE"
  case none = "NONE"
}

// MARK: - User Extensions
extension UserModel {
  /// 사용자의 표시 이름 (닉네임 우선, 없으면 이메일)
  public var displayName: String {
    return nickname.isEmpty ? email : nickname
  }
}

// MARK: - Validation (Shared Logic)

extension UserModel {
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
