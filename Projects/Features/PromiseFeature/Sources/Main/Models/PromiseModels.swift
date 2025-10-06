import Foundation

// MARK: - Promise Status

public enum PromiseStatus: String, Equatable, Sendable {
  case needResponse  // 답변 필요
  case confirmed     // 확정됨
  case sent          // 응답 대기

  var displayText: String {
    switch self {
    case .needResponse: return "답변 필요"
    case .confirmed: return "확정됨"
    case .sent: return "응답 대기"
    }
  }

  var color: String {
    switch self {
    case .needResponse: return "orange"
    case .confirmed: return "green"
    case .sent: return "blue"
    }
  }

  var iconName: String {
    switch self {
    case .needResponse: return "exclamationmark.circle.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .sent: return "paperplane.fill"
    }
  }
}

// MARK: - Promise Response

public struct PromiseResponse: Equatable, Sendable {
  public let current: Int
  public let total: Int

  public init(current: Int, total: Int) {
    self.current = current
    self.total = total
  }
}

// MARK: - Promise Item

public struct PromiseItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let emoji: String
  public let time: String
  public let date: String
  public let location: String
  public let distance: String?
  public let with: String
  public let status: PromiseStatus
  public let responses: PromiseResponse?
  public let deadline: String?

  public init(
    id: String,
    title: String,
    emoji: String,
    time: String,
    date: String,
    location: String,
    distance: String? = nil,
    with: String,
    status: PromiseStatus,
    responses: PromiseResponse? = nil,
    deadline: String? = nil
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.time = time
    self.date = date
    self.location = location
    self.distance = distance
    self.with = with
    self.status = status
    self.responses = responses
    self.deadline = deadline
  }
}

// MARK: - Current Group

public struct CurrentGroup: Equatable, Sendable {
  public let id: String
  public let name: String
  public let emoji: String
  public let activeCount: Int
  public let pendingCount: Int
  public let memberCount: Int
  public let role: GroupRole
  public let notifications: Bool

  public init(
    id: String,
    name: String,
    emoji: String,
    activeCount: Int,
    pendingCount: Int,
    memberCount: Int,
    role: GroupRole,
    notifications: Bool
  ) {
    self.id = id
    self.name = name
    self.emoji = emoji
    self.activeCount = activeCount
    self.pendingCount = pendingCount
    self.memberCount = memberCount
    self.role = role
    self.notifications = notifications
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
  case confirmed = "확정됨"
}
