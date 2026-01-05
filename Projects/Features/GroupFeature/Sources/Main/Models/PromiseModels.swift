import Foundation

import PromisoShared

// MARK: - Current Group

public struct CurrentGroup: Equatable, Sendable {
  public let id: String
  public let name: String
  public let emoji: String
  public let activeCount: Int
  public let pendingCount: Int
  public let role: GroupRole
  public let notifications: Bool
  public let members: [GroupMember]

  public init(
    id: String,
    name: String,
    emoji: String,
    activeCount: Int,
    pendingCount: Int,
    role: GroupRole,
    notifications: Bool,
    members: [GroupMember]
  ) {
    self.id = id
    self.name = name
    self.emoji = emoji
    self.activeCount = activeCount
    self.pendingCount = pendingCount
    self.role = role
    self.notifications = notifications
    self.members = members
  }
}

// MARK: - Group Role

public enum GroupRole: String, Equatable, Sendable {
  case admin
  case member

  var displayText: String {
    switch self {
    case .admin: return "관리자"
    case .member: return "멤버"
    }
  }
}

// MARK: - Group Member

public struct GroupMember: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let emoji: String
  public let role: GroupRole
  public let isMe: Bool

  public init(
    id: String,
    name: String,
    emoji: String,
    role: GroupRole,
    isMe: Bool
  ) {
    self.id = id
    self.name = name
    self.emoji = emoji
    self.role = role
    self.isMe = isMe
  }
}

// MARK: - Status Filter

public enum StatusFilter: String, CaseIterable, Equatable, Sendable {
  case all = "전체"
  case needResponse = "응답 필요"
  case responded = "응답 완료"
}
