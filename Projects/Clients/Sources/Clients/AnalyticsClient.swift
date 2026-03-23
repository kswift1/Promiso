import ComposableArchitecture
import Foundation
import FirebaseAnalytics
import PromisoShared

// MARK: - Client

public struct AnalyticsClient: Sendable {
  /// Analytics 이벤트 로깅
  public var logEvent: @Sendable (String, [String: Any]?) -> Void

  /// Analytics 유저 ID 설정
  public var setUserID: @Sendable (String?) -> Void

  /// Analytics 유저 속성 설정
  public var setUserProperty: @Sendable (String?, String) -> Void
}

// MARK: - Typed Analytics

public extension AnalyticsClient {
  public enum ParameterValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var rawValue: Any {
      switch self {
      case .string(let value):
        value
      case .int(let value):
        value
      case .double(let value):
        value
      case .bool(let value):
        value
      }
    }
  }

  public struct Event: Equatable, Sendable {
    public let name: String
    public let parameters: [String: ParameterValue]

    public init(name: String, parameters: [String: ParameterValue] = [:]) {
      self.name = name
      self.parameters = parameters
    }
  }

  public enum ScreenName: String, CaseIterable, Sendable {
    case notificationPermission = "notification_permission"
    case createGroup = "create_group"
    case joinGroup = "join_group"
    case groupMain = "group_main"
    case groupSettings = "group_settings"
    case createSchedule = "create_schedule"
    case scheduleDetail = "schedule_detail"
    case paywall = "paywall"

    var screenClass: String {
      switch self {
      case .notificationPermission:
        "NotificationPermissionView"
      case .createGroup:
        "CreateGroupView"
      case .joinGroup:
        "JoinGroupView"
      case .groupMain:
        "GroupMainView"
      case .groupSettings:
        "GroupSettingsView"
      case .createSchedule:
        "CreateScheduleView"
      case .scheduleDetail:
        "ScheduleDetailView"
      case .paywall:
        "PaywallView"
      }
    }
  }

  public enum ShareMethod: String, Sendable {
    case kakao
    case system
  }

  public enum UserPropertyKey: String, Sendable {
    case nickname = "nickname"
    case authProvider = "auth_provider"
    case subscriptionTier = "subscription_tier"
    case notificationPermissionStatus = "notification_permission_status"
    case hasGroup = "has_group"
    case groupCountBucket = "group_count_bucket"
    case calendarSyncEnabled = "calendar_sync_enabled"
    case signupDate = "signup_date"
    case activationStatus = "activation_status"
  }

  public enum ActivationStatus: String, Sendable {
    case signedUp = "signed_up"
    case groupJoined = "group_joined"
    case scheduleResponded = "schedule_responded"

    var level: Int {
      switch self {
      case .signedUp: 0
      case .groupJoined: 1
      case .scheduleResponded: 2
      }
    }
  }
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
    setUserProperty: { _, _ in }
  )
}

// MARK: - Live

