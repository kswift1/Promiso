import SwiftUI
import ComposableArchitecture
import MainFeatureImplement

@main
struct MainFeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: Main.Feature.State()) {
        Main.Feature()
      }
      Main.RootView(store: store)
    }
  }
}