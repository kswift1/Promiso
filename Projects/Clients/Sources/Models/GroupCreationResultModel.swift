import Foundation

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
