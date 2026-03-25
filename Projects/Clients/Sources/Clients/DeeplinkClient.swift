import Combine
import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Types

/// 딥링크 목적지
public enum DeeplinkDestination: Equatable, Sendable {
  /// 일정 상세 화면
  case schedule(scheduleId: String, groupId: String)
  /// 그룹 상세 화면
  case group(groupId: String)
  /// 그룹 참여 (초대 코드)
  case joinGroup(inviteCode: String)
  /// LiveActivity ETA 변경 시트 (Widget에서 "직접 입력" 버튼)
  case liveActivityETA(scheduleId: String)
  /// LiveSchedule 상세 화면 (LiveActivity 탭 시 ETA 시트 없이 열기)
  case liveSchedule(scheduleId: String)
  /// 투표 딥링크 (VoteLiveActivity 탭 시 일정 상세 화면 열기)
  case vote(scheduleId: String)
  /// 일정 만들기 화면 (Widget에서 "일정 만들기" 버튼)
  case create
  /// 개인 일정 (Widget에서 탭 시 개인 모드 탭으로 이동 + 상세 push)
  case personalEvent(eventId: String)
  /// 프로 플랜 화면 (마케팅/푸시에서 Paywall로 직접 진입)
  case proPlan
  /// Share Extension에서 텍스트 일정 추출 (개인 일정 생성 폼으로 연결)
  case extractSchedule
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
  /// - Parameter userInfo: FCM payload ([type, scheduleId?, groupId?, relatedUserId?])
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

  public static let testValue: Self = Self(
    pushNotificationTapStream: { AsyncStream { _ in } },
    parseURL: { _ in nil },
    parseNotification: { _ in nil }
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
  /// - scheduleAndGroup: scheduleId + groupId 필요 → .schedule
  /// - groupOnly: groupId만 필요 → .group
  /// - none: 딥링크 불필요 (system 등) → nil
  ///
  /// - Note: joinGroup은 URL 딥링크 전용 (푸시 알림에서는 inviteCode 미전송)
  private static func parseUserInfo(_ userInfo: [AnyHashable: Any]) -> DeeplinkDestination? {
    // 1. type 추출 및 NotificationType 변환
    guard let typeString = userInfo["type"] as? String,
          let type = NotificationType.fromWireValue(typeString) else {
      return nil
    }

    // 2. 필드 추출
    let scheduleId = (userInfo["scheduleId"] as? String) ?? (userInfo["promiseId"] as? String)
    let groupId = userInfo["groupId"] as? String

    // 3. deeplinkGuide에 따라 검증 및 변환
    switch type.deeplinkGuide {
    case .scheduleAndGroup:
      guard let scheduleId, let groupId else { return nil }
      return .schedule(scheduleId: scheduleId, groupId: groupId)

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