extension AnalyticsClient: DependencyKey {
  public static let liveValue = Self(
    logEvent: { name, parameters in
      let sanitizedName = Self.sanitizeEventName(name)
      let sanitizedParameters = Self.sanitizeParameters(parameters)

      if AppLogger.isDebugEnabled {
        AppLogger.general.debug(
          "Analytics event: \(sanitizedName, privacy: .public)"
        )
      }

      Analytics.logEvent(sanitizedName, parameters: sanitizedParameters)
    },
    setUserID: { userID in
      Analytics.setUserID(Self.sanitizeUserID(userID))
    },
    setUserProperty: { value, name in
      Analytics.setUserProperty(
        Self.sanitizeUserPropertyValue(value),
        forName: Self.sanitizeUserPropertyName(name)
      )
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
  public enum EventName {
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
    public static let groupInviteLinkShared = "group_invite_link_shared"
    public static let settingsOpened = "settings_opened"
    public static let scheduleShareSheetOpened = "schedule_share_sheet_opened"
    public static let scheduleLinkShared = "schedule_link_shared"
    public static let paywallOpen = "paywall_open"
    public static let paywallPurchase = "paywall_purchase"
    public static let paywallRestore = "paywall_restore"
    public static let paywallClose = "paywall_close"

    // 📊 그룹 생성 퍼널
    public static let groupCreateTapped = "group_create_tapped"
    public static let groupCreateSucceeded = "group_create_succeeded"
    public static let groupCreateFailed = "group_create_failed"
    public static let groupCreateSettingsCompleted = "group_create_settings_completed"
    public static let groupCreateCancelled = "group_create_cancelled"

    // 📊 신규 유저 퍼널
    public static let inviteLinkOpened = "invite_link_opened"
    public static let onboardingStepViewed = "onboarding_step_viewed"
    public static let firstScheduleResponse = "first_schedule_response"
    public static let homeEmptyStateShown = "home_empty_state_shown"

    // 🔔 알림
    public static let notificationPermissionRequested = "notification_permission_requested"
    public static let notificationPermissionGranted = "notification_permission_granted"
    public static let notificationPermissionDenied = "notification_permission_denied"
  }

  /// Analytics 파라미터 키 상수
  public enum ParameterKey {
    public static let screenName = AnalyticsParameterScreenName
    public static let screenClass = AnalyticsParameterScreenClass
    public static let groupID = "group_id"
    public static let groupName = "group_name"
    public static let scheduleID = "schedule_id"
    public static let scheduleTitle = "schedule_title"
    public static let responseType = "response_type"
    public static let loginMethod = "login_method"
    public static let shareMethod = "share_method"
    public static let scheduleCount = "schedule_count"
    public static let productID = "product_id"
    public static let hasIntroOffer = "has_intro_offer"
    public static let errorMessage = "error_message"
    public static let step = "step"
    public static let inviteCode = "invite_code"
    public static let source = "source"
    public static let onboardingStep = "onboarding_step"
  }
}

// MARK: - Convenience API

public extension AnalyticsClient {
  public func log(_ event: Event) {
    let parameters = event.parameters.isEmpty
      ? nil
      : event.parameters.mapValues(\.rawValue)

    logEvent(event.name, parameters)
  }

  public func logScreen(
    _ screen: ScreenName,
    additionalParameters: [String: ParameterValue] = [:]
  ) {
    var parameters = additionalParameters
    parameters[ParameterKey.screenName] = .string(screen.rawValue)
    parameters[ParameterKey.screenClass] = .string(screen.screenClass)
    log(Event(name: AnalyticsEventScreenView, parameters: parameters))
  }

  public func setUserProperty(_ value: String?, _ key: UserPropertyKey) {
    setUserProperty(value, key.rawValue)
  }

  public func setSubscriptionTier(_ status: SubscriptionStatus) {
    setUserProperty(UserPropertyValue.subscriptionTier(status), .subscriptionTier)
  }

  public func setNotificationPermissionStatus(_ status: NotificationAuthorizationStatus) {
    setUserProperty(
      UserPropertyValue.notificationPermissionStatus(status),
      .notificationPermissionStatus
    )
  }

  public func setGroupMembershipProperties(_ groups: [UserGroupInfo]) {
    setUserProperty(UserPropertyValue.boolean(!groups.isEmpty), .hasGroup)
    setUserProperty(UserPropertyValue.groupCountBucket(groups.count), .groupCountBucket)
  }

  public func setCalendarSyncEnabled(personalEnabled: Bool, groups: [UserGroupInfo]) {
    setUserProperty(
      UserPropertyValue.boolean(
        UserPropertyValue.isAnyCalendarSyncEnabled(
          personalEnabled: personalEnabled,
          groups: groups
        )
      ),
      .calendarSyncEnabled
    )
  }

  public func updateActivationStatus(_ status: ActivationStatus) {
    let key = "com.promiso.analytics.activationLevel"
    let currentLevel = UserDefaults.standard.integer(forKey: key)
    guard status.level > currentLevel else { return }
    UserDefaults.standard.set(status.level, forKey: key)
    setUserProperty(status.rawValue, .activationStatus)
  }

  public func logFirstScheduleResponseIfNeeded(scheduleID: String, scheduleTitle: String) {
    let key = "com.promiso.analytics.firstScheduleResponseFired"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    log(.firstScheduleResponse(scheduleID: scheduleID, scheduleTitle: scheduleTitle))
    updateActivationStatus(.scheduleResponded)
  }
}

public extension AnalyticsClient.Event {
  public static func userSignup(loginMethod: String? = nil) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.userSignup,
      optionalParameters: [AnalyticsClient.ParameterKey.loginMethod: loginMethod]
    )
  }

