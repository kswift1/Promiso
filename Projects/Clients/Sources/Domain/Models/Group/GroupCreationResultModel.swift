import Foundation

/// 그룹 생성 결과 모델
public struct GroupCreationResultModel: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let inviteCode: String
  public let imageUploadFailed: Bool

  public init(
    id: String,
    name: String,
    inviteCode: String,
    imageUploadFailed: Bool = false
  ) {
    self.id = id
    self.name = name
    self.inviteCode = inviteCode
    self.imageUploadFailed = imageUploadFailed
  }
}
