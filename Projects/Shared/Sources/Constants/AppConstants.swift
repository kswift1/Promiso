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
    privacyPolicyURL: "https://www.notion.so/3029e497067580beb0aaf485a0dd4a02",
    termsOfServiceURL: "https://www.notion.so/3029e4970675802ab781e282bb92d63b",
    supportEmail: "kswen0203@icloud.com",
    notionFAQDatabaseId: "3029e4970675812ca3d6c852867858a2"
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

  // MARK: - Deeplink

  /// 딥링크 설정 (환경별 xcconfig에서 주입)
  public enum Deeplink {
    /// URL 스킴 (dev: promiso-dev, stage: promiso-stage, prod: promiso)
    public static var scheme: String {
      Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String ?? "promiso"
    }

    /// 웹 호스트 (dev: dev.promiso.app, stage: stage.promiso.app, prod: promiso.app)
    public static var webHost: String {
      Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_WEB_HOST") as? String ?? "promiso.app"
    }

    /// 딥링크 URL 생성 (예: promiso-dev://join/ABC123)
    public static func url(path: String) -> URL? {
      URL(string: "\(scheme)://\(path)")
    }
  }

  // MARK: - App Group

  /// App Group 공유 데이터 (Extension ↔ 메인 앱)
  public enum AppGroup {
    /// App Group suite name (환경별 자동 판별)
    public static var suiteName: String {
      let bundleId = Bundle.main.bundleIdentifier ?? ""
      if bundleId.contains(".dev") {
        return "group.com.promiso.dev.shared"
      } else if bundleId.contains(".stage") {
        return "group.com.promiso.stage.shared"
      } else {
        return "group.com.promiso.shared"
      }
    }

    public static let pendingExtractionTextKey = "pendingExtractionText"

    /// pending 텍스트가 있는지 확인 (삭제하지 않음)
    public static var hasPendingExtractionText: Bool {
      Foundation.UserDefaults(suiteName: suiteName)?.string(forKey: pendingExtractionTextKey) != nil
    }

    /// pending 텍스트를 읽고 즉시 삭제 (consume)
    public static func consumePendingExtractionText() -> String? {
      let defaults = Foundation.UserDefaults(suiteName: suiteName)
      let text = defaults?.string(forKey: pendingExtractionTextKey)
      if text != nil {
        defaults?.removeObject(forKey: pendingExtractionTextKey)
      }
      return text
    }
  }

  // MARK: - External URLs

  public enum ExternalURLs {
    public static let kakaoMapSearchBase = "https://map.kakao.com/?q="
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
      case .system: return LocalizedStrings.ThemeMode.system
      case .light: return LocalizedStrings.ThemeMode.light
      case .dark: return LocalizedStrings.ThemeMode.dark
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
    /// 캘린더 동기화 idempotency를 위한 해시 캐시
    public static let calendarSyncWriteFingerprints = "promisoCalendarSyncWriteFingerprints"
    /// 캘린더 이벤트 매핑 (scheduleId → eventIdentifier)
    public static let calendarEventMappings = "promisoCalendarEventMappings"
    /// 마지막 캘린더 동기화 날짜
    public static let lastCalendarSyncDate = "promisoLastCalendarSyncDate"
    /// 일정 탭 기본 모드 (group/own)
    public static let defaultScheduleTabMode = "promisoDefaultScheduleTabMode"
    /// 선호하는 앱 언어 (ko/en, nil이면 시스템 기본)
    public static let preferredLanguage = "promisoPreferredLanguage"
    /// 개인 일정 캘린더 동기화 활성화 여부
    public static let personalCalendarSync = "promisoPersonalCalendarSync"
    /// 앱 소개 온보딩 완료 여부
    public static let hasCompletedOnboarding = "promisoHasCompletedOnboarding"
    /// 캘린더 시작 요일 (true: 월요일, false: 일요일, 기본값: true)
    public static let calendarStartOnMonday = "promisoCalendarStartOnMonday"
    /// 캘린더 권한 배너 다시 보지 않기
    public static let dismissedCalendarBannerTypes = "promisoDismissedCalendarBannerTypes"
    /// 브리핑 스타일 (friendly/humorous/concise/motivational/calm)
    public static let briefingStyle = "promisoBriefingStyle"
    /// 캘린더 기본 표시 모드 (week/month/monthExpanded)
    public static let defaultCalendarDisplayMode = "promisoDefaultCalendarDisplayMode"

    // MARK: - Guide

    /// 캘린더 기능 가이드 본 적 있는지
    public static let hasSeenCalendarGuide = "promisoHasSeenCalendarGuide"
    /// 홈 기능 가이드 본 적 있는지
    public static let hasSeenHomeGuide = "promisoHasSeenHomeGuide"
    /// 일정 기능 가이드 본 적 있는지
    public static let hasSeenScheduleGuide = "promisoHasSeenScheduleGuide"
    /// 설정 기능 가이드 본 적 있는지
    public static let hasSeenSettingsGuide = "promisoHasSeenSettingsGuide"
  }

  // MARK: - Calendar Helpers

  /// 캘린더 시작 요일이 월요일인지 (기본값: true)
  public static var isCalendarStartOnMonday: Bool {
    let ud = Foundation.UserDefaults.standard
    if ud.object(forKey: AppConstants.UserDefaults.calendarStartOnMonday) == nil {
      return true  // 기본값: 월요일 시작
    }
    return ud.bool(forKey: AppConstants.UserDefaults.calendarStartOnMonday)
  }

  // MARK: - Shared State Keys (TCA @Shared inMemory)

  public enum SharedState {
    /// 그룹 멤버 캐시 (groupId → members)
    public static let groupMembersCache = "groupMembersCache"
    /// 그룹 캘린더 동기화 설정 캐시 (groupId → calendarSync)
    public static let groupCalendarSyncCache = "groupCalendarSyncCache"
    /// Pro 구독 상태
    public static let isPro = "isPro"
  }

  // MARK: - Notification Names

  public enum Notifications {
    /// FCM 토큰 수신 시 발송 (userInfo: ["token": String])
    public static let fcmTokenDidReceive = NSNotification.Name("FCMTokenDidReceive")
    /// 푸시 알림 탭 시 발송 (userInfo: ["type": String, "scheduleId": String?, "groupId": String?])
    public static let pushNotificationTapped = NSNotification.Name("PushNotificationTapped")
  }

  // MARK: - Image Cache

  public enum ImageCache {
    /// 디스크 캐시 이름
    public static let diskCacheName = "com.promiso.imageCache"
    /// 디스크 캐시 최대 크기 (150MB)
    public static let diskCacheSizeLimit: Int = 150 * 1024 * 1024
    /// 메모리 캐시 최대 크기 (100MB)
    public static let memoryCacheCostLimit: Int = 100 * 1024 * 1024
    /// 메모리 캐시 최대 이미지 수
    public static let memoryCacheCountLimit: Int = 200
    /// Firebase URL 캐시 최대 엔트리 수
    public static let urlCacheMaxEntries: Int = 500
  }

  // MARK: - Time Intervals

  public enum TimeIntervals {
    /// 이미지 캐시 만료 시간 (24시간)
    public static let cacheExpiry: TimeInterval = 24 * 60 * 60
  }
}
