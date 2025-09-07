import SwiftUI
import ComposableArchitecture
import RootTabFeatureImplement

@main
struct RootTabFeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: RootTab.Feature.State()) {
        RootTab.Feature()
      }
      RootTab.RootView(store: store)
    }
  }
}