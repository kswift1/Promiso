import Foundation

/// 일정 제안 시 그룹원에게 보낼 알림 방법
public enum ScheduleNotificationMethod: String, Codable, Sendable, Equatable, CaseIterable {
  case pushNotification = "pushNotification"
  case liveActivity = "liveActivity"
  case none = "none"
}

