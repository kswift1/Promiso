import Foundation

// MARK: - User Domain Model

public struct UserModel: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let email: String
  public let nickname: String
  public let pinnedGroupId: String?
  public let profileImageUrl: String?
  public let profileType: ProfileType
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
    self.notificationEnabled = notificationEnabled
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - ProfileType

public enum ProfileType: String, Codable, Equatable, Hashable, Sendable {
  case url = "URL"
  case firebase = "FIREBASE"
}

// MARK: - User Extensions
extension UserModel {
  /// 사용자의 표시 이름 (닉네임 우선, 없으면 이메일)
  public var displayName: String {
    return nickname.isEmpty ? email : nickname
  }
  
  /// 사용자의 이니셜
  public var initials: String {
    let components = nickname.components(separatedBy: .whitespacesAndNewlines)
    let initials = components.compactMap { $0.first }.map(String.init)
    return initials.prefix(2).joined()
  }
}
