import Foundation

// MARK: - Group Shared Model

public struct Group: Identifiable, Equatable, Hashable {
  public let id: String
  public let name: String
  public let description: String?
  public let isPublic: Bool
  public let memberCount: Int
  
  public init(
    id: String,
    name: String,
    description: String? = nil,
    isPublic: Bool = false,
    memberCount: Int = 0
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.isPublic = isPublic
    self.memberCount = memberCount
  }
}
