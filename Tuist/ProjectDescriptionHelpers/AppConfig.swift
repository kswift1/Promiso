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

  public static let deploymentTargets = "17.0"
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
    // FIXME: API Key들 안보이게 옮기기
    let kakaoAPIKey: String = "85c9fc88501e426b848242e7c02d20af"
    let googleClientId: String = "1068229870528-4vquo3fuh2pnsvabfkk67okt49vpnv3o.apps.googleusercontent.com"
    let googleReversedClientId: String = "com.googleusercontent.apps.1068229870528-4vquo3fuh2pnsvabfkk67okt49vpnv3o"
    return [
      "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
      "CFBundleVersion": .string(AppConfig.buildVersion),
      "UILaunchStoryboardName": .string("LaunchScreen"),
      "UIDesignRequiresCompatibility": .boolean(false),
      "LSApplicationQueriesSchemes": [
        "kakaokompassauth",
        "kakaolink",
        "kakaoplus"
      ],
      "CFBundleURLTypes": [
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLSchemes": [.string("kakao" + "\(kakaoAPIKey)")]
        ],
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLSchemes": [.string(googleReversedClientId)]
        ]
      ],
      "KAKAO_API_KEY": .string(kakaoAPIKey),
      "GIDClientID": .string(googleClientId)
    ]
  }
}

public enum Paths {
  // App 타깃 기본 경로(원하는 대로 바꿔도 됨)
  public static let sources    = "Promiso/Sources"
  public static let resources  = "Promiso/Resources"
  public static let tests      = "Promiso/Tests"
}
