import Foundation
import PromisoShared

public struct GroupPreview: Equatable, Sendable {
  public let group: GroupModel
  public let members: [GroupMemberPreview]

  public init(
    group: GroupModel,
    members: [GroupMemberPreview]
  ) {
    self.group = group
    self.members = members
  }
}

//public struct GroupMemberPreview: Identifiable, Equatable, Sendable {
//  public let id: String
//  public let name: String
//  public let profileImage: RemoteImage?
//
//  public init(
//    userId: String,
//    name: String,
//    profileImage: RemoteImage?
//  ) {
//    self.id = userId
//    self.name = name
//    self.profileImage = profileImage
//  }
//}
