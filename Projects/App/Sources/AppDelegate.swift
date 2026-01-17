//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit
import UserNotifications

import ExternalDependency
import Clarity
import PromisoShared
import SharedFeature

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    configureClaritySDK()
    configureRemoteNotifications(application)

// MARK: - Emulator 사용 시 주석 해제
#if DEBUG
//    connectToEmulators()
#endif

    return true
  }

  // MARK: - Remote Notifications Configuration

  private func configureRemoteNotifications(_ application: UIApplication) {
    // UNUserNotificationCenter delegate 설정
    UNUserNotificationCenter.current().delegate = self

    // Firebase Messaging delegate 설정
    Messaging.messaging().delegate = self

    // 알림 권한 요청
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      print("📱 Notification authorization granted: \(granted)")
      if granted {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
      if let error = error {
        print("❌ Notification authorization error: \(error)")
      }
    }
  }

  // MARK: - APNs Token Registration

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // FCM에 APNs 토큰 설정
    Messaging.messaging().apnsToken = deviceToken
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNs Token registered: \(tokenString)")
  }

  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
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
    print("📩 Received notification in foreground: \(userInfo)")

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
    print("👆 Notification tapped: \(userInfo)")

    handleNotificationTap(userInfo)
    completionHandler()
  }

  private func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
    // 알림 데이터 추출
    let notificationType = userInfo["type"] as? String
    let promiseId = userInfo["promiseId"] as? String
    let groupId = userInfo["groupId"] as? String

    print("📍 Notification tap - type: \(notificationType ?? "nil"), promiseId: \(promiseId ?? "nil"), groupId: \(groupId ?? "nil")")

    // NotificationCenter를 통해 AppEntryFeature로 전달
    var notificationInfo: [String: Any] = [:]
    if let type = notificationType {
      notificationInfo["type"] = type
    }
    if let promiseId = promiseId {
      notificationInfo["promiseId"] = promiseId
    }
    if let groupId = groupId {
      notificationInfo["groupId"] = groupId
    }

    // promiseId 또는 groupId가 있을 때만 전달
    guard promiseId != nil || groupId != nil else { return }

    NotificationCenter.default.post(
      name: AppConstants.Notifications.pushNotificationTapped,
      object: nil,
      userInfo: notificationInfo
    )
  }
}
