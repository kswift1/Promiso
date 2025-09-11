import ProjectDescription

public extension Settings {
  /// 팀 ID가 설정된 기본 설정
  static func withTeamId(
    base: [String: SettingValue] = [:],
    configurations: [Configuration] = [.debug(name: "Debug"), .release(name: "Release")]
  ) -> Settings {
    var baseSettings = base
    baseSettings["DEVELOPMENT_TEAM"] = .string(AppConfig.teamId)
    baseSettings["MARKETING_VERSION"] = .string(AppConfig.marketingNumber)
    
    return .settings(
      base: baseSettings,
      configurations: configurations
    )
  }
}

public extension SettingsDictionary {
  /// 팀 ID가 포함된 기본 설정 딕셔너리
  static var withTeamId: SettingsDictionary {
    return [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId)
    ]
  }
}
