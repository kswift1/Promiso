import Foundation
import FirebaseFirestore
import PromisoShared

/// Firestore Groups 컬렉션 문서 모델
public struct GroupDocument: Codable {
  // MARK: - 기본 정보
  public let name: String
  public let description: String?
  public let imageUrl: String?

  // MARK: - 멤버 관리
  public let memberIds: [String]

  // MARK: - 카운터 (캐시)
  public let activePromiseCount: Int

  // MARK: - 설정
  public let maxMembers: Int

  // MARK: - 메타데이터
  public let inviteCode: String
  public let createdBy: String
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  public let isDeleted: Bool
  
  public init(
    name: String,
    description: String? = nil,
    imageUrl: String? = nil,
    memberIds: [String] = [],
    activePromiseCount: Int = 0,
    maxMembers: Int,
    inviteCode: String,
    createdBy: String,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp(),
    isDeleted: Bool = false
  ) {
    self.name = name
    self.description = description
    self.imageUrl = imageUrl
    self.memberIds = memberIds
    self.activePromiseCount = activePromiseCount
    self.maxMembers = maxMembers
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
    case imageUrl
    case memberIds
    case activePromiseCount
    case maxMembers
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
    return GroupModel(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      memberIds: memberIds,
      activePromiseCount: activePromiseCount,
      maxMembers: maxMembers,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt.dateValue(),
      updatedAt: updatedAt.dateValue(),
      isDeleted: isDeleted
    )
  }
}
