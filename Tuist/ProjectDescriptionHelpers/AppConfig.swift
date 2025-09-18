import ProjectDescription

public enum AppConfig {
  public static let name = "Promiso"
  public static let bundlePrefix = "com.promiso"
  public static let bundleId = bundlePrefix
  public static let testsBundleId = "\(bundlePrefix).Tests"

  // 모듈별 Bundle ID 생성 헬퍼
  public static func moduleBundleId(_ module: String) -> String {
    return "\(bundlePrefix).\(module.lowercased())"
  }

  public static let deploymentTargets = "16.4"
  public static let defaultRegions = ["en", "ko"]
  
  public static let marketingNumber = "1.0.0"
  public static let teamId = "BAC795627G"
}

public enum Paths {
  // App 타깃 기본 경로(원하는 대로 바꿔도 됨)
  public static let sources    = "Promiso/Sources"
  public static let resources  = "Promiso/Resources"
  public static let tests      = "Promiso/Tests"
}
