import Foundation

// MARK: - App Config Manager (Actor)

/// Remote Config 값을 캐싱하는 Thread-safe Actor
actor AppConfigManager {
  static let shared = AppConfigManager()

  private var _config: AppConfigModel = .defaultConfig

  // nonisolated(unsafe): Actor 밖에서 동기 접근 가능
  // 쓰기는 Actor 내부에서만 수행하므로 안전함
  nonisolated(unsafe) private(set) var cachedConfig: AppConfigModel = .defaultConfig

  func updateConfig(_ config: AppConfigModel) async {
    _config = config
    cachedConfig = config
  }

  func getConfig() -> AppConfigModel {
    cachedConfig
  }
}

// MARK: - AppConfigModel (Public)

/// Remote Config에서 가져오는 앱 설정 (Actor에서 사용)
public struct AppConfigModel: Equatable, Sendable {
  public let forceUpdateVersion: String
  public let recommendedVersion: String
  public let appStoreURL: String
  public let privacyPolicyURL: String
  public let termsOfServiceURL: String
  public let supportEmail: String
  public let notionFAQDatabaseId: String

  public init(
    forceUpdateVersion: String,
    recommendedVersion: String,
    appStoreURL: String,
    privacyPolicyURL: String,
    termsOfServiceURL: String,
    supportEmail: String,
    notionFAQDatabaseId: String
  ) {
    self.forceUpdateVersion = forceUpdateVersion
    self.recommendedVersion = recommendedVersion
    self.appStoreURL = appStoreURL
    self.privacyPolicyURL = privacyPolicyURL
    self.termsOfServiceURL = termsOfServiceURL
    self.supportEmail = supportEmail
    self.notionFAQDatabaseId = notionFAQDatabaseId
  }

  public static let defaultConfig = AppConfigModel(
    forceUpdateVersion: "0.0.0",
    recommendedVersion: "0.0.0",
    appStoreURL: "https://apps.apple.com/app/id1625074042",
    privacyPolicyURL: "https://www.notion.so/2fb655a898de813882b5eebcf35ccb3d",
    termsOfServiceURL: "https://www.notion.so/2fb655a898de817f9f76fdce51f5a09f",
    supportEmail: "kswen0203@icloud.com",
    notionFAQDatabaseId: "356188caae734b5ebd73203557a34930"
  )
}

// MARK: - App Constants

/// 앱 전반에서 사용되는 상수들
public enum AppConstants {

  // MARK: - App Info

  /// 앱 기본 정보
  public enum App {
    // MARK: - Static Properties (변하지 않는 값)

    public static let name = "Promiso"
    public static let bundleId = "com.promiso.app"
    public static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - Remote Config 캐시 업데이트

    /// Remote Config 값 업데이트 (앱 시작 시 호출)
    public static func updateConfig(_ config: AppConfigModel) {
      Task {
        await AppConfigManager.shared.updateConfig(config)
      }
    }

    // MARK: - Dynamic Properties (Remote Config)

    /// 앱스토어 URL (동적 - Remote Config)
    public static var appStoreURL: URL {
      let config = AppConfigManager.shared.cachedConfig
      return URL(string: config.appStoreURL) ?? URL(string: AppConfigModel.defaultConfig.appStoreURL)!
    }

    /// 개인정보처리방침 URL (동적 - Remote Config)
    public static var privacyPolicyURL: URL {
      let config = AppConfigManager.shared.cachedConfig
      return URL(string: config.privacyPolicyURL) ?? URL(string: AppConfigModel.defaultConfig.privacyPolicyURL)!
    }

    /// 이용약관 URL (동적 - Remote Config)
    public static var termsOfServiceURL: URL {
      let config = AppConfigManager.shared.cachedConfig
      return URL(string: config.termsOfServiceURL) ?? URL(string: AppConfigModel.defaultConfig.termsOfServiceURL)!
    }

    /// 지원 이메일 (동적 - Remote Config)
    public static var supportEmail: String {
      AppConfigManager.shared.cachedConfig.supportEmail
    }

