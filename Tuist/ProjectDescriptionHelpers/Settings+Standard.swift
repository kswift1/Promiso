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
    // CODE_SIGN_STYLE은 xcconfig에서 설정 (Manual)
    baseSettings["OTHER_LDFLAGS"] = .string("-ObjC")
    baseSettings["MARKETING_VERSION"] = .string(AppConfig.marketingNumber)
    // CURRENT_PROJECT_VERSION은 각 타겟의 Info.plist에서 CFBundleVersion으로 환경별 설정됨

    return .settings(
      base: baseSettings,
      configurations: configurations,
      defaultSettings: defaultSettings
    )
  }
}
