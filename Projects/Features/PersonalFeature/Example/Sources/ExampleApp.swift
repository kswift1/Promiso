import SwiftUI
import ComposableArchitecture
import PersonalFeature
import PromisoShared

@main
struct PersonalFeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      PersonalMode.RootView(
        store: Store(
          initialState: PersonalMode.Feature.State(
            currentUser: Shared(value: .exampleUser)
          )
        ) {
          PersonalMode.Feature()
        }
      )
    }
  }
}
