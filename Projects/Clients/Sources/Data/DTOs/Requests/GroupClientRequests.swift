import Foundation

/// 그룹 생성 요청 모델
/// GroupClient.createGroup에서 사용
public struct CreateGroupRequestModel: Equatable, Sendable {
  public let name: String
  public let maxMembers: Int
  public let description: String?
  public let creatorId: String
  public let photoData: Data?

  public init(
    name: String,
    maxMembers: Int,
    description: String? = nil,
    creatorId: String,
    photoData: Data? = nil
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.description = description
    self.creatorId = creatorId
    self.photoData = photoData
  }
}
