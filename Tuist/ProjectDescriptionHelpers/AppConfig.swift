import ProjectDescription
import Foundation

public enum AppConfig {
  public static let name = "Promiso"
  public static let bundlePrefix = "com.promiso"
  public static let bundleId = bundlePrefix
  public static let testsBundleId = "\(bundlePrefix).Tests"

  // 모듈별 Bundle ID 생성 헬퍼
  public static func moduleBundleId(_ module: String) -> String {
    return "\(bundlePrefix).\(module.lowercased())"
  }

  public static let deploymentTargets = "18.0"
  public static let defaultRegions = ["en", "ko"]
  
  public static let teamId = "BAC795627G"
  public static let marketingNumber: String = "1.0.0"
  
  public static let buildVersion: String = {
    let now = Date()
    let dataFormatter = DateFormatter()
    dataFormatter.dateFormat = "YYMMddHHmm"
    
    return "\(dataFormatter.string(from: now))001"
  }()
  
  public static var infoPlist: [String: Plist.Value] {
    // API Keys는 xcconfig 파일에서 환경별로 관리 (Config/*.xcconfig, gitignored)
    return [
      "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
      "CFBundleVersion": .string(AppConfig.buildVersion),
      "UILaunchScreen": .dictionary([
        "UIImageName": .string("LaunchImage"),
        "UIColorName": .string("LaunchBackgroundColor"),
        "UIImageRespectsSafeAreaInsets": true
      ]),
      "UIDesignRequiresCompatibility": .boolean(false),
      "CFBundleURLTypes": [
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLSchemes": [.string("$(GOOGLE_REVERSED_CLIENT_ID)")]
        ],
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLName": "com.promiso.deeplink",
          "CFBundleURLSchemes": [.string("promiso")]
        ]
      ],
      "GIDClientID": .string("$(GOOGLE_CLIENT_ID)"),
      // Calendar permissions
      "NSCalendarsUsageDescription": .string("캘린더 일정을 표시하려면 접근 권한이 필요합니다."),
      "NSCalendarsFullAccessUsageDescription": .string("캘린더 일정을 표시하려면 접근 권한이 필요합니다."),
      // Background Modes for Push Notifications
      "UIBackgroundModes": .array([
        .string("fetch"),
        .string("remote-notification")
      ]),
      // Firebase Swizzling 비활성화 (Silent Push 직접 처리)
      "FirebaseAppDelegateProxyEnabled": .boolean(false),
      // Live Activity Support
      "NSSupportsLiveActivities": .boolean(true),
      "NSSupportsLiveActivitiesFrequentUpdates": .boolean(true),
      // Kakao Maps SDK
      "KAKAO_NATIVE_APP_KEY": .string("$(KAKAO_NATIVE_APP_KEY)"),
      "KAKAO_REST_API_KEY": .string("$(KAKAO_REST_API_KEY)"),
      // ProMotion Display Support (120Hz)
      "CADisableMinimumFrameDurationOnPhone": .boolean(true),
      // App Store 제출: 암호화 사용 여부 (표준 암호화만 사용)
      "ITSAppUsesNonExemptEncryption": .boolean(false)
    ]
  }
}

public enum Paths {
  // App 타깃 기본 경로(원하는 대로 바꿔도 됨)
  public static let sources    = "Promiso/Sources"
  public static let resources  = "Promiso/Resources"
  public static let tests      = "Promiso/Tests"
}
