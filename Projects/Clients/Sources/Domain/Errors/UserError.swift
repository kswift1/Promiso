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

// MARK: - Briefing Style

/// 브리핑 스타일 종류
public enum BriefingStyle: String, CaseIterable, Equatable, Sendable {
  case friendly
  case humorous
  case concise
  case motivational
  case calm

  public var displayName: String {
    switch self {
    case .friendly: return LocalizedStrings.SettingsStrings.briefingStyleFriendly
    case .humorous: return LocalizedStrings.SettingsStrings.briefingStyleHumorous
    case .concise: return LocalizedStrings.SettingsStrings.briefingStyleConcise
    case .motivational: return LocalizedStrings.SettingsStrings.briefingStyleMotivational
    case .calm: return LocalizedStrings.SettingsStrings.briefingStyleCalm
    }
  }

  public var description: String {
    switch self {
    case .friendly: return LocalizedStrings.SettingsStrings.briefingStyleFriendlyDescription
    case .humorous: return LocalizedStrings.SettingsStrings.briefingStyleHumorousDescription
    case .concise: return LocalizedStrings.SettingsStrings.briefingStyleConciseDescription
    case .motivational: return LocalizedStrings.SettingsStrings.briefingStyleMotivationalDescription
    case .calm: return LocalizedStrings.SettingsStrings.briefingStyleCalmDescription
    }
  }
}

// MARK: - Available Transport

/// 이용 가능 교통수단
public enum AvailableTransport: String, CaseIterable, Equatable, Sendable {
  case transit
  case car

  public var displayName: String {
    switch self {
    case .transit: return LocalizedStrings.SettingsStrings.briefingTransportTransit
    case .car: return LocalizedStrings.SettingsStrings.briefingTransportCar
    }
  }

  public var iconName: String {
    switch self {
    case .transit: return "bus.fill"
    case .car: return "car.fill"
    }
  }
}

// MARK: - User Settings

/// 사용자 설정 정보
public struct UserSettings: Equatable, Sendable {
  public var notificationEnabled: Bool
  public var groupSortOption: GroupSortOption
  public var conflictDetectionThreshold: Int
  public var briefingStyle: BriefingStyle
  public var briefingNotificationHour: Int?
  public var availableTransports: Set<AvailableTransport>
  public var briefingDefaultLocation: LocationInfoModel?

  public init(
    notificationEnabled: Bool,
    groupSortOption: GroupSortOption = .joinedRecent,
    conflictDetectionThreshold: Int = 0,
    briefingStyle: BriefingStyle = .friendly,
    briefingNotificationHour: Int? = nil,
    availableTransports: Set<AvailableTransport> = [.transit, .car],
    briefingDefaultLocation: LocationInfoModel? = nil
  ) {
    self.notificationEnabled = notificationEnabled
    self.groupSortOption = groupSortOption
    self.conflictDetectionThreshold = conflictDetectionThreshold
    self.briefingStyle = briefingStyle
    self.briefingNotificationHour = briefingNotificationHour
    self.availableTransports = availableTransports
    self.briefingDefaultLocation = briefingDefaultLocation
  }

  /// 기본 설정값
  public static let `default` = UserSettings(
    notificationEnabled: true,
    groupSortOption: .joinedRecent,
    conflictDetectionThreshold: 0
  )
}
