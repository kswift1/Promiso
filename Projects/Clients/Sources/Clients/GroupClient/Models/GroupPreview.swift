import Foundation
import PromisoShared

public struct GroupPreview: Equatable, Sendable {
  public let group: GroupModel
  public let members: [UserPublicModel]

  public init(
    group: GroupModel,
    members: [UserPublicModel]
  ) {
    self.group = group
    self.members = members
  }
}
