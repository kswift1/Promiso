import SwiftUI
import ComposableArchitecture
import RootTabInterface

public extension RootTabEntry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: RootTab.Feature.State()) {
        RootTab.Feature()
      }
      return AnyView(RootTab.RootView(store: store))
    }
  }
}