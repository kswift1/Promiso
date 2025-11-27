import SwiftUI
import ComposableArchitecture
import AppEntryFeature

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      // App 레이어에서 모든 의존성을 주입
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      }
      
      AppEntry.RootView(store: store)
    }
  }
}
