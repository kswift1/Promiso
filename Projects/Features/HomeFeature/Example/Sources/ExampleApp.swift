import SwiftUI
import ComposableArchitecture
import HomeFeatureImplement

@main
struct HomeFeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: Home.Feature.State()) {
        Home.Feature()
      }
      Home.RootView(store: store)
    }
  }
}