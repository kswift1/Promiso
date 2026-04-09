import ComposableArchitecture
import Foundation
import PromisoShared
import UIKit
import UserNotifications

// MARK: - Client

@DependencyClient
public struct NotificationClient: Sendable {
  // MARK: - Device Registration

  /// 일반 알림용 토큰 저장
  /// - Parameter token: 현재는 FCM registration token
  public var saveNotificationToken: @Sendable (_ token: String) async throws -> Void

  /// 현재 디바이스 등록 삭제 (로그아웃 시)
  public var deleteCurrentDeviceRegistration: @Sendable () async throws -> Void

  /// LiveActivity Push to Start 토큰 저장 (앱 단위 통합)
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
  /// - Parameter userId: 사용자 ID
  /// - Returns: 안 읽은 알림 개수
  public var getUnreadCount: @Sendable (_ userId: String) async throws -> Int

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

  // MARK: - Badge

  /// 앱 아이콘 배지 카운트 설정
  /// - Parameter count: 배지 카운트 (0이면 배지 제거)
  public var setBadgeCount: @Sendable (_ count: Int) async -> Void = { _ in }
}

// MARK: - Test / Preview

extension NotificationClient: TestDependencyKey {
  public static let previewValue = Self(
    saveNotificationToken: { _ in },
    deleteCurrentDeviceRegistration: { },
    saveLiveActivityPushToStartToken: { _ in },
    getAuthorizationStatus: { .authorized },
    requestAuthorization: { true },
    openNotificationSettings: { },
    getNotifications: { _, _, _ in [] },
    getUnreadCount: { _ in 0 },
    markAsRead: { _ in },
    markAllAsRead: { },
    deleteNotifications: { _ in },
    deleteAllNotifications: { },
    setBadgeCount: { _ in }
  )

  public static let testValue = Self(
    saveNotificationToken: unimplemented("\(Self.self).saveNotificationToken"),
    deleteCurrentDeviceRegistration: unimplemented("\(Self.self).deleteCurrentDeviceRegistration"),
    saveLiveActivityPushToStartToken: unimplemented(
      "\(Self.self).saveLiveActivityPushToStartToken"
    ),
    getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus", placeholder: .notDetermined),
    requestAuthorization: unimplemented("\(Self.self).requestAuthorization", placeholder: false),
    openNotificationSettings: unimplemented("\(Self.self).openNotificationSettings"),
    getNotifications: unimplemented("\(Self.self).getNotifications", placeholder: []),
    getUnreadCount: unimplemented("\(Self.self).getUnreadCount", placeholder: 0),
    markAsRead: unimplemented("\(Self.self).markAsRead"),
    markAllAsRead: unimplemented("\(Self.self).markAllAsRead"),
    deleteNotifications: unimplemented("\(Self.self).deleteNotifications"),
    deleteAllNotifications: unimplemented("\(Self.self).deleteAllNotifications"),
    setBadgeCount: unimplemented("\(Self.self).setBadgeCount")
  )
}

// MARK: - Live

extension NotificationClient: DependencyKey {
  public static let liveValue: NotificationClient = {
    let rustDataSource = NotificationRustDataSource(
      api: RustAPIClient()
    )

    return Self(
      saveNotificationToken: { token in
        try await rustDataSource.saveNotificationToken(token)
      },

      deleteCurrentDeviceRegistration: {
        try await rustDataSource.deleteCurrentDevice()
      },

      saveLiveActivityPushToStartToken: { token in
        // Live Activity는 Rust/APNs 경로만 유지한다.
        try await rustDataSource.saveLiveActivityPushToStartToken(token)
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
        // Rust API는 서버에서 인증된 사용자 기준으로 조회한다.
        // filter는 현재 서버측 필터링 미지원이므로 전체 조회 후 클라이언트 필터링한다.
        var notifications = try await rustDataSource.getNotifications(
          limit: limit,
          lastCreatedAt: lastCreatedAt
        )
        if filter == .unread {
          notifications = notifications.filter { !$0.isRead }
        }
        return notifications
      },

      getUnreadCount: { _ in
        return try await rustDataSource.getUnreadCount()
      },

      markAsRead: { notificationId in
        try await rustDataSource.markAsRead(notificationId: notificationId)
      },

      markAllAsRead: {
        try await rustDataSource.markAllAsRead()
      },

      deleteNotifications: { notificationIds in
        try await rustDataSource.deleteNotifications(notificationIds: notificationIds)
      },

      deleteAllNotifications: {
        try await rustDataSource.deleteAllNotifications()
      },

      setBadgeCount: { count in
        do {
          try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
          AppLogger.notification.error("Failed to set badge count: \(error.localizedDescription)")
        }
      }
    )
  }()
}

// MARK: - Error

public enum NotificationClientError: Error, Equatable {
  case authenticationRequired
  case tokenNotFound
  case saveFailed
  case deleteFailed
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
