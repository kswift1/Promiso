import Foundation

// MARK: - Group Model

/// 그룹 정보를 나타내는 도메인 모델
public struct Group: Equatable, Codable, Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public let description: String?
  public let imageURL: String?
  public let createdBy: UUID // User ID
  public let createdAt: Date
  public let updatedAt: Date
  public let memberCount: Int
  public let maxMembers: Int?
  public let isPrivate: Bool
  public let inviteCode: String?
  public let status: GroupStatus
  public let settings: GroupSettings
  
  public init(
    id: UUID = UUID(),
    name: String,
    description: String? = nil,
    imageURL: String? = nil,
    createdBy: UUID,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    memberCount: Int = 1,
    maxMembers: Int? = nil,
    isPrivate: Bool = false,
    inviteCode: String? = nil,
    status: GroupStatus = .active,
    settings: GroupSettings = GroupSettings()
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.imageURL = imageURL
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.memberCount = memberCount
    self.maxMembers = maxMembers
    self.isPrivate = isPrivate
    self.inviteCode = inviteCode
    self.status = status
    self.settings = settings
  }
}

// MARK: - Group Status

/// 그룹 상태
public enum GroupStatus: String, CaseIterable, Codable, Sendable {
  case active = "active"
  case inactive = "inactive"
  case archived = "archived"
  case deleted = "deleted"
  
  public var displayName: String {
    switch self {
    case .active: return "활성"
    case .inactive: return "비활성"
    case .archived: return "보관됨"
    case .deleted: return "삭제됨"
    }
  }
  
  public var isActive: Bool {
    self == .active
  }
}

// MARK: - Group Settings

/// 그룹 설정
public struct GroupSettings: Equatable, Codable, Sendable {
  public let allowMemberInvites: Bool
  public let requireApprovalForJoin: Bool
  public let allowPromiseCreation: Bool
  public let notificationsEnabled: Bool
  public let autoDeleteExpiredPromises: Bool
  public let defaultPromiseVisibility: PromiseVisibility
  
  public init(
    allowMemberInvites: Bool = true,
    requireApprovalForJoin: Bool = false,
    allowPromiseCreation: Bool = true,
    notificationsEnabled: Bool = true,
    autoDeleteExpiredPromises: Bool = false,
    defaultPromiseVisibility: PromiseVisibility = .group
  ) {
    self.allowMemberInvites = allowMemberInvites
    self.requireApprovalForJoin = requireApprovalForJoin
    self.allowPromiseCreation = allowPromiseCreation
    self.notificationsEnabled = notificationsEnabled
    self.autoDeleteExpiredPromises = autoDeleteExpiredPromises
    self.defaultPromiseVisibility = defaultPromiseVisibility
  }
}

// MARK: - Group Member

/// 그룹 멤버 정보
public struct GroupMember: Equatable, Codable, Identifiable, Sendable {
  public let id: UUID
  public let groupId: UUID
  public let userId: UUID
  public let role: MemberRole
  public let joinedAt: Date
  public let nickname: String?
  public let status: MemberStatus
  public let permissions: MemberPermissions
  
  // 캐시된 사용자 정보 (옵셔널)
  public let user: User?
  
  public init(
    id: UUID = UUID(),
    groupId: UUID,
    userId: UUID,
    role: MemberRole = .member,
    joinedAt: Date = Date(),
    nickname: String? = nil,
    status: MemberStatus = .active,
    permissions: MemberPermissions = MemberPermissions(),
    user: User? = nil
  ) {
    self.id = id
    self.groupId = groupId
    self.userId = userId
    self.role = role
    self.joinedAt = joinedAt
    self.nickname = nickname
    self.status = status
    self.permissions = permissions
    self.user = user
  }
}

// MARK: - Member Role

/// 멤버 역할
public enum MemberRole: String, CaseIterable, Codable, Sendable {
  case owner = "owner"
  case admin = "admin"
  case moderator = "moderator"
  case member = "member"
  
  public var displayName: String {
    switch self {
    case .owner: return "소유자"
    case .admin: return "관리자"
    case .moderator: return "모더레이터"
    case .member: return "멤버"
    }
  }
  
  public var priority: Int {
    switch self {
    case .owner: return 4
    case .admin: return 3
    case .moderator: return 2
    case .member: return 1
    }
  }
  
  public var canManageGroup: Bool {
    priority >= 3
  }
  
  public var canManageMembers: Bool {
    priority >= 2
  }
}

// MARK: - Member Status

/// 멤버 상태
public enum MemberStatus: String, CaseIterable, Codable, Sendable {
  case active = "active"
  case inactive = "inactive"
  case banned = "banned"
  case left = "left"
  
  public var displayName: String {
    switch self {
    case .active: return "활성"
    case .inactive: return "비활성"
    case .banned: return "차단됨"
    case .left: return "탈퇴함"
    }
  }
  
  public var isActive: Bool {
    self == .active
  }
}

// MARK: - Member Permissions

