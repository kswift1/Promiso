import ProjectDescription

public extension Settings {
  /// 표준 프로젝트 설정 (Team ID, 버전, 코드사인, 빌드 최적화)
  static func standard(
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
    baseSettings["OTHER_LDFLAGS"] = .string("-ObjC")
    baseSettings["MARKETING_VERSION"] = .string(AppConfig.marketingNumber)
//    baseSettings["CURRENT_PROJECT_VERSION"] = .string(AppConfig.buildNumber)

    return .settings(
      base: baseSettings,
      configurations: configurations,
      defaultSettings: defaultSettings
    )
  }
}
