import ProjectDescription

/// Feature 의존성 축약 헬퍼
public enum FeatureDependency {
  // MARK: - 단일 Feature
  
  /// Interface + Implement 둘 다
  public static func all(_ feature: Feature) -> [TargetDependency] {
    [
      interface(feature),
      implement(feature),
    ]
  }
  
  public static func interface(_ feature: Feature) -> TargetDependency {
    .project(
      target: "\(feature.fullName)Interface",
      path: "."
    )
  }
  
  public static func implement(_ feature: Feature) -> TargetDependency {
    .project(
      target: "\(feature.fullName)Implement", 
      path: "."
    )
  }
  
  /// (선택) Testing 모듈
  public static func testing(_ feature: Feature) -> TargetDependency {
    .project(
      target: "\(feature.fullName)Testing",
      path: "."
    )
  }
  
  /// (선택) Tests 타깃
  public static func tests(_ feature: Feature) -> TargetDependency {
    .project(
      target: "\(feature.fullName)Tests",
      path: "."
    )
  }
  
  /// (선택) Example 앱
  public static func example(_ feature: Feature) -> TargetDependency {
    .project(
      target: "\(feature.fullName)Example",
      path: "."
    )
  }
  
  // MARK: - 여러 Feature 한 번에
  
  /// 여러 Feature를 한 번에 Interface+Implement로 전개
  public static func all(_ features: [Feature]) -> [TargetDependency] {
    features.flatMap { all($0) }
  }
  
  public static func interfaces(_ features: [Feature]) -> [TargetDependency] {
    features.map { interface($0) }
  }
  
  public static func implements(_ features: [Feature]) -> [TargetDependency] {
    features.map { implement($0) }
  }
}
