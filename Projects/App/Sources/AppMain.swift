import SwiftUI
import UserNotifications

import AppEntryFeature
import ExternalDependency
import PromisoShared

#if DEBUG
import PulseUI
#endif

@main
struct PromisoApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  init() {
    // 앱 시작 시 시간 형식 설정 로드
    LocalizedDateFormatters.use24HourFormat = UserDefaults.standard.bool(forKey: AppConstants.UserDefaults.use24HourFormat)

    // 테마 모드 기본값 설정 (최초 실행 시)
    if UserDefaults.standard.string(forKey: AppConstants.UserDefaults.preferredThemeMode) == nil {
      UserDefaults.standard.set(AppConstants.ThemeMode.system.rawValue, forKey: AppConstants.UserDefaults.preferredThemeMode)
    }

    AppLanguage.initializeIfNeeded()

    // 선호 언어 번들 설정
    LocalizedStrings.configure()
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
        #if DEBUG
        .modifier(ShakeToPulseModifier())
        #endif
    }
    // 배지 카운트는 HomeFeature에서 실제 unreadCount로 동기화
  }
}

// MARK: - Shake to Pulse Console (DEBUG only)

#if DEBUG
private extension NSNotification.Name {
  static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    super.motionEnded(motion, with: event)
    if motion == .motionShake {
      NotificationCenter.default.post(name: .deviceDidShake, object: nil)
    }
  }
}

private struct ShakeToPulseModifier: ViewModifier {
  @State private var isPresented = false

  func body(content: Content) -> some View {
    content
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        isPresented = true
      }
      .sheet(isPresented: $isPresented) {
        NavigationStack {
          ConsoleView()
        }
      }
  }
}
#endif
