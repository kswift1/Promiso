import Foundation

public struct CreateGroupRequest: Equatable, Sendable {
  public let name: String
  public let maxMembers: Int
  public let creatorId: String
  public let creatorName: String
  public let creatorNickname: String
  public let creatorProfileImageURL: String?
  public let photoData: Data?
  
  public init(
    name: String,
    maxMembers: Int,
    creatorId: String,
    creatorName: String,
    creatorNickname: String,
    creatorProfileImageURL: String?,
    photoData: Data?
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.creatorId = creatorId
    self.creatorName = creatorName
    self.creatorNickname = creatorNickname
    self.creatorProfileImageURL = creatorProfileImageURL
    self.photoData = photoData
  }
}
