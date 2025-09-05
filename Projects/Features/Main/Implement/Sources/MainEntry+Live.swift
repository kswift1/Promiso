import SwiftUI
import ComposableArchitecture
import MainFeatureInterface

public extension MainEntry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Main.Feature.State()) {
        Main.Feature()
      }
      return AnyView(Main.RootView(store: store))
    }
  }
}
