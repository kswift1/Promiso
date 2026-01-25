import SwiftUI
import UserNotifications

import AppEntryFeature
import ExternalDependency

@main
struct PromisoApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @Environment(\.scenePhase) private var scenePhase

  private let store = Store(initialState: AppEntry.Feature.State()) {
    AppEntry.Feature()
  } withDependencies: { deps in
    deps.authClient = .liveValue
  }

  var body: some Scene {
    WindowGroup {
      AppEntry.RootView(store: store)
        .onOpenURL { url in
          store.send(.view(.handleDeeplink(url)))
        }
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        // 앱 진입 시 배지 초기화
        UNUserNotificationCenter.current().setBadgeCount(0)
      }
    }
  }
}
