//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit
import UserNotifications

import Clients
import ExternalDependency
import Clarity
import PromisoShared

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    ImagePipelineConfigurator.configure()
    configureAnalytics()
    configureCrashlytics()
    configureClaritySDK()
    configureKakaoSDK()
    configureKakaoMapsSDK()
    configureRemoteNotifications(application)

    return true
  }

  // MARK: - Remote Notifications Configuration

  private func configureRemoteNotifications(_ application: UIApplication) {
    // UNUserNotificationCenter delegate 설정
    UNUserNotificationCenter.current().delegate = self

    // Firebase Messaging delegate 설정
    Messaging.messaging().delegate = self

    // 알림 권한 상태 확인 후 등록
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
    AppLogger.notification.debug("APNs Token registered")
  }

  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    AppLogger.notification.error("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  // MARK: - Kakao SDK (Share)
  private func configureKakaoSDK() {
    guard let kakaoAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else {
      AppLogger.general.error("Kakao Native App Key not found in Info.plist")
      return
    }
    KakaoSDK.initSDK(appKey: kakaoAppKey)
    AppLogger.general.debug("Kakao SDK initialized")
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

  // MARK: - Firebase Analytics
  private func configureAnalytics() {
    #if DEBUG
    // Debug 빌드에서는 Analytics 비활성화 (선택사항)
    Analytics.setAnalyticsCollectionEnabled(false)
    AppLogger.general.debug("Firebase Analytics disabled for DEBUG build")
    #else
    // Release 빌드에서는 Analytics 활성화
    Analytics.setAnalyticsCollectionEnabled(true)
    AppLogger.general.debug("Firebase Analytics enabled")
    #endif
  }

  // MARK: - Firebase Crashlytics
  private func configureCrashlytics() {
    #if DEBUG
    // Debug 빌드에서는 Crashlytics 비활성화
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
    AppLogger.general.debug("Firebase Crashlytics disabled for DEBUG build")
    #else
    // Release 빌드에서는 Crashlytics 활성화
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    AppLogger.general.debug("Firebase Crashlytics enabled")
    #endif
  }

  // MARK: - Microsoft Clarity SDK
  private func configureClaritySDK() {
    guard let projectId = Bundle.main.object(forInfoDictionaryKey: "CLARITY_PROJECT_ID") as? String else {
      AppLogger.general.error("Clarity Project ID not found in Info.plist")
      return
    }

    #if DEBUG
    let config = ClarityConfig(projectId: projectId, logLevel: .error)
    #else
    let config = ClarityConfig(projectId: projectId, logLevel: .none)
    #endif

    ClaritySDK.initialize(config: config)
    AppLogger.general.debug("Clarity SDK initialized with projectId: \(projectId)")
  }

  /// Google Sign-In 리디렉션 URL 처리
  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }

}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken else { return }
    AppLogger.notification.debug("FCM Token received")

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
