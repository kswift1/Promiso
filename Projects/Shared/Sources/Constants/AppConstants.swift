import Foundation

// MARK: - App Constants

/// 앱 전반에서 사용되는 상수들
public enum AppConstants {

  // MARK: - App Info

  /// 앱 기본 정보
  public enum App {
    public static let name = "Promiso"
    public static let bundleId = "com.promiso.app"
    public static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    public static let appStoreURL = URL(string: "https://apps.apple.com/app/id1625074042")!
    public static let privacyPolicyURL = URL(string: "https://www.notion.so/2fb655a898de813882b5eebcf35ccb3d")!
    public static let termsOfServiceURL = URL(string: "https://www.notion.so/2fb655a898de817f9f76fdce51f5a09f")!
    public static let supportURL = URL(string: "https://promiso.com/support")!
    public static let supportEmail = "kswen0203@icloud.com"

    // MARK: - Notion FAQ
    /// Notion FAQ 데이터베이스 ID (공개 설정이므로 하드코딩 가능)
    /// Notion 페이지 URL에서 추출: https://notion.so/{database_id}?v=...
    public static let notionFAQDatabaseId = "356188caae734b5ebd73203557a34930"
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

  // MARK: - LiveActivity

  public enum LiveActivity {
    /// 커스텀 분 입력 최대 자릿수
    public static let maxCustomMinutesDigits = 3
  }

  // MARK: - User Defaults Keys

  public enum UserDefaults {
    /// 디바이스 고유 ID (FCM 토큰 관리용)
    public static let deviceId = "promisoDeviceId"
    /// 실시간 공유 정보 팝오버 본 적 있는지
    public static let hasSeenLiveActivityInfo = "promisoHasSeenLiveActivityInfo"
    /// 24시간 형식 사용 여부
    public static let use24HourFormat = "promisoUse24HourFormat"
    /// 캘린더 이벤트 매핑 (promiseId → eventIdentifier)
    public static let calendarEventMappings = "promisoCalendarEventMappings"
    /// 마지막 캘린더 동기화 날짜
    public static let lastCalendarSyncDate = "promisoLastCalendarSyncDate"
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
