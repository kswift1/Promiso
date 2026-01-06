import Foundation
import PromisoShared

public struct GroupPreview: Equatable, Sendable {
  public let group: GroupModel
  public let members: [UserPublic]

  public init(
    group: GroupModel,
    members: [UserPublic]
  ) {
    self.group = group
    self.members = members
  }
}
