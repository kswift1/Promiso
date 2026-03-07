import Foundation
import UserNotifications

// MARK: - Notification Authorization Status

/// 알림 권한 상태
public enum NotificationAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case denied
  case authorized
  case provisional
  case ephemeral

  public var isGranted: Bool {
    switch self {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined, .denied:
      return false
    }
  }

  public init(from status: UNAuthorizationStatus) {
    switch status {
    case .notDetermined: self = .notDetermined
    case .denied: self = .denied
    case .authorized: self = .authorized
    case .provisional: self = .provisional
    case .ephemeral: self = .ephemeral
    @unknown default: self = .notDetermined
    }
  }
}