/// 멤버 권한
public struct MemberPermissions: Equatable, Codable, Sendable {
  public let canCreatePromises: Bool
  public let canInviteMembers: Bool
  public let canRemoveMembers: Bool
  public let canEditGroupInfo: Bool
  public let canManageSettings: Bool
  public let canDeleteGroup: Bool
  
  public init(
    canCreatePromises: Bool = true,
    canInviteMembers: Bool = false,
    canRemoveMembers: Bool = false,
    canEditGroupInfo: Bool = false,
    canManageSettings: Bool = false,
    canDeleteGroup: Bool = false
  ) {
    self.canCreatePromises = canCreatePromises
    self.canInviteMembers = canInviteMembers
    self.canRemoveMembers = canRemoveMembers
    self.canEditGroupInfo = canEditGroupInfo
    self.canManageSettings = canManageSettings
    self.canDeleteGroup = canDeleteGroup
  }
  
  public static func permissions(for role: MemberRole) -> MemberPermissions {
    switch role {
    case .owner:
      return MemberPermissions(
        canCreatePromises: true,
        canInviteMembers: true,
        canRemoveMembers: true,
        canEditGroupInfo: true,
        canManageSettings: true,
        canDeleteGroup: true
      )
    case .admin:
      return MemberPermissions(
        canCreatePromises: true,
        canInviteMembers: true,
        canRemoveMembers: true,
        canEditGroupInfo: true,
        canManageSettings: true,
        canDeleteGroup: false
      )
    case .moderator:
      return MemberPermissions(
        canCreatePromises: true,
        canInviteMembers: true,
        canRemoveMembers: true,
        canEditGroupInfo: false,
        canManageSettings: false,
        canDeleteGroup: false
      )
    case .member:
      return MemberPermissions(
        canCreatePromises: true,
        canInviteMembers: false,
        canRemoveMembers: false,
        canEditGroupInfo: false,
        canManageSettings: false,
        canDeleteGroup: false
      )
    }
  }
}

// MARK: - Group Invitation

/// 그룹 초대
public struct GroupInvitation: Equatable, Codable, Identifiable, Sendable {
  public let id: UUID
  public let groupId: UUID
  public let invitedBy: UUID // User ID
  public let invitedUser: UUID? // User ID (이메일로 초대 시 nil)
  public let invitedEmail: String?
  public let message: String?
  public let createdAt: Date
  public let expiresAt: Date
  public let status: InvitationStatus
  
  public init(
    id: UUID = UUID(),
    groupId: UUID,
    invitedBy: UUID,
    invitedUser: UUID? = nil,
    invitedEmail: String? = nil,
    message: String? = nil,
    createdAt: Date = Date(),
    expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60), // 7일 후 만료
    status: InvitationStatus = .pending
  ) {
    self.id = id
    self.groupId = groupId
    self.invitedBy = invitedBy
    self.invitedUser = invitedUser
    self.invitedEmail = invitedEmail
    self.message = message
    self.createdAt = createdAt
    self.expiresAt = expiresAt
    self.status = status
  }
}

// MARK: - Invitation Status

/// 초대 상태
public enum InvitationStatus: String, CaseIterable, Codable, Sendable {
  case pending = "pending"
  case accepted = "accepted"
  case declined = "declined"
  case expired = "expired"
  case cancelled = "cancelled"
  
  public var displayName: String {
    switch self {
    case .pending: return "대기 중"
    case .accepted: return "수락됨"
    case .declined: return "거절됨"
    case .expired: return "만료됨"
    case .cancelled: return "취소됨"
    }
  }
  
  public var isPending: Bool {
    self == .pending
  }
}

// MARK: - Promise Visibility

/// 약속 공개 범위
public enum PromiseVisibility: String, CaseIterable, Codable, Sendable {
  case `private` = "private"
  case group = "group"
  case `public` = "public"
  
  public var displayName: String {
    switch self {
    case .private: return "비공개"
    case .group: return "그룹 내 공개"
    case .public: return "전체 공개"
    }
  }
}

// MARK: - Group Extensions

public extension Group {
  /// 그룹이 가득 찬지 확인
  var isFull: Bool {
    guard let maxMembers = maxMembers else { return false }
    return memberCount >= maxMembers
  }
  
  /// 그룹 가입 가능 여부
  var canJoin: Bool {
    status.isActive && !isFull
  }
  
  /// 공개 그룹인지 확인
  var isPublic: Bool {
    !isPrivate
  }
}

public extension GroupMember {
  /// 표시할 이름 (닉네임 우선, 없으면 사용자 이름)
  var displayName: String {
    nickname ?? user?.name ?? "Unknown User"
  }
  
  /// 멤버가 활성 상태인지 확인
  var isActive: Bool {
    status.isActive
  }
}

public extension GroupInvitation {
  /// 초대가 만료되었는지 확인
  var isExpired: Bool {
    Date() > expiresAt
  }
  
  /// 초대가 유효한지 확인
  var isValid: Bool {
    status.isPending && !isExpired
  }
}