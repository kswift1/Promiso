import ComposableArchitecture
import Foundation
import UserNotifications

// MARK: - Client

public struct NotificationClient: Sendable {
  /// FCM 토큰 Firestore 저장
  /// - Parameter token: FCM 토큰
  public var saveFCMToken: @Sendable (_ token: String) async throws -> Void

  /// FCM 토큰 삭제 (로그아웃 시)
  public var deleteFCMToken: @Sendable () async throws -> Void

  /// LiveActivity Push to Start 토큰 저장
  /// - Parameter token: Push to Start 토큰
  public var saveLiveActivityPushToStartToken: @Sendable (_ token: String) async throws -> Void

  /// 알림 권한 상태 확인
  /// - Returns: 권한 상태
  public var getAuthorizationStatus: @Sendable () async -> NotificationAuthorizationStatus = { .notDetermined }

  /// 알림 권한 요청
  /// - Returns: 권한 부여 여부
  public var requestAuthorization: @Sendable () async throws -> Bool

  /// 알림 설정 열기 (시스템 설정으로 이동)
  public var openNotificationSettings: @Sendable () async -> Void = { }
}

// MARK: - Test / Preview

extension NotificationClient: TestDependencyKey {
  public static let previewValue = Self(
    saveFCMToken: { _ in },
    deleteFCMToken: { },
    saveLiveActivityPushToStartToken: { _ in },
    getAuthorizationStatus: { .authorized },
    requestAuthorization: { true },
    openNotificationSettings: { }
  )

  public static let testValue = Self(
    saveFCMToken: unimplemented("\(Self.self).saveFCMToken"),
    deleteFCMToken: unimplemented("\(Self.self).deleteFCMToken"),
    saveLiveActivityPushToStartToken: unimplemented("\(Self.self).saveLiveActivityPushToStartToken"),
    getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus", placeholder: .notDetermined),
    requestAuthorization: unimplemented("\(Self.self).requestAuthorization", placeholder: false),
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

      saveLiveActivityPushToStartToken: { token in
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.saveLiveActivityPushToStartToken(userId: currentUser.uid, token: token)
      },

      getAuthorizationStatus: {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAuthorizationStatus(from: settings.authorizationStatus)
      },

      requestAuthorization: {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
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