  public static func userLogin(loginMethod: String? = nil) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.userLogin,
      optionalParameters: [AnalyticsClient.ParameterKey.loginMethod: loginMethod]
    )
  }

  public static let profileSetupCompleted = Self(name: AnalyticsClient.EventName.profileSetupCompleted)
  public static let settingsOpened = Self(name: AnalyticsClient.EventName.settingsOpened)
  public static let notificationPermissionRequested = Self(name: AnalyticsClient.EventName.notificationPermissionRequested)
  public static let notificationPermissionGranted = Self(name: AnalyticsClient.EventName.notificationPermissionGranted)
  public static let notificationPermissionDenied = Self(name: AnalyticsClient.EventName.notificationPermissionDenied)
  public static let paywallRestore = Self(name: AnalyticsClient.EventName.paywallRestore)
  public static let paywallClose = Self(name: AnalyticsClient.EventName.paywallClose)

  public static func groupCreated(groupID: String, groupName: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupCreated,
      [
        AnalyticsClient.ParameterKey.groupID: groupID,
        AnalyticsClient.ParameterKey.groupName: groupName
      ]
    )
  }

  public static let groupCreateTapped = Self(name: AnalyticsClient.EventName.groupCreateTapped)

  public static func groupCreateSucceeded(groupID: String, groupName: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupCreateSucceeded,
      [
        AnalyticsClient.ParameterKey.groupID: groupID,
        AnalyticsClient.ParameterKey.groupName: groupName
      ]
    )
  }

  public static func groupCreateFailed(errorMessage: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupCreateFailed,
      [AnalyticsClient.ParameterKey.errorMessage: errorMessage]
    )
  }

  public static func groupCreateSettingsCompleted(groupID: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupCreateSettingsCompleted,
      [AnalyticsClient.ParameterKey.groupID: groupID]
    )
  }

  public static func groupCreateCancelled(step: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupCreateCancelled,
      [AnalyticsClient.ParameterKey.step: step]
    )
  }

  public static func inviteLinkOpened(inviteCode: String, source: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.inviteLinkOpened,
      [
        AnalyticsClient.ParameterKey.inviteCode: inviteCode,
        AnalyticsClient.ParameterKey.source: source
      ]
    )
  }

  public static func onboardingStepViewed(step: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.onboardingStepViewed,
      [AnalyticsClient.ParameterKey.onboardingStep: step]
    )
  }

  public static func firstScheduleResponse(scheduleID: String, scheduleTitle: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.firstScheduleResponse,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle
      ]
    )
  }

  public static let homeEmptyStateShown = Self(name: AnalyticsClient.EventName.homeEmptyStateShown)

  public static func groupJoined(groupID: String, groupName: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupJoined,
      [
        AnalyticsClient.ParameterKey.groupID: groupID,
        AnalyticsClient.ParameterKey.groupName: groupName
      ]
    )
  }

  public static func groupInviteSheetOpened(groupID: String, groupName: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.groupInviteShared,
      [
        AnalyticsClient.ParameterKey.groupID: groupID,
        AnalyticsClient.ParameterKey.groupName: groupName
      ]
    )
  }

  public static func groupInviteLinkShared(
    groupID: String,
    groupName: String,
    shareMethod: AnalyticsClient.ShareMethod,
    scheduleCount: Int? = nil
  ) -> Self {
    var parameters: [String: AnalyticsClient.ParameterValue] = [
      AnalyticsClient.ParameterKey.groupID: .string(groupID),
      AnalyticsClient.ParameterKey.groupName: .string(groupName),
      AnalyticsClient.ParameterKey.shareMethod: .string(shareMethod.rawValue)
    ]

    if let scheduleCount {
      parameters[AnalyticsClient.ParameterKey.scheduleCount] = .int(scheduleCount)
    }

    return Self(name: AnalyticsClient.EventName.groupInviteLinkShared, parameters: parameters)
  }

  public static func scheduleCreated(scheduleID: String, scheduleTitle: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.scheduleCreated,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle
      ]
    )
  }

  public static func scheduleResponseYes(scheduleID: String, scheduleTitle: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.scheduleResponseYes,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle
      ]
    )
  }

  public static func scheduleResponseNo(scheduleID: String, scheduleTitle: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.scheduleResponseNo,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle
      ]
    )
  }

  public static func scheduleShareSheetOpened(scheduleID: String, scheduleTitle: String) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.scheduleShareSheetOpened,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle
      ]
    )
  }

  public static func scheduleLinkShared(
    scheduleID: String,
    scheduleTitle: String,
    shareMethod: AnalyticsClient.ShareMethod
  ) -> Self {
    analyticsEvent(
      AnalyticsClient.EventName.scheduleLinkShared,
      [
        AnalyticsClient.ParameterKey.scheduleID: scheduleID,
        AnalyticsClient.ParameterKey.scheduleTitle: scheduleTitle,
        AnalyticsClient.ParameterKey.shareMethod: shareMethod.rawValue
      ]
    )
  }

  public static func paywallOpen(hasIntroOffer: Bool) -> Self {
    Self(
      name: AnalyticsClient.EventName.paywallOpen,
      parameters: [AnalyticsClient.ParameterKey.hasIntroOffer: .bool(hasIntroOffer)]
    )
  }

  public static func paywallPurchase(productID: String) -> Self {
    Self(
      name: AnalyticsClient.EventName.paywallPurchase,
      parameters: [AnalyticsClient.ParameterKey.productID: .string(productID)]
    )
  }

  private static func analyticsEvent(_ name: String, _ parameters: [String: String]) -> Self {
    Self(
      name: name,
      parameters: parameters.mapValues { .string($0) }
    )
  }

  private static func analyticsEvent(
    _ name: String,
    optionalParameters: [String: String?]
  ) -> Self {
    Self(
      name: name,
      parameters: optionalParameters.compactMapValues { value in
        guard let value else { return nil }
        return .string(value)
      }
    )
  }
}

