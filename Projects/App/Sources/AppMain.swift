import SwiftUI
import AppEntryFeature
import ExternalDependency

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: { dependencies in
        LiveDependencies.install(into: &dependencies)
      }
      
      AppEntry.RootView(store: store)
    }
  }
}
