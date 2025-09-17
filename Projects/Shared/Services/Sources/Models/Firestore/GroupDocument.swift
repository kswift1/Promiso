import Foundation
import FirebaseFirestore

/// Firestore Groups 컬렉션 문서 모델
public struct GroupDocument: Codable {
  // MARK: - 기본 정보
  public let name: String
  public let description: String?
  public let emoji: String?
  public let themeColor: String?
  
  // MARK: - 카운터 (캐시)
  public let memberCount: Int
  public let activePromiseCount: Int
  
  // MARK: - 설정
  public let maxMembers: Int?
  public let requireApproval: Bool
  public let defaultMinimumParticipants: Int
  
  // MARK: - 메타데이터
  public let createdBy: String
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  public let isDeleted: Bool
  
  public init(
    name: String,
    description: String? = nil,
    emoji: String? = nil,
    themeColor: String? = nil,
    memberCount: Int = 0,
    activePromiseCount: Int = 0,
    maxMembers: Int? = nil,
    requireApproval: Bool = false,
    defaultMinimumParticipants: Int = 2,
    createdBy: String,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp(),
    isDeleted: Bool = false
  ) {
    self.name = name
    self.description = description
    self.emoji = emoji
    self.themeColor = themeColor
    self.memberCount = memberCount
    self.activePromiseCount = activePromiseCount
    self.maxMembers = maxMembers
    self.requireApproval = requireApproval
    self.defaultMinimumParticipants = defaultMinimumParticipants
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
    case memberCount
    case activePromiseCount
    case maxMembers
    case requireApproval
    case defaultMinimumParticipants
    case createdBy
    case createdAt
    case updatedAt
    case isDeleted
  }
}
