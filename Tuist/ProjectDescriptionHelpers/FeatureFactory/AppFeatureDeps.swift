import ProjectDescription

/// App 타겟의 피쳐 의존성을 관리하는 헬퍼
public enum AppFeatureDeps {
  
  /// 모든 피쳐의 의존성을 자동으로 수집하여 반환
  /// - Returns: 모든 피쳐의 Interface + Implement 의존성 배열
  public static func allFeaturesDeps() -> [TargetDependency] {
    let allFeatures: [Feature] = [
      // 🤖 Auto-generated features
      .rootTab,
      .schedule,
      .home,
    ]
    return allFeatures
      .flatMap { feature($0) }
  }
  
  /// 특정 피쳐의 Interface + Implement 의존성을 생성하는 슈가 함수
  /// - Parameter feature: Feature 구조체 (예: .rootTab, .schedule)
  /// - Returns: Interface + Implement 의존성 배열
  private static func feature(_ feature: Feature) -> [TargetDependency] {
    return [
      .project(target: "\(feature.fullName)Interface", path: "../Features/\(feature.fullName)"),
      .project(target: "\(feature.fullName)Implement", path: "../Features/\(feature.fullName)"),
    ]
  }
}