// MARK: - Sanitization

extension AnalyticsClient {
  private enum UserPropertyValue {
    static func boolean(_ value: Bool) -> String {
      value ? "true" : "false"
    }

    static func subscriptionTier(_ status: SubscriptionStatus) -> String {
      status.isPro ? "pro" : "free"
    }

    static func notificationPermissionStatus(_ status: NotificationAuthorizationStatus) -> String {
      switch status {
      case .notDetermined:
        "not_determined"
      case .denied:
        "denied"
      case .authorized:
        "authorized"
      case .provisional:
        "provisional"
      case .ephemeral:
        "ephemeral"
      }
    }

    static func groupCountBucket(_ count: Int) -> String {
      switch count {
      case ..<1:
        "0"
      case 1:
        "1"
      case 2...4:
        "2_4"
      default:
        "5_plus"
      }
    }

    static func isAnyCalendarSyncEnabled(
      personalEnabled: Bool,
      groups: [UserGroupInfo]
    ) -> Bool {
      personalEnabled || groups.contains { $0.notifications?.calendarSync ?? true }
    }
  }

  private enum Limits {
    static let eventName = 40
    static let parameterKey = 40
    static let parameterStringValue = 100
    static let userPropertyName = 24
    static let userPropertyValue = 36
    static let userID = 256
  }

  static func sanitizeParameters(_ parameters: [String: Any]?) -> [String: Any]? {
    guard let parameters else { return nil }

    var sanitized: [String: Any] = [:]
    sanitized.reserveCapacity(parameters.count)

    for (rawKey, rawValue) in parameters {
      let key = sanitizeKey(rawKey, maxLength: Limits.parameterKey)
      guard !key.isEmpty, let value = sanitizeValue(rawValue) else { continue }
      sanitized[key] = value
    }

    return sanitized.isEmpty ? nil : sanitized
  }

  private static func sanitizeEventName(_ name: String) -> String {
    sanitizeKey(name, maxLength: Limits.eventName)
  }

  private static func sanitizeUserPropertyName(_ name: String) -> String {
    sanitizeKey(name, maxLength: Limits.userPropertyName)
  }

  private static func sanitizeUserPropertyValue(_ value: String?) -> String? {
    guard let value else { return nil }
    return String(value.prefix(Limits.userPropertyValue))
  }

  private static func sanitizeUserID(_ userID: String?) -> String? {
    guard let userID else { return nil }
    return String(userID.prefix(Limits.userID))
  }

  private static func sanitizeKey(_ key: String, maxLength: Int) -> String {
    String(key.prefix(maxLength))
  }

  private static func sanitizeValue(_ value: Any) -> Any? {
    switch value {
    case let value as String:
      return String(value.prefix(Limits.parameterStringValue))
    case let value as Int:
      return value
    case let value as Int64:
      return Int(truncatingIfNeeded: value)
    case let value as Double:
      return value
    case let value as Float:
      return Double(value)
    case let value as Bool:
      return value
    case let value as NSNumber:
      return value
    default:
      return nil
    }
  }
}
