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
  /// LiveActivity ETA 변경 시트 (Widget에서 "직접 입력" 버튼)
  case liveActivityETA(promiseId: String)
  /// LivePromise 상세 화면 (LiveActivity 탭 시 ETA 시트 없이 열기)
  case livePromise(promiseId: String)
  /// 약속 만들기 화면 (Widget에서 "약속 만들기" 버튼)
  case create
  /// 개인 일정 (Widget에서 탭 시 홈 탭으로 이동)
  case personalEvent(eventId: String)
}

// MARK: - Client

public struct DeeplinkClient: Sendable {
  /// 푸시 알림 탭 이벤트 스트림
  public var pushNotificationTapStream: @Sendable () -> AsyncStream<DeeplinkDestination>

  /// URL 딥링크 파싱
  /// - Parameter url: 딥링크 URL (예: promiso://join/ABC123)
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public var parseURL: @Sendable (_ url: URL) -> DeeplinkDestination?

  /// 푸시 알림 userInfo에서 딥링크 목적지 파싱
  /// - Parameter userInfo: FCM payload ([type, promiseId?, groupId?, relatedUserId?])
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public var parseNotification: @Sendable (_ userInfo: [AnyHashable: Any]) -> DeeplinkDestination?
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
            if let destination = Self.parseUserInfo(notification.userInfo ?? [:]) {
              continuation.yield(destination)
            }
          }

          continuation.onTermination = { _ in
            NotificationCenter.default.removeObserver(observer)
          }
        }
      },

      parseURL: { url in
        DeeplinkURLParser.parse(url)
      },

      parseNotification: { userInfo in
        Self.parseUserInfo(userInfo)
      }
    )
  }()

  /// FCM userInfo 파싱 (내부 헬퍼)
  ///
  /// NotificationType별 필수 필드:
  /// - promiseAndGroup: promiseId + groupId 필요 → .promise
  /// - groupOnly: groupId만 필요 → .group
  /// - none: 딥링크 불필요 (system 등) → nil
  ///
  /// - Note: joinGroup은 URL 딥링크 전용 (푸시 알림에서는 inviteCode 미전송)
  private static func parseUserInfo(_ userInfo: [AnyHashable: Any]) -> DeeplinkDestination? {
    // 1. type 추출 및 NotificationType 변환
    guard let typeString = userInfo["type"] as? String,
          let type = NotificationType(rawValue: typeString) else {
      return nil
    }

    // 2. 필드 추출
    let promiseId = userInfo["promiseId"] as? String
    let groupId = userInfo["groupId"] as? String

    // 3. deeplinkGuide에 따라 검증 및 변환
    switch type.deeplinkGuide {
    case .promiseAndGroup:
      guard let promiseId, let groupId else { return nil }
      return .promise(promiseId: promiseId, groupId: groupId)

    case .groupOnly:
      guard let groupId else { return nil }
      return .group(groupId: groupId)

    case .none:
      // system 등 딥링크 불필요한 타입
      return nil
    }
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var deeplinkClient: DeeplinkClient {
    get { self[DeeplinkClient.self] }
    set { self[DeeplinkClient.self] = newValue }
  }
}
