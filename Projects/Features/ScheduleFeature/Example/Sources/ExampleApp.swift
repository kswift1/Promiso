import SwiftUI
import ComposableArchitecture
import ScheduleFeatureImplement

@main
struct ScheduleFeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: Schedule.Feature.State()) {
        Schedule.Feature()
      }
      Schedule.RootView(store: store)
    }
  }
}