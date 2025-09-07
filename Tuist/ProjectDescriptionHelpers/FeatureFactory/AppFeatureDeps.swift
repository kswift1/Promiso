import ProjectDescription

/// App 타겟의 피쳐 의존성을 관리하는 헬퍼
public enum AppFeatureDeps {
  
  /// 모든 피쳐의 의존성을 자동으로 수집하여 반환
  /// - Parameter dependencyPathFromThisProject: App/Project.swift 기준 상대 경로
  /// - Returns: 모든 피쳐의 Interface + Implement 의존성 배열
  public static func allFeaturesDeps(
    dependencyPathFromThisProject: String = "../Features"
  ) -> [TargetDependency] {
    let allFeatures: [Feature] = [
      // 🤖 Auto-generated features
      .rootTab,
      .schedule,
    ]
    return allFeatures
      .flatMap { feature($0, path: dependencyPathFromThisProject) }
  }
  
  /// 특정 피쳐의 Interface + Implement 의존성을 생성하는 슈가 함수
  /// - Parameters:
  ///   - feature: Feature 구조체 (예: .home, .calendar)
  ///   - path: 베이스 경로 (예: "../Features")
  /// - Returns: Interface + Implement 의존성 배열
  private static func feature(_ feature: Feature, path: String) -> [TargetDependency] {
    return [
      .project(target: "\(feature.rawValue)Interface", path: "\(path)/\(feature.rawValue)Feature"),
      .project(target: "\(feature.rawValue)Implement", path: "\(path)/\(feature.rawValue)Feature"),
    ]
  }
}
