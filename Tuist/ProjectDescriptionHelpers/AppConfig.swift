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
  public static let marketingNumber: String = "1.3.1"
  
  public static func buildVersion(for environment: String = "dev") -> String {
    let now = Date()
    let dataFormatter = DateFormatter()
    dataFormatter.dateFormat = "YYMMddHHmm"
    let timestamp = dataFormatter.string(from: now)

    // 환경별 끝자리 구분
    // dev/stage: 001, prod: 009
    let suffix = environment == "prod" ? "009" : "001"
    return "\(timestamp)\(suffix)"
  }
  
  public static func infoPlist(for environment: String = "prod") -> [String: Plist.Value] {
    // API Keys는 xcconfig 파일에서 환경별로 관리 (Config/*.xcconfig, gitignored)
    // Deeplink는 비밀값이 아니므로 환경별 직접 설정
    let deeplinkScheme: String
    let deeplinkWebHost: String
    switch environment {
    case "dev":
      deeplinkScheme = "promiso-dev"
      deeplinkWebHost = "dev.promiso.app"
    case "stage":
      deeplinkScheme = "promiso-stage"
      deeplinkWebHost = "stage.promiso.app"
    default:
      deeplinkScheme = "promiso"
      deeplinkWebHost = "promiso.app"
    }

    return [
      "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
      "CFBundleVersion": .string(AppConfig.buildVersion(for: environment)),
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
          "CFBundleURLSchemes": [.string(deeplinkScheme)]
        ],
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLName": "com.promiso.kakaolink",
          "CFBundleURLSchemes": [.string("kakao$(KAKAO_NATIVE_APP_KEY)")]
        ]
      ],
      "LSApplicationQueriesSchemes": .array([
        .string("kakaolink"),
        .string("kakaokompassauth"),
        .string("kakaomap"),
        .string("nmap")
      ]),
      "GIDClientID": .string("$(GOOGLE_CLIENT_ID)"),
      // Location permissions
      "NSLocationWhenInUseUsageDescription": .string("현재 위치의 날씨 정보를 제공하기 위해 위치 접근 권한이 필요합니다."),
      // Calendar permissions
      "NSCalendarsUsageDescription": .string("캘린더 일정을 표시하려면 접근 권한이 필요합니다."),
      "NSCalendarsFullAccessUsageDescription": .string("캘린더 일정을 표시하려면 접근 권한이 필요합니다."),
      // Background Modes for Silent Push Notifications
      "UIBackgroundModes": .array([
        .string("remote-notification")
      ]),
      // Firebase Swizzling 비활성화 (Silent Push 직접 처리)
      "FirebaseAppDelegateProxyEnabled": .boolean(false),
      // Live Activity Support
      "NSSupportsLiveActivities": .boolean(true),
      "NSSupportsLiveActivitiesFrequentUpdates": .boolean(true),
      // Deeplink
      "DEEPLINK_SCHEME": .string(deeplinkScheme),
      "DEEPLINK_WEB_HOST": .string(deeplinkWebHost),
      // Kakao SDK
      "KAKAO_NATIVE_APP_KEY": .string("$(KAKAO_NATIVE_APP_KEY)"),
      // Microsoft Clarity
      "CLARITY_PROJECT_ID": .string("$(CLARITY_PROJECT_ID)"),
      // 공공데이터포털 (한국천문연구원 특일 정보 API)
      "DATA_GO_KR_SERVICE_KEY": .string("$(DATA_GO_KR_SERVICE_KEY)"),
      // ProMotion Display Support (120Hz)
      "CADisableMinimumFrameDurationOnPhone": .boolean(true),
      // App Store 제출: 암호화 사용 여부 (표준 암호화만 사용)
      "ITSAppUsesNonExemptEncryption": .boolean(false),
      // 세로 모드만 지원 (가로 모드 비활성화)
      "UISupportedInterfaceOrientations": .array([
        .string("UIInterfaceOrientationPortrait")
      ]),
      "CFBundleLocalizations": .array([
        .string("ko"),
        .string("en")
      ]),
      "CFBundleDevelopmentRegion": .string("ko"),
    ]
  }
}

public enum Paths {
  // App 타깃 기본 경로(원하는 대로 바꿔도 됨)
  public static let sources    = "Promiso/Sources"
  public static let resources  = "Promiso/Resources"
  public static let tests      = "Promiso/Tests"
}
