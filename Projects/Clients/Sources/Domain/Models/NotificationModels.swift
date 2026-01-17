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

// MARK: - Device Info

/// 디바이스 정보
public struct DeviceInfo: Equatable, Sendable, Codable {
  public let fcmToken: String
  public let platform: String
  public let lastActiveAt: Date
  public let createdAt: Date

  public init(
    fcmToken: String,
    platform: String = "ios",
    lastActiveAt: Date = Date(),
    createdAt: Date = Date()
  ) {
    self.fcmToken = fcmToken
    self.platform = platform
    self.lastActiveAt = lastActiveAt
    self.createdAt = createdAt
  }
}
