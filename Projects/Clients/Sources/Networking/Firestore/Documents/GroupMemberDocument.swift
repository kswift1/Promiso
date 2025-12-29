import Foundation
import FirebaseFirestore

public struct GroupMemberDocument: Codable {
  public let userId: String
  public let userName: String
  public let profileImageUrl: String?
  public let role: String
  public let nickname: String?
  public let joinedAt: Timestamp
  public let invitedBy: String
  
  public init(
    userId: String,
    userName: String,
    profileImageUrl: String?,
    role: String,
    nickname: String?,
    joinedAt: Timestamp,
    invitedBy: String
  ) {
    self.userId = userId
    self.userName = userName
    self.profileImageUrl = profileImageUrl
    self.role = role
    self.nickname = nickname
    self.joinedAt = joinedAt
    self.invitedBy = invitedBy
  }
}
