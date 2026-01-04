import SwiftUI

import AppEntryFeature
import ExternalDependency

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  private let store = Store(initialState: AppEntry.Feature.State()) {
    AppEntry.Feature()
  }
  
  var body: some Scene {
    WindowGroup {
      AppEntry.RootView(store: store)
        .onOpenURL { url in
          store.send(.view(.handleDeeplink(url)))
        }
    }
  }
}
