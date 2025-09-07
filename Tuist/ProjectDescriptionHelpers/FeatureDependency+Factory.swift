import ProjectDescription

/// Feature 의존성 축약 헬퍼
public enum FeatureDependency {
  // MARK: - 단일 Feature
  
  /// Interface + Implement 둘 다
  public static func all(_ feature: Feature, path: String = FeaturePath.root) -> [TargetDependency] {
    [
      interface(feature, path: path),
      implement(feature, path: path),
    ]
  }
  
  public static func interface(_ feature: Feature, path: String = FeaturePath.root) -> TargetDependency {
    .project(
      target: FeaturePath.interfaceName(feature),
      path: .path(FeaturePath.path(for: feature, root: path))
    )
  }
  
  public static func implement(_ feature: Feature, path: String = FeaturePath.root) -> TargetDependency {
    .project(
      target: FeaturePath.implementName(feature),
      path: .path(FeaturePath.path(for: feature, root: path))
    )
  }
  
  /// (선택) Testing 모듈
  public static func testing(_ feature: Feature, path: String = FeaturePath.root) -> TargetDependency {
    .project(
      target: FeaturePath.testingName(feature),
      path: .path(FeaturePath.path(for: feature, root: path))
    )
  }
  
  /// (선택) Tests 타깃
  public static func tests(_ feature: Feature, path: String = FeaturePath.root) -> TargetDependency {
    .project(
      target: FeaturePath.testsName(feature),
      path: .path(FeaturePath.path(for: feature, root: path))
    )
  }
  
  /// (선택) Example 앱
  public static func example(_ feature: Feature, path: String = FeaturePath.root) -> TargetDependency {
    .project(
      target: FeaturePath.exampleName(feature),
      path: .path(FeaturePath.path(for: feature, root: path))
    )
  }
  
  // MARK: - 여러 Feature 한 번에
  
  /// 여러 Feature를 한 번에 Interface+Implement로 전개
  public static func all(_ features: [Feature], path: String = FeaturePath.root) -> [TargetDependency] {
    features.flatMap { all($0, path: path) }
  }
  
  public static func interfaces(_ features: [Feature], path: String = FeaturePath.root) -> [TargetDependency] {
    features.map { interface($0, path: path) }
  }
  
  public static func implements(_ features: [Feature], path: String = FeaturePath.root) -> [TargetDependency] {
    features.map { implement($0, path: path) }
  }
}
