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

    // TODO: 앱스토어 출시 후 실제 URL로 교체 (설정 화면 > 앱 정보에서 사용)
    public static let appStoreURL = URL(string: "https://apps.apple.com/app/promiso/id123456789")!
    // TODO: 웹사이트 구축 후 실제 URL로 교체 (설정 화면 > 약관/정책에서 사용)
    public static let privacyPolicyURL = URL(string: "https://promiso.com/privacy")!
    public static let termsOfServiceURL = URL(string: "https://promiso.com/terms")!
    public static let supportURL = URL(string: "https://promiso.com/support")!
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
    public static let deviceId = "promiso.device.id"
    /// 실시간 공유 정보 팝오버 본 적 있는지
    public static let hasSeenLiveActivityInfo = "promiso.hasSeenLiveActivityInfo"
  }

  // MARK: - Notification Names

  public enum Notifications {
    /// FCM 토큰 수신 시 발송 (userInfo: ["token": String])
    public static let fcmTokenDidReceive = NSNotification.Name("FCMTokenDidReceive")
    /// 푸시 알림 탭 시 발송 (userInfo: ["type": String, "promiseId": String?, "groupId": String?])
    public static let pushNotificationTapped = NSNotification.Name("PushNotificationTapped")
  }

  // MARK: - Time Intervals

  public enum TimeIntervals {
    /// 이미지 캐시 만료 시간 (24시간)
    public static let cacheExpiry: TimeInterval = 24 * 60 * 60
  }
}
