import ComposableArchitecture
import Foundation
import UserNotifications

// MARK: - Types

/// 알림 권한 상태
public enum NotificationAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case denied
  case authorized
  case provisional
  case ephemeral

  init(from status: UNAuthorizationStatus) {
    switch status {
    case .notDetermined: self = .notDetermined
    case .denied: self = .denied
    case .authorized: self = .authorized
    case .provisional: self = .provisional
    case .ephemeral: self = .ephemeral
    @unknown default: self = .notDetermined
    }
  }
}

/// 디바이스 정보
public struct DeviceInfo: Equatable, Sendable, Codable {
  public let fcmToken: String
  public let platform: String
  public let lastActiveAt: Date
  public let createdAt: Date

  public init(fcmToken: String, platform: String = "ios", lastActiveAt: Date = Date(), createdAt: Date = Date()) {
    self.fcmToken = fcmToken
    self.platform = platform
    self.lastActiveAt = lastActiveAt
    self.createdAt = createdAt
  }
}

// MARK: - Client

public struct NotificationClient: Sendable {
  /// FCM 토큰 Firestore 저장
  /// - Parameter token: FCM 토큰
  public var saveFCMToken: @Sendable (_ token: String) async throws -> Void

  /// FCM 토큰 삭제 (로그아웃 시)
  public var deleteFCMToken: @Sendable () async throws -> Void

  /// 알림 권한 상태 확인
  /// - Returns: 권한 상태
  public var getAuthorizationStatus: @Sendable () async -> NotificationAuthorizationStatus = { .notDetermined }

  /// 알림 권한 요청
  /// - Returns: 권한 부여 여부
  public var requestAuthorization: @Sendable () async throws -> Bool

  /// 현재 FCM 토큰 조회
  /// - Returns: FCM 토큰 (없으면 nil)
  public var getCurrentFCMToken: @Sendable () async -> String? = { nil }

  /// 알림 설정 열기 (시스템 설정으로 이동)
  public var openNotificationSettings: @Sendable () async -> Void = { }
}

// MARK: - Test / Preview

extension NotificationClient: TestDependencyKey {
  public static let previewValue = Self(
    saveFCMToken: { _ in },
    deleteFCMToken: { },
    getAuthorizationStatus: { .authorized },
    requestAuthorization: { true },
    getCurrentFCMToken: { "preview-fcm-token" },
    openNotificationSettings: { }
  )

  public static let testValue = Self(
    saveFCMToken: unimplemented("\(Self.self).saveFCMToken"),
    deleteFCMToken: unimplemented("\(Self.self).deleteFCMToken"),
    getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus", placeholder: .notDetermined),
    requestAuthorization: unimplemented("\(Self.self).requestAuthorization", placeholder: false),
    getCurrentFCMToken: unimplemented("\(Self.self).getCurrentFCMToken", placeholder: nil),
    openNotificationSettings: unimplemented("\(Self.self).openNotificationSettings")
  )
}

// MARK: - Live

extension NotificationClient: DependencyKey {
  public static let liveValue: NotificationClient = {
    @Dependency(\.authClient) var authClient
    let dataSource = NotificationRemoteDataSource()

    return Self(
      saveFCMToken: { token in
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.saveFCMToken(userId: currentUser.uid, token: token)
      },

      deleteFCMToken: {
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.deleteFCMToken(userId: currentUser.uid)
      },

      getAuthorizationStatus: {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAuthorizationStatus(from: settings.authorizationStatus)
      },

      requestAuthorization: {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
      },

      getCurrentFCMToken: {
        // Firebase Messaging의 현재 토큰 반환
        // ExternalDependency에서 Messaging 접근 필요
        return nil // TODO: Messaging.messaging().fcmToken
      },

      openNotificationSettings: {
        await MainActor.run {
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      }
    )
  }()
}

// MARK: - Error

public enum NotificationClientError: Error, Equatable, LocalizedError {
  case authenticationRequired
  case tokenNotFound
  case saveFailed
  case deleteFailed

  public var errorDescription: String? {
    switch self {
    case .authenticationRequired:
      return "로그인이 필요합니다."
    case .tokenNotFound:
      return "FCM 토큰을 찾을 수 없습니다."
    case .saveFailed:
      return "토큰 저장에 실패했습니다."
    case .deleteFailed:
      return "토큰 삭제에 실패했습니다."
    }
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