    /// Notion FAQ 데이터베이스 ID (동적 - Remote Config)
    public static var notionFAQDatabaseId: String {
      AppConfigManager.shared.cachedConfig.notionFAQDatabaseId
    }

    // MARK: - Testing

    #if DEBUG
    /// 테스트용: 캐시 초기화
    public static func resetConfigForTesting() {
      Task {
        await AppConfigManager.shared.updateConfig(.defaultConfig)
      }
    }
    #endif
  }

  // MARK: - UI Constants

  public enum UI {
    public static let safeMargin: CGFloat = 16

    // Tab Bar
    public static let tabBarHeight: CGFloat = 49
    public static let compactViewBottomSpacing: CGFloat = 8
    public static let compactViewCornerRadius: CGFloat = 15
    public static let compactViewPadding: CGFloat = 15
    public static let compactViewVerticalPadding: CGFloat = 8

    // Opacity
    public static let selectionOpacity: CGFloat = 0.3
  }

  // MARK: - Sync

  public enum Sync {
    /// 개인 일정 조회 최대 개수
    public static let personalEventFetchLimit = 100
  }

  // MARK: - LiveActivity

  public enum LiveActivity {
    /// 커스텀 분 입력 최대 자릿수
    public static let maxCustomMinutesDigits = 3
  }

  // MARK: - Theme Mode

  /// 앱 테마 모드 설정
  public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case system = "system"  // 시스템 설정 따르기 (기본)
    case light = "light"    // 항상 라이트 모드
    case dark = "dark"      // 항상 다크 모드

    public var displayName: String {
      switch self {
      case .system: return "시스템 설정 따르기"
      case .light: return "라이트 모드"
      case .dark: return "다크 모드"
      }
    }
  }

  // MARK: - User Defaults Keys

  public enum UserDefaults {
    /// 디바이스 고유 ID (FCM 토큰 관리용)
    public static let deviceId = "promisoDeviceId"
    /// 실시간 공유 정보 팝오버 본 적 있는지
    public static let hasSeenLiveActivityInfo = "promisoHasSeenLiveActivityInfo"
    /// 24시간 형식 사용 여부
    public static let use24HourFormat = "promisoUse24HourFormat"
    /// 선호하는 테마 모드 (system/light/dark)
    public static let preferredThemeMode = "promisoPreferredThemeMode"
    /// 캘린더 이벤트 매핑 (promiseId → eventIdentifier)
    public static let calendarEventMappings = "promisoCalendarEventMappings"
    /// 마지막 캘린더 동기화 날짜
    public static let lastCalendarSyncDate = "promisoLastCalendarSyncDate"
    /// 약속 탭 기본 모드 (group/own)
    public static let defaultPromiseTabMode = "promisoDefaultPromiseTabMode"
    /// 개인 일정 캘린더 동기화 활성화 여부
    public static let personalCalendarSync = "promisoPersonalCalendarSync"
  }

  // MARK: - Shared State Keys (TCA @Shared inMemory)

  public enum SharedState {
    /// 그룹 멤버 캐시 (groupId → members)
    public static let groupMembersCache = "groupMembersCache"
    /// 그룹 캘린더 동기화 설정 캐시 (groupId → calendarSync)
    public static let groupCalendarSyncCache = "groupCalendarSyncCache"
  }

  // MARK: - Notification Names

  public enum Notifications {
    /// FCM 토큰 수신 시 발송 (userInfo: ["token": String])
    public static let fcmTokenDidReceive = NSNotification.Name("FCMTokenDidReceive")
    /// 푸시 알림 탭 시 발송 (userInfo: ["type": String, "promiseId": String?, "groupId": String?])
    public static let pushNotificationTapped = NSNotification.Name("PushNotificationTapped")
    /// 앱 재시작 요청 (설정 변경 등으로 인해 앱 상태 리셋 필요 시)
    public static let appRestartRequested = NSNotification.Name("AppRestartRequested")
  }

  // MARK: - Time Intervals

  public enum TimeIntervals {
    /// 이미지 캐시 만료 시간 (24시간)
    public static let cacheExpiry: TimeInterval = 24 * 60 * 60
  }
}
