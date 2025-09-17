import Foundation

// MARK: - User Domain Model

public struct User: Identifiable, Equatable, Hashable {
  public let id: String
  public let email: String
  public let nickname: String
  public let profileImageUrl: String?
  
  public init(
    id: String,
    email: String,
    nickname: String,
    profileImageUrl: String? = nil
  ) {
    self.id = id
    self.email = email
    self.nickname = nickname
    self.profileImageUrl = profileImageUrl
  }
}

// MARK: - User Extensions
extension User {
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
