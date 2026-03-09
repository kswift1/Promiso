import Foundation

/// 그룹 미리보기 모델
/// 초대 코드로 그룹 참여 전 미리보기용
public struct GroupPreviewModel: Equatable, Sendable {
  public let group: GroupModel
  public let members: [UserPublicModel]
  public let memberCount: Int

  public init(
    group: GroupModel,
    members: [UserPublicModel],
    memberCount: Int? = nil
  ) {
    self.group = group
    self.members = members
    self.memberCount = memberCount ?? members.count
  }
}
