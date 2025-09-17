import ProjectDescription

public extension Settings {
  /// App 타깃용 기본 Settings (Team, 버전, 코드사인)
  static func withTeamId(
    base: [String: SettingValue] = [:],
    configurations: [Configuration] = [
      .debug(name: "Debug"),
      .release(name: "Release")
    ],
    defaultSettings: DefaultSettings = .recommended
  ) -> Settings {
    var baseSettings = base
    baseSettings["DEVELOPMENT_TEAM"] = .string(AppConfig.teamId)
    baseSettings["CODE_SIGN_STYLE"] = .string("Automatic")
    baseSettings["MARKETING_VERSION"] = .string(AppConfig.marketingNumber)
//    baseSettings["CURRENT_PROJECT_VERSION"] = .string(AppConfig.buildNumber)

    return .settings(
      base: baseSettings,
      configurations: configurations,
      defaultSettings: defaultSettings
    )
  }
}
