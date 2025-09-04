import SwiftUI

public struct MainEntry {
  public var makeView: (_ config: Config) -> AnyView
  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
}

public struct Config: Sendable { public init() {} }
public enum MainRoute: Hashable { case root }