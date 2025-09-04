import SwiftUI
import SharedModels

public struct MainEntry {
  public var makeView: (_ config: Config) -> AnyView
  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
}

public struct Config: Sendable {
  public let groupID: GroupID
  public init(groupID: GroupID) { self.groupID = groupID }
}

public enum MainRoute: Hashable {
  case root
}