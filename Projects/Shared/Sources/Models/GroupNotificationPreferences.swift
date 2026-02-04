import Foundation

public enum GroupNotificationCategory: String, CaseIterable, Sendable {
  case promise
  case group
}

public enum GroupNotificationPreferenceKey: String, CaseIterable, Sendable {
  case promiseInvitation
  case promiseConfirmed
  case promiseCancelled
  case promiseUpdated
  case groupUpdate

  public var category: GroupNotificationCategory {
    switch self {
    case .promiseInvitation,
         .promiseConfirmed,
         .promiseCancelled,
         .promiseUpdated:
      return .promise
    case .groupUpdate:
      return .group
    }
  }

  public var storageKey: String {
    switch self {
    case .promiseInvitation: return "invitation"
    case .promiseConfirmed: return "confirmed"
    case .promiseCancelled: return "cancelled"
    case .promiseUpdated: return "updated"
    case .groupUpdate: return "update"
    }
  }

  public var title: String {
    switch self {
    case .promiseInvitation:
      return "약속 초대"
    case .promiseConfirmed:
      return "약속 확정"
    case .promiseCancelled:
      return "약속 취소"
    case .promiseUpdated:
      return "약속 변경"
    case .groupUpdate:
      return "그룹 업데이트"
    }
  }

  public var subtitle: String? {
    switch self {
    case .groupUpdate:
      return "그룹 정보/멤버 변동 알림"
    default:
      return nil
    }
  }
}

public struct GroupNotificationSettings: Codable, Equatable, Hashable, Sendable {
  public var enabled: Bool
  public var promise: [String: Bool]
  public var group: [String: Bool]
  public var calendarSync: Bool

  public init(
    enabled: Bool = true,
    promise: [String: Bool] = GroupNotificationPreferences.defaultPromise,
    group: [String: Bool] = GroupNotificationPreferences.defaultGroup,
    calendarSync: Bool = true
  ) {
    self.enabled = enabled
    self.promise = GroupNotificationPreferences.mergeDefaults(
      source: promise,
      defaults: GroupNotificationPreferences.defaultPromise
    )
    self.group = GroupNotificationPreferences.mergeDefaults(
      source: group,
      defaults: GroupNotificationPreferences.defaultGroup
    )
    self.calendarSync = calendarSync
  }

  public func value(for key: GroupNotificationPreferenceKey) -> Bool {
    switch key.category {
    case .promise:
      return promise[key.storageKey] ?? true
    case .group:
      return group[key.storageKey] ?? true
    }
  }

  public mutating func setValue(_ enabled: Bool, for key: GroupNotificationPreferenceKey) {
    switch key.category {
    case .promise:
      promise[key.storageKey] = enabled
    case .group:
      group[key.storageKey] = enabled
    }
  }

  public var asDictionary: [String: Any] {
    [
      "enabled": enabled,
      "promise": promise,
      "group": group,
      "calendarSync": calendarSync,
    ]
  }
}

public enum GroupNotificationPreferences {
  public static let defaultPromise: [String: Bool] = [
    "invitation": true,
    "reminder": true,
    "confirmed": true,
    "cancelled": true,
    "updated": true,
    "attendanceResponse": true,
  ]

  public static let defaultGroup: [String: Bool] = [
    "update": true,
  ]

  public static func value(
    for key: GroupNotificationPreferenceKey,
    in settings: GroupNotificationSettings?
  ) -> Bool {
    settings?.value(for: key) ?? true
  }

  public static func mergeDefaults(
    source: [String: Bool],
    defaults: [String: Bool]
  ) -> [String: Bool] {
    defaults.merging(source) { _, incoming in incoming }
  }

  public static func fromLegacy(
    enabled: Bool,
    preferences: [String: Bool]?
  ) -> GroupNotificationSettings {
    let promise = mergeDefaults(
      source: legacyPromise(from: preferences),
      defaults: defaultPromise
    )
    let group = mergeDefaults(
      source: legacyGroup(from: preferences),
      defaults: defaultGroup
    )
    return GroupNotificationSettings(enabled: enabled, promise: promise, group: group)
  }

  private static func legacyPromise(from preferences: [String: Bool]?) -> [String: Bool] {
    guard let preferences else { return [:] }
    return [
      "invitation": preferences["promiseInvitation"],
      "reminder": preferences["promiseReminder"],
      "confirmed": preferences["promiseConfirmed"],
      "cancelled": preferences["promiseCancelled"],
      "updated": preferences["promiseUpdated"],
      "attendanceResponse": preferences["attendanceResponse"],
    ].compactMapValues { $0 }
  }

  private static func legacyGroup(from preferences: [String: Bool]?) -> [String: Bool] {
    guard let preferences else { return [:] }
    return [
      "update": preferences["groupUpdate"],
    ].compactMapValues { $0 }
  }
}
