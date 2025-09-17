//import Foundation
//
//// MARK: - User Model
//
///// 사용자 정보를 나타내는 도메인 모델
//public struct User: Equatable, Codable, Identifiable, Sendable {
//  public let id: UUID
//  public let email: String
//  public let name: String
//  public let profileImageURL: String?
//  public let phoneNumber: String?
//  public let createdAt: Date
//  public let updatedAt: Date
//  public let isEmailVerified: Bool
//  public let isPhoneVerified: Bool
//  public let status: UserStatus
//  
//  public init(
//    id: UUID = UUID(),
//    email: String,
//    name: String,
//    profileImageURL: String? = nil,
//    phoneNumber: String? = nil,
//    createdAt: Date = Date(),
//    updatedAt: Date = Date(),
//    isEmailVerified: Bool = false,
//    isPhoneVerified: Bool = false,
//    status: UserStatus = .active
//  ) {
//    self.id = id
//    self.email = email
//    self.name = name
//    self.profileImageURL = profileImageURL
//    self.phoneNumber = phoneNumber
//    self.createdAt = createdAt
//    self.updatedAt = updatedAt
//    self.isEmailVerified = isEmailVerified
//    self.isPhoneVerified = isPhoneVerified
//    self.status = status
//  }
//}
//
//// MARK: - User Status
//
///// 사용자 상태
//public enum UserStatus: String, CaseIterable, Codable, Sendable {
//  case active = "active"
//  case inactive = "inactive"
//  case suspended = "suspended"
//  case deleted = "deleted"
//  
//  public var displayName: String {
//    switch self {
//    case .active: return "활성"
//    case .inactive: return "비활성"
//    case .suspended: return "정지"
//    case .deleted: return "삭제됨"
//    }
//  }
//  
//  public var isActive: Bool {
//    self == .active
//  }
//}
//
//// MARK: - User Profile
//
///// 사용자 프로필 정보 (확장된 정보)
//public struct UserProfile: Equatable, Codable, Identifiable, Sendable {
//  public let id: UUID
//  public let userId: UUID
//  public let bio: String?
//  public let birthDate: Date?
//  public let location: String?
//  public let website: String?
//  public let preferences: UserPreferences
//  public let statistics: UserStatistics
//  
//  public init(
//    id: UUID = UUID(),
//    userId: UUID,
//    bio: String? = nil,
//    birthDate: Date? = nil,
//    location: String? = nil,
//    website: String? = nil,
//    preferences: UserPreferences = UserPreferences(),
//    statistics: UserStatistics = UserStatistics()
//  ) {
//    self.id = id
//    self.userId = userId
//    self.bio = bio
//    self.birthDate = birthDate
//    self.location = location
//    self.website = website
//    self.preferences = preferences
//    self.statistics = statistics
//  }
//}
//
//// MARK: - User Preferences
//
///// 사용자 설정
//public struct UserPreferences: Equatable, Codable, Sendable {
//  public let notificationsEnabled: Bool
//  public let pushNotificationsEnabled: Bool
//  public let emailNotificationsEnabled: Bool
//  public let language: String
//  public let timezone: String
//  public let theme: AppTheme
//  
//  public init(
//    notificationsEnabled: Bool = true,
//    pushNotificationsEnabled: Bool = true,
//    emailNotificationsEnabled: Bool = true,
//    language: String = "ko",
//    timezone: String = "Asia/Seoul",
//    theme: AppTheme = .system
//  ) {
//    self.notificationsEnabled = notificationsEnabled
//    self.pushNotificationsEnabled = pushNotificationsEnabled
//    self.emailNotificationsEnabled = emailNotificationsEnabled
//    self.language = language
//    self.timezone = timezone
//    self.theme = theme
//  }
//}
//
//// MARK: - User Statistics
//
///// 사용자 통계
//public struct UserStatistics: Equatable, Codable, Sendable {
//  public let totalPromises: Int
//  public let completedPromises: Int
//  public let cancelledPromises: Int
//  public let successRate: Double
//  public let totalGroups: Int
//  public let activeGroups: Int
//  public let joinDate: Date
//  
//  public init(
//    totalPromises: Int = 0,
//    completedPromises: Int = 0,
//    cancelledPromises: Int = 0,
//    successRate: Double = 0.0,
//    totalGroups: Int = 0,
//    activeGroups: Int = 0,
//    joinDate: Date = Date()
//  ) {
//    self.totalPromises = totalPromises
//    self.completedPromises = completedPromises
//    self.cancelledPromises = cancelledPromises
//    self.successRate = successRate
//    self.totalGroups = totalGroups
//    self.activeGroups = activeGroups
//    self.joinDate = joinDate
//  }
//}
//
//// MARK: - App Theme
//
///// 앱 테마
//public enum AppTheme: String, CaseIterable, Codable, Sendable {
//  case light = "light"
//  case dark = "dark"
//  case system = "system"
//  
//  public var displayName: String {
//    switch self {
//    case .light: return "라이트 모드"
//    case .dark: return "다크 모드"
//    case .system: return "시스템 설정"
//    }
//  }
//}
//
//// MARK: - User Extensions
//
//public extension User {
//  /// 사용자의 표시 이름 (이메일 또는 이름)
//  var displayName: String {
//    name.isEmpty ? email : name
//  }
//  
//  /// 사용자의 이니셜
//  var initials: String {
//    let components = name.components(separatedBy: .whitespacesAndNewlines)
//    let initials = components.compactMap { $0.first }.map(String.init)
//    return initials.prefix(2).joined()
//  }
//  
//  /// 검증된 사용자인지 확인
//  var isVerified: Bool {
//    isEmailVerified || isPhoneVerified
//  }
//  
//  /// 완전히 검증된 사용자인지 확인
//  var isFullyVerified: Bool {
//    isEmailVerified && isPhoneVerified
//  }
//}
//
//public extension UserProfile {
//  /// 나이 계산
//  var age: Int? {
//    guard let birthDate = birthDate else { return nil }
//    let calendar = Calendar.current
//    let now = Date()
//    let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
//    return ageComponents.year
//  }
//}
//
//public extension UserStatistics {
//  /// 성공률을 백분율로 표시
//  var successRatePercentage: String {
//    String(format: "%.1f%%", successRate * 100)
//  }
//  
//  /// 실패한 약속 수
//  var failedPromises: Int {
//    totalPromises - completedPromises - cancelledPromises
//  }
//  
//  /// 실패율
//  var failureRate: Double {
//    guard totalPromises > 0 else { return 0.0 }
//    return Double(failedPromises) / Double(totalPromises)
//  }
//}
