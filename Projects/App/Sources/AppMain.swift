import SwiftUI
import UserNotifications

import AppEntryFeature
import ExternalDependency
import PromisoShared

@main
struct PromisoApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  init() {
    // 앱 시작 시 시간 형식 설정 로드
    KoreanDateFormatters.use24HourFormat = UserDefaults.standard.bool(forKey: AppConstants.UserDefaults.use24HourFormat)
  }
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
