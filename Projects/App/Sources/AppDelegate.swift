//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit
import UserNotifications
import os.log

import Clients
import ExternalDependency
import Clarity
import PromisoShared

private let silentPushLog = OSLog(subsystem: "com.promiso", category: "SilentPush")

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    configureClaritySDK()
    configureKakaoMapsSDK()
    configureRemoteNotifications(application)

// MARK: - Emulator 사용 시 주석 해제
#if DEBUG
//    connectToEmulators()
#endif

    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // 앱 활성화 시 뱃지 카운트 초기화
    UNUserNotificationCenter.current().setBadgeCount(0)

    // 위젯 디버그 로그 출력
    if let widgetLog = WidgetDataManager.readDebugLog() {
      print("[WIDGET_DEBUG] \(widgetLog)")
    }
  }

  // MARK: - Remote Notifications Configuration

  private func configureRemoteNotifications(_ application: UIApplication) {
    // UNUserNotificationCenter delegate 설정
    UNUserNotificationCenter.current().delegate = self

    // Firebase Messaging delegate 설정
    Messaging.messaging().delegate = self

    // 이미 권한이 있는 경우에만 등록 (권한 요청은 온보딩에서 처리)
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      if settings.authorizationStatus == .authorized {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
  }

  // MARK: - APNs Token Registration

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // FCM에 APNs 토큰 설정
    Messaging.messaging().apnsToken = deviceToken
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    AppLogger.notification.debug("APNs Token registered: \(tokenString)")
  }

  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    AppLogger.notification.error("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  // MARK: - Silent Push (Widget Refresh)

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // os.log로 Silent Push 수신 로깅 (prefix: PROMISO_PUSH)
    os_log(.error, log: silentPushLog, "[PROMISO_PUSH] 📩 Received: %{public}@", String(describing: userInfo))

    // Silent Push 타입 확인
    guard let type = userInfo["type"] as? String, type == "widget_refresh" else {
      let receivedType = userInfo["type"] as? String ?? "nil"
      os_log(.error, log: silentPushLog, "[PROMISO_PUSH] ❌ Type mismatch - got: %{public}@", receivedType)
      completionHandler(.noData)
      return
    }

    os_log(.error, log: silentPushLog, "[PROMISO_PUSH] ✅ Widget refresh matched")

    // 서버에서 위젯 스냅샷 조회 → 캐시 저장 → 위젯 갱신
    Task {
      let success = await WidgetDataManager.refreshFromServer()
      os_log(.error, log: silentPushLog, "[PROMISO_PUSH] 🔄 Result: %{public}@", success ? "success" : "failed")
      completionHandler(success ? .newData : .failed)
    }
  }

  // MARK: - Kakao Maps SDK
  private func configureKakaoMapsSDK() {
    guard let kakaoAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else {
      AppLogger.general.error("Kakao Native App Key not found in Info.plist")
      return
    }
    SDKInitializer.InitSDK(appKey: kakaoAppKey)
    AppLogger.general.debug("Kakao Maps SDK initialized")
  }

  // MARK: - Microsoft Clarity SDK
  private func configureClaritySDK() {
    let projectId = "v0o95eccpc"

    #if DEBUG
    let config = ClarityConfig(projectId: projectId, logLevel: .error)
    #else
    let config = ClarityConfig(projectId: projectId, logLevel: .none)
    #endif

    ClaritySDK.initialize(config: config)
  }
  
  /// Google Sign-In 리디렉션 URL 처리
  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }
  
#if DEBUG
  private func connectToEmulators() {
    let emulatorHost = "192.168.0.2"
    print("🎮 Connecting to Firebase Emulators...")

    // Auth Emulator
    Auth.auth().useEmulator(withHost: emulatorHost, port: 9099)
    print("✅ Auth Emulator: \(emulatorHost):9099")

    // Firestore Emulator
    let settings = Firestore.firestore().settings
    settings.host = "\(emulatorHost):8081"
    settings.isSSLEnabled = false
    Firestore.firestore().settings = settings
    print("✅ Firestore Emulator: \(emulatorHost):8081")

    // Functions Emulator
    Functions.functions().useEmulator(withHost: emulatorHost, port: 5001)
    Functions.functions(region: "asia-northeast3").useEmulator(withHost: emulatorHost, port: 5001)
    print("✅ Functions Emulator: \(emulatorHost):5001")

    // Storage Emulator
    Storage.storage().useEmulator(withHost: emulatorHost, port: 9199)
    print("✅ Storage Emulator: \(emulatorHost):9199")

    print("🎉 All emulators connected!")
  }
#endif
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken else { return }
    AppLogger.notification.debug("FCM Token received: \(token)")

    // NotificationCenter를 통해 토큰 브로드캐스트
    // AppFeature에서 수신하여 Firestore에 저장
    NotificationCenter.default.post(
      name: AppConstants.Notifications.fcmTokenDidReceive,
      object: nil,
      userInfo: ["token": token]
    )
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
  /// Foreground에서 알림 수신 시 처리
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    AppLogger.notification.debug("Received notification in foreground: \(userInfo)")

    // Foreground에서도 배너, 사운드, 뱃지 표시
    completionHandler([.banner, .sound, .badge])
  }

  /// 알림 탭 시 처리
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    handleNotificationTap(userInfo)
    completionHandler()
  }

  private func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
    AppLogger.notification.debug("Notification tap - userInfo: \(userInfo)")

    // DeeplinkClient에서 파싱 및 검증 처리
    NotificationCenter.default.post(
      name: AppConstants.Notifications.pushNotificationTapped,
      object: nil,
      userInfo: userInfo
    )
  }
}
