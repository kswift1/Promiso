import Foundation
import PromisoShared

// MARK: - User Profile Errors

/// 사용자 프로필 관련 에러
public enum UserProfileError: Error, Equatable {
  case invalidData
  case userNotFound
  case uploadFailed
  case networkError
  case authenticationRequired
  case permissionDenied
}

// MARK: - Provider Info

/// 인증 제공자 정보
public struct ProviderInfo: Equatable, Sendable {
  public let type: String
  public let uid: String
  public let email: String

  public init(type: String, uid: String, email: String) {
    self.type = type
    self.uid = uid
    self.email = email
  }
}

// MARK: - User Settings

/// 사용자 플랜
public enum UserPlan: String, Codable, Equatable, Sendable {
  case free
  case pro

  public var displayName: String {
    switch self {
    case .free:
      return "무료"
    case .pro:
      return "프로"
    }
  }
}

/// 사용자 설정 정보
public struct UserSettings: Equatable, Sendable {
  public var notificationEnabled: Bool
  public var groupSortOption: GroupSortOption
  public var plan: UserPlan
  public var conflictDetectionThreshold: Int

  public init(
    notificationEnabled: Bool,
    groupSortOption: GroupSortOption = .joinedRecent,
    plan: UserPlan = .free,
    conflictDetectionThreshold: Int = 0
  ) {
    self.notificationEnabled = notificationEnabled
    self.groupSortOption = groupSortOption
    self.plan = plan
    self.conflictDetectionThreshold = conflictDetectionThreshold
  }

  /// 기본 설정값
  public static let `default` = UserSettings(
    notificationEnabled: true,
    groupSortOption: .joinedRecent,
    plan: .free,
    conflictDetectionThreshold: 0
  )
}
