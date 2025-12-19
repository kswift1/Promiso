import SwiftUI
import ComposableArchitecture
import AppEntryFeature

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  private let store = Store(initialState: AppEntry.Feature.State()) {
    AppEntry.Feature()
  }
  
  var body: some Scene {
    WindowGroup {
//      TestEmulatorView()
      AppEntry.RootView(store: store)
    }
  }
}
