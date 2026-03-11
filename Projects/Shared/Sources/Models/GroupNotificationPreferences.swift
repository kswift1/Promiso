import Foundation

public enum GroupNotificationCategory: String, CaseIterable, Sendable {
  case schedule
  case group
}

public enum GroupNotificationPreferenceKey: String, CaseIterable, Sendable {
  case scheduleInvitation
  case scheduleConfirmed
  case scheduleCancelled
  case scheduleUpdated
  case groupUpdate

  public var category: GroupNotificationCategory {
    switch self {
    case .scheduleInvitation,
         .scheduleConfirmed,
         .scheduleCancelled,
         .scheduleUpdated:
      return .schedule
    case .groupUpdate:
      return .group
    }
  }

  public var storageKey: String {
    switch self {
    case .scheduleInvitation: return "invitation"
    case .scheduleConfirmed: return "confirmed"
    case .scheduleCancelled: return "cancelled"
    case .scheduleUpdated: return "updated"
    case .groupUpdate: return "update"
    }
  }

  public var title: String {
    switch self {
    case .scheduleInvitation:
      return "일정 초대"
    case .scheduleConfirmed:
      return "일정 확정"
    case .scheduleCancelled:
      return "일정 취소"
    case .scheduleUpdated:
      return "일정 변경"
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
  public var schedule: [String: Bool]
  public var group: [String: Bool]
  public var calendarSync: Bool

  public init(
    enabled: Bool = true,
    schedule: [String: Bool] = GroupNotificationPreferences.defaultSchedule,
    group: [String: Bool] = GroupNotificationPreferences.defaultGroup,
    calendarSync: Bool = true
  ) {
    self.enabled = enabled
    self.schedule = GroupNotificationPreferences.mergeDefaults(
      source: schedule,
      defaults: GroupNotificationPreferences.defaultSchedule
    )
    self.group = GroupNotificationPreferences.mergeDefaults(
      source: group,
      defaults: GroupNotificationPreferences.defaultGroup
    )
    self.calendarSync = calendarSync
  }

  public func value(for key: GroupNotificationPreferenceKey) -> Bool {
    switch key.category {
    case .schedule:
      return schedule[key.storageKey] ?? true
    case .group:
      return group[key.storageKey] ?? true
    }
  }

  public mutating func setValue(_ enabled: Bool, for key: GroupNotificationPreferenceKey) {
    switch key.category {
    case .schedule:
      schedule[key.storageKey] = enabled
    case .group:
      group[key.storageKey] = enabled
    }
  }

  public var asDictionary: [String: Any] {
    [
      "enabled": enabled,
      "schedule": schedule,
      "group": group,
      "calendarSync": calendarSync,
    ]
  }
}

public enum GroupNotificationPreferences {
  public static let defaultSchedule: [String: Bool] = [
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
    let schedule = mergeDefaults(
      source: legacySchedule(from: preferences),
      defaults: defaultSchedule
    )
    let group = mergeDefaults(
      source: legacyGroup(from: preferences),
      defaults: defaultGroup
    )
    return GroupNotificationSettings(enabled: enabled, schedule: schedule, group: group)
  }

  private static func legacySchedule(from preferences: [String: Bool]?) -> [String: Bool] {
    guard let preferences else { return [:] }
    return [
      "invitation": preferences["scheduleInvitation"],
      "reminder": preferences["scheduleReminder"],
      "confirmed": preferences["scheduleConfirmed"],
      "cancelled": preferences["scheduleCancelled"],
      "updated": preferences["scheduleUpdated"],
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
