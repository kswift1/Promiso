import ProjectDescription

public enum AppConfig {
  public static let name = "Promiso"
  public static let bundlePrefix = "com.kswift1"
  public static let bundleId = "\(bundlePrefix).\(name)"
  public static let testsBundleId = "\(bundlePrefix).\(name)Tests"

  public static let deploymentTargets = "16.4"
  public static let defaultRegions = ["en", "ko"]
}

public enum Paths {
  // App 타깃 기본 경로(원하는 대로 바꿔도 됨)
  public static let sources    = "Promiso/Sources"
  public static let resources  = "Promiso/Resources"
  public static let tests      = "Promiso/Tests"
}
