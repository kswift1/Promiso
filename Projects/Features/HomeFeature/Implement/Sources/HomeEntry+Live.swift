import SwiftUI
import ComposableArchitecture
import HomeInterface

public extension HomeEntry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Home.Feature.State()) {
        Home.Feature()
      }
      return AnyView(Home.RootView(store: store))
    }
  }
}