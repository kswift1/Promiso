import ProjectDescription

/// App 타겟의 의존성을 관리하는 헬퍼
public enum AppFeatureDeps {

  // MARK: - Base Dependencies (공통 모듈)

  /// 모든 앱이 필요로 하는 기본 의존성
  public static let coreDeps: [TargetDependency] = [
    .project(target: "Clients", path: "../Clients"),
    .project(target: "PromisoShared", path: "../Shared"),
    .project(target: "ResourceKit", path: "../ResourceKit"),
    .project(target: "ExternalDependency", path: "../ExternalDependency")
  ]

  // MARK: - Feature Dependencies (자동 생성)

  /// 모든 피쳐 의존성을 자동으로 수집하여 반환
  /// - Returns: 모든 피쳐 타겟 의존성 배열
  public static let allFeaturesDeps: [TargetDependency] = {
    let allFeatures: [Feature] = [
      // 🤖 Auto-generated features
      .rootTab,
      .home,
      .group,
      .appEntry,
      .auth,
      .calendar,
      .settings,
    ]
    return allFeatures.map { feature($0) }
  }()

  // MARK: - All Dependencies

  /// Base + Feature 의존성을 모두 포함
  public static let allDeps: [TargetDependency] = coreDeps + allFeaturesDeps

  // MARK: - Private Helpers

  /// 특정 피쳐의 타겟 의존성 생성
  /// - Parameter feature: Feature 구조체 (예: .rootTab, .home)
  /// - Returns: 피쳐 타겟 의존성
  private static func feature(_ feature: Feature) -> TargetDependency {
    return .project(target: feature.fullName, path: "../Features/\(feature.fullName)")
  }
}
