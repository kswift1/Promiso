import Foundation

// MARK: - GroupClient Response Models

/// 그룹 생성 결과 모델
/// GroupClient.createGroup의 반환 타입
public struct GroupCreationResultModel: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let inviteCode: String

  public init(
    id: String,
    name: String,
    inviteCode: String
  ) {
    self.id = id
    self.name = name
    self.inviteCode = inviteCode
  }
}

/// 그룹 미리보기 모델
/// 초대 코드로 그룹 참여 전 미리보기용
public struct GroupPreviewModel: Equatable, Sendable {
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
