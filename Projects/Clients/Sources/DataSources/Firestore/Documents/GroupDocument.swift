import Foundation
import FirebaseFirestore
import PromisoShared

/// Firestore Groups 컬렉션 문서 모델
public struct GroupDocument: Codable {
  // MARK: - 기본 정보
  public let name: String
  public let description: String?
  public let emoji: String?
  public let themeColor: String?
  public let photo: RemoteImage?

  // MARK: - 멤버 관리
  public let memberIds: [String]

  // MARK: - 카운터 (캐시)
  public let memberCount: Int
  public let activePromiseCount: Int
  
  // MARK: - 설정
  public let maxMembers: Int?
  public let requireApproval: Bool
  public let defaultMinimumParticipants: Int
  
  // MARK: - 메타데이터
  public let inviteCode: String
  public let createdBy: String
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  public let isDeleted: Bool
  
  public init(
    name: String,
    description: String? = nil,
    emoji: String? = nil,
    themeColor: String? = nil,
    photo: RemoteImage? = nil,
    memberIds: [String] = [],
    memberCount: Int = 0,
    activePromiseCount: Int = 0,
    maxMembers: Int? = nil,
    requireApproval: Bool = false,
    defaultMinimumParticipants: Int = 2,
    inviteCode: String,
    createdBy: String,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp(),
    isDeleted: Bool = false
  ) {
    self.name = name
    self.description = description
    self.emoji = emoji
    self.themeColor = themeColor
    self.photo = photo
    self.memberIds = memberIds
    self.memberCount = memberCount
    self.activePromiseCount = activePromiseCount
    self.maxMembers = maxMembers
    self.requireApproval = requireApproval
    self.defaultMinimumParticipants = defaultMinimumParticipants
    self.inviteCode = inviteCode
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
  }
}

// MARK: - CodingKeys
extension GroupDocument {
  enum CodingKeys: String, CodingKey {
    case name
    case description
    case emoji
    case themeColor
    case photo
    case memberIds
    case memberCount
    case activePromiseCount
    case maxMembers
    case requireApproval
    case defaultMinimumParticipants
    case inviteCode
    case createdBy
    case createdAt
    case updatedAt
    case isDeleted
  }
}

// MARK: - Domain Mapping

extension GroupDocument {
  func toModel(id: String) -> GroupModel {
    let emojiValue = emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayEmoji = (emojiValue?.isEmpty == false) ? emojiValue! : "👥"

    return GroupModel(
      id: id,
      name: name,
      description: description,
      emoji: displayEmoji,
      themeColor: themeColor,
      photo: photo,
      memberCount: memberCount,
      activePromiseCount: activePromiseCount,
      maxMembers: maxMembers,
      requireApproval: requireApproval,
      defaultMinimumParticipants: defaultMinimumParticipants,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt.dateValue(),
      updatedAt: updatedAt.dateValue(),
      isDeleted: isDeleted
    )
  }
}
