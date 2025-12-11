import SwiftUI
import ComposableArchitecture
import AppEntryFeature

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      }
      
      AppEntry.RootView(store: store)
    }
  }
}
