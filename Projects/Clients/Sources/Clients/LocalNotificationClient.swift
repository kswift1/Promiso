import ComposableArchitecture
import Foundation
import UserNotifications
import PromisoShared

// MARK: - Client

/// 로컬 알림 스케줄링을 위한 TCA Dependency Client
/// UNUserNotificationCenter를 래핑하여 알림 예약/취소 기능 제공
@DependencyClient
public struct LocalNotificationClient: Sendable {
  /// 로컬 알림 예약
  public var schedule: @Sendable (
    _ id: String,
    _ title: String,
    _ body: String,
    _ triggerDate: Date,
    _ userInfo: [String: String]
  ) async throws -> Void

  /// 특정 ID의 로컬 알림 취소
  public var cancel: @Sendable (_ id: String) async -> Void

  /// 여러 ID의 로컬 알림 일괄 취소
  public var cancelAll: @Sendable (_ ids: [String]) async -> Void

  /// 반복 알림 예약 (UNCalendarNotificationTrigger repeats: true)
  public var scheduleRepeating: @Sendable (
    _ id: String,
    _ title: String,
    _ body: String,
    _ dateComponents: DateComponents,
    _ userInfo: [String: String]
  ) async throws -> Void

  /// 현재 예약된 알림 ID 목록 조회
  public var pendingIds: @Sendable () async -> [String] = { [] }
}

// MARK: - Test & Preview Values

extension LocalNotificationClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    schedule: { _, _, _, _, _ in },
    cancel: { _ in },
    cancelAll: { _ in },
    scheduleRepeating: { _, _, _, _, _ in },
    pendingIds: { [] }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var localNotificationClient: LocalNotificationClient {
    get { self[LocalNotificationClient.self] }
    set { self[LocalNotificationClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension LocalNotificationClient: DependencyKey {
  public static let liveValue = Self(
    schedule: { id, title, body, triggerDate, userInfo in
      guard triggerDate > Date() else {
        AppLogger.notification.debug("⏰ [LocalNotification] 알림 시간이 이미 지남 - 스킵: \(id)")
        return
      }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.userInfo = userInfo

      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: triggerDate
      )
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components,
        repeats: false
      )

      let request = UNNotificationRequest(
        identifier: id,
        content: content,
        trigger: trigger
      )

      try await UNUserNotificationCenter.current().add(request)
      AppLogger.notification.info("⏰ [LocalNotification] 알림 예약 완료: \(id)")
    },

    cancel: { id in
      UNUserNotificationCenter.current()
        .removePendingNotificationRequests(withIdentifiers: [id])
      AppLogger.notification.info("⏰ [LocalNotification] 알림 취소: \(id)")
    },

    cancelAll: { ids in
      guard !ids.isEmpty else { return }
      UNUserNotificationCenter.current()
        .removePendingNotificationRequests(withIdentifiers: ids)
      AppLogger.notification.info("⏰ [LocalNotification] 알림 일괄 취소: \(ids.count)개")
    },

    scheduleRepeating: { id, title, body, components, userInfo in
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.userInfo = userInfo.mapValues { $0 as Any }

      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components,
        repeats: true
      )

      let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
      try await UNUserNotificationCenter.current().add(request)
      AppLogger.notification.info("⏰ [LocalNotification] 반복 알림 예약 완료: \(id)")
    },

    pendingIds: {
      let requests = await UNUserNotificationCenter.current()
        .pendingNotificationRequests()
      return requests.map(\.identifier)
    }
  )
}
