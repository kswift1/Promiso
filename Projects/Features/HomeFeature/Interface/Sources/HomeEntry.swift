import SwiftUI

public struct HomeEntry {
  public var makeView: (_ config: Config) -> AnyView
  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
}

public struct Config: Sendable { public init() {} }
public enum HomeRoute: Hashable { case root }