import Combine
import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Types

/// 딥링크 목적지
public enum DeeplinkDestination: Equatable, Sendable {
  /// 약속 상세 화면
  case promise(promiseId: String, groupId: String)
  /// 그룹 상세 화면
  case group(groupId: String)
  /// 그룹 참여 (초대 코드)
  case joinGroup(inviteCode: String)
}

/// 푸시 알림 데이터 (FCM payload)
public struct PushNotificationData: Equatable, Sendable {
  public let type: String?
  public let promiseId: String?
  public let groupId: String?

  public init(type: String?, promiseId: String?, groupId: String?) {
    self.type = type
    self.promiseId = promiseId
    self.groupId = groupId
  }

  public init(userInfo: [AnyHashable: Any]) {
    self.type = userInfo["type"] as? String
    self.promiseId = userInfo["promiseId"] as? String
    self.groupId = userInfo["groupId"] as? String
  }
}

// MARK: - Client

public struct DeeplinkClient: Sendable {
  /// 푸시 알림 탭 이벤트 스트림
  public var pushNotificationTapStream: @Sendable () -> AsyncStream<DeeplinkDestination>

  /// URL 딥링크 파싱
  /// - Parameter url: 딥링크 URL (예: promiso://join/ABC123)
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public var parseURL: @Sendable (_ url: URL) -> DeeplinkDestination?

  /// 푸시 알림 데이터에서 딥링크 목적지 파싱
  /// - Parameter data: 푸시 알림 데이터
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public var parseNotification: @Sendable (_ data: PushNotificationData) -> DeeplinkDestination?
}

// MARK: - Test / Preview

extension DeeplinkClient: TestDependencyKey {
  public static let previewValue = Self(
    pushNotificationTapStream: { AsyncStream { _ in } },
    parseURL: { _ in nil },
    parseNotification: { _ in nil }
  )

  public static let testValue = Self(
    pushNotificationTapStream: unimplemented("\(Self.self).pushNotificationTapStream"),
    parseURL: unimplemented("\(Self.self).parseURL", placeholder: nil),
    parseNotification: unimplemented("\(Self.self).parseNotification", placeholder: nil)
  )
}

// MARK: - Live

extension DeeplinkClient: DependencyKey {
  public static let liveValue: DeeplinkClient = {
    return Self(
      pushNotificationTapStream: {
        AsyncStream { continuation in
          let observer = NotificationCenter.default.addObserver(
            forName: AppConstants.Notifications.pushNotificationTapped,
            object: nil,
            queue: .main
          ) { notification in
            let data = PushNotificationData(userInfo: notification.userInfo ?? [:])
            if let destination = Self.parseNotificationData(data) {
              continuation.yield(destination)
            }
          }

          continuation.onTermination = { _ in
            NotificationCenter.default.removeObserver(observer)
          }
        }
      },

      parseURL: { url in
        // promiso://join/{inviteCode}
        guard url.scheme == "promiso" else { return nil }

        switch url.host {
        case "join":
          guard let inviteCode = url.pathComponents.dropFirst().first else { return nil }
          return .joinGroup(inviteCode: inviteCode)

        case "group":
          guard let groupId = url.pathComponents.dropFirst().first else { return nil }
          return .group(groupId: groupId)

        case "promise":
          let components = Array(url.pathComponents.dropFirst())
          guard components.count >= 2 else { return nil }
          let promiseId = components[0]
          let groupId = components[1]
          return .promise(promiseId: promiseId, groupId: groupId)

        default:
          return nil
        }
      },

      parseNotification: { data in
        Self.parseNotificationData(data)
      }
    )
  }()

  /// 푸시 알림 데이터에서 목적지 파싱 (내부 헬퍼)
  private static func parseNotificationData(_ data: PushNotificationData) -> DeeplinkDestination? {
    if let promiseId = data.promiseId, let groupId = data.groupId {
      return .promise(promiseId: promiseId, groupId: groupId)
    } else if let groupId = data.groupId {
      return .group(groupId: groupId)
    }
    return nil
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var deeplinkClient: DeeplinkClient {
    get { self[DeeplinkClient.self] }
    set { self[DeeplinkClient.self] = newValue }
  }
}
