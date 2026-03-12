import ComposableArchitecture
import Foundation
import FirebaseAnalytics

// MARK: - Client

public struct AnalyticsClient: Sendable {
  /// Analytics 이벤트 로깅
  public var logEvent: @Sendable (String, [String: Any]?) -> Void

  /// Analytics 유저 ID 설정
  public var setUserID: @Sendable (String?) -> Void

  /// Analytics 유저 속성 설정
  public var setUserProperty: @Sendable (String?, String) -> Void
}

// MARK: - Test / Preview

extension AnalyticsClient: TestDependencyKey {
  public static let previewValue = Self(
    logEvent: { _, _ in },
    setUserID: { _ in },
    setUserProperty: { _, _ in }
  )

  public static let testValue = Self(
    logEvent: unimplemented("\(Self.self).logEvent"),
    setUserID: unimplemented("\(Self.self).setUserID"),
    setUserProperty: unimplemented("\(Self.self).setUserProperty")
  )
}

// MARK: - Live

extension AnalyticsClient: DependencyKey {
  public static let liveValue = Self(
    logEvent: { name, parameters in
      Analytics.logEvent(name, parameters: parameters)
    },
    setUserID: { userID in
      Analytics.setUserID(userID)
    },
    setUserProperty: { value, name in
      Analytics.setUserProperty(value, forName: name)
    }
  )
}

// MARK: - Dependency Registration

public extension DependencyValues {
  var analyticsClient: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}

// MARK: - Event Names

public extension AnalyticsClient {
  /// Analytics 이벤트 이름 상수
  enum EventName {
    // 🎯 핵심 비즈니스
    public static let userSignup = "user_signup"
    public static let userLogin = "user_login"
    public static let groupCreated = "group_created"
    public static let groupJoined = "group_joined"
    public static let scheduleCreated = "schedule_created"
    public static let scheduleResponseYes = "schedule_response_yes"
    public static let scheduleResponseNo = "schedule_response_no"

    // 📱 사용자 행동
    public static let profileSetupCompleted = "profile_setup_completed"
    public static let groupInviteShared = "group_invite_shared"
    public static let settingsOpened = "settings_opened"
    public static let paywallOpen = "paywall_open"
    public static let paywallPurchase = "paywall_purchase"
    public static let paywallRestore = "paywall_restore"
    public static let paywallClose = "paywall_close"

    // 🔔 알림
    public static let notificationPermissionRequested = "notification_permission_requested"
    public static let notificationPermissionGranted = "notification_permission_granted"
  }

  /// Analytics 파라미터 키 상수
  enum ParameterKey {
    public static let groupID = "group_id"
    public static let groupName = "group_name"
    public static let scheduleID = "schedule_id"
    public static let scheduleTitle = "schedule_title"
    public static let responseType = "response_type"
    public static let loginMethod = "login_method"
  }
}
