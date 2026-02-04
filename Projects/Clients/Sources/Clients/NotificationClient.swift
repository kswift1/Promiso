import ComposableArchitecture
import Foundation
import UIKit
import UserNotifications

// MARK: - Client

public struct NotificationClient: Sendable {
  // MARK: - FCM Token Management

  /// FCM 토큰 Firestore 저장
  /// - Parameter token: FCM 토큰
  public var saveFCMToken: @Sendable (_ token: String) async throws -> Void

  /// FCM 토큰 삭제 (로그아웃 시)
  public var deleteFCMToken: @Sendable () async throws -> Void

  /// LiveActivity Push to Start 토큰 저장
  /// - Parameter token: Push to Start 토큰
  public var saveLiveActivityPushToStartToken: @Sendable (_ token: String) async throws -> Void

  // MARK: - Authorization

  /// 알림 권한 상태 확인
  /// - Returns: 권한 상태
  public var getAuthorizationStatus: @Sendable () async -> NotificationAuthorizationStatus = { .notDetermined }

  /// 알림 권한 요청
  /// - Returns: 권한 부여 여부
  public var requestAuthorization: @Sendable () async throws -> Bool

  /// 알림 설정 열기 (시스템 설정으로 이동)
  public var openNotificationSettings: @Sendable () async -> Void = { }

  // MARK: - Notification List

  /// 알림 목록 조회
  /// - Parameters:
  ///   - filter: 필터 (전체/안읽음)
  ///   - limit: 조회 개수
  ///   - lastCreatedAt: 페이지네이션 커서 (마지막 알림의 createdAt)
  /// - Returns: 알림 목록
  public var getNotifications: @Sendable (
    _ filter: NotificationFilter,
    _ limit: Int,
    _ lastCreatedAt: Date?
  ) async throws -> [NotificationModel]

  /// 안 읽은 알림 개수 조회
  /// - Returns: 안 읽은 알림 개수
  public var getUnreadCount: @Sendable () async throws -> Int

  // MARK: - Read Status

  /// 알림 읽음 처리
  /// - Parameter notificationId: 알림 ID
  public var markAsRead: @Sendable (_ notificationId: String) async throws -> Void

  /// 전체 알림 읽음 처리
  public var markAllAsRead: @Sendable () async throws -> Void

  // MARK: - Delete

  /// 알림 삭제
  /// - Parameter notificationIds: 삭제할 알림 ID 목록
  public var deleteNotifications: @Sendable (_ notificationIds: [String]) async throws -> Void

  /// 전체 알림 삭제
  public var deleteAllNotifications: @Sendable () async throws -> Void
}

// MARK: - Test / Preview

extension NotificationClient: TestDependencyKey {
  public static let previewValue = Self(
    saveFCMToken: { _ in },
    deleteFCMToken: { },
    saveLiveActivityPushToStartToken: { _ in },
    getAuthorizationStatus: { .authorized },
    requestAuthorization: { true },
    openNotificationSettings: { },
    getNotifications: { _, _, _ in [] },
    getUnreadCount: { 0 },
    markAsRead: { _ in },
    markAllAsRead: { },
    deleteNotifications: { _ in },
    deleteAllNotifications: { }
  )

  public static let testValue = Self(
    saveFCMToken: unimplemented("\(Self.self).saveFCMToken"),
    deleteFCMToken: unimplemented("\(Self.self).deleteFCMToken"),
    saveLiveActivityPushToStartToken: unimplemented("\(Self.self).saveLiveActivityPushToStartToken"),
    getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus", placeholder: .notDetermined),
    requestAuthorization: unimplemented("\(Self.self).requestAuthorization", placeholder: false),
    openNotificationSettings: unimplemented("\(Self.self).openNotificationSettings"),
    getNotifications: unimplemented("\(Self.self).getNotifications", placeholder: []),
    getUnreadCount: unimplemented("\(Self.self).getUnreadCount", placeholder: 0),
    markAsRead: unimplemented("\(Self.self).markAsRead"),
    markAllAsRead: unimplemented("\(Self.self).markAllAsRead"),
    deleteNotifications: unimplemented("\(Self.self).deleteNotifications"),
    deleteAllNotifications: unimplemented("\(Self.self).deleteAllNotifications")
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
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        // 권한 허용 시 원격 알림 등록
        if granted {
          await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
        return granted
      },

      openNotificationSettings: {
        await MainActor.run {
          if let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      },

      getNotifications: { filter, limit, lastCreatedAt in
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        return try await dataSource.getNotifications(
          userId: currentUser.uid,
          filter: filter,
          limit: limit,
          lastCreatedAt: lastCreatedAt
        )
      },

      getUnreadCount: {
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        return try await dataSource.getUnreadCount(userId: currentUser.uid)
      },

      markAsRead: { notificationId in
        guard await authClient.currentUser() != nil else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.markAsRead(notificationId: notificationId)
      },

      markAllAsRead: {
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.markAllAsRead(userId: currentUser.uid)
      },

      deleteNotifications: { notificationIds in
        guard await authClient.currentUser() != nil else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.deleteNotifications(notificationIds: notificationIds)
      },

      deleteAllNotifications: {
        guard let currentUser = await authClient.currentUser() else {
          throw NotificationClientError.authenticationRequired
        }
        try await dataSource.deleteAllNotifications(userId: currentUser.uid)
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
