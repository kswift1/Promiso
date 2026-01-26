import Foundation

public enum GroupNotificationPreferenceKey: String, CaseIterable, Sendable {
  case promiseInvitation
  case promiseReminder
  case promiseConfirmed
  case promiseCancelled
  case promiseUpdated
  case attendanceResponse
  case groupInvitation
  case groupUpdate

  public var title: String {
    switch self {
    case .promiseInvitation:
      return "약속 초대"
    case .promiseReminder:
      return "약속 리마인더"
    case .promiseConfirmed:
      return "약속 확정"
    case .promiseCancelled:
      return "약속 취소"
    case .promiseUpdated:
      return "약속 변경"
    case .attendanceResponse:
      return "응답 변경"
    case .groupInvitation:
      return "그룹 초대"
    case .groupUpdate:
      return "그룹 업데이트"
    }
  }

  public var subtitle: String? {
    switch self {
    case .promiseReminder:
      return "약속 전 리마인더 알림"
    case .attendanceResponse:
      return "참석/불참 응답 변경 알림"
    case .groupUpdate:
      return "그룹 정보 변경 알림"
    default:
      return nil
    }
  }
}

public enum GroupNotificationPreferences {
  public static let allEnabled: [String: Bool] = {
    Dictionary(uniqueKeysWithValues: GroupNotificationPreferenceKey.allCases.map { ($0.rawValue, true) })
  }()

  public static func value(
    for key: GroupNotificationPreferenceKey,
    in preferences: [String: Bool]?
  ) -> Bool {
    preferences?[key.rawValue] ?? true
  }
}
