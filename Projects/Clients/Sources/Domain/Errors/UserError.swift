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
    case .friendly: return "상냥한"
    case .humorous: return "유머러스"
    case .concise: return "간결한"
    case .motivational: return "응원하는"
    case .calm: return "차분한"
    }
  }

  public var description: String {
    switch self {
    case .friendly: return "따뜻하고 친근한 말투"
    case .humorous: return "위트 있는 말투, 가벼운 드립"
    case .concise: return "핵심만 짧게, 이모지 최소"
    case .motivational: return "긍정적 에너지와 격려"
    case .calm: return "조용하고 편안한 톤"
    }
  }
}

// MARK: - Preferred Transport

/// 선호 교통수단
public enum PreferredTransport: String, CaseIterable, Equatable, Sendable {
  case all
  case transit
  case car

  public var displayName: String {
    switch self {
    case .all: return "모두 보기"
    case .transit: return "대중교통 위주"
    case .car: return "자차 위주"
    }
  }

  public var description: String {
    switch self {
    case .all: return "자동차, 대중교통 골고루 안내해요"
    case .transit: return "대중교통 중심으로 안내해요"
    case .car: return "자동차 중심으로 안내해요"
    }
  }

  public var iconName: String {
    switch self {
    case .all: return "arrow.triangle.branch"
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
  public var preferredTransport: PreferredTransport

  public init(
    notificationEnabled: Bool,
    groupSortOption: GroupSortOption = .joinedRecent,
    conflictDetectionThreshold: Int = 0,
    briefingStyle: BriefingStyle = .friendly,
    briefingNotificationHour: Int? = nil,
    preferredTransport: PreferredTransport = .all
  ) {
    self.notificationEnabled = notificationEnabled
    self.groupSortOption = groupSortOption
    self.conflictDetectionThreshold = conflictDetectionThreshold
    self.briefingStyle = briefingStyle
    self.briefingNotificationHour = briefingNotificationHour
    self.preferredTransport = preferredTransport
  }

  /// 기본 설정값
  public static let `default` = UserSettings(
    notificationEnabled: true,
    groupSortOption: .joinedRecent,
    conflictDetectionThreshold: 0
  )
}
