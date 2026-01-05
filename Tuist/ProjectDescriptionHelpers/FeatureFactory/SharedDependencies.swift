import ProjectDescription

/// Shared 모듈에 대한 의존성을 관리하는 헬퍼
public enum SharedDependencies {
  // MARK: - Shared Dependencies
  
  /// Shared 모듈들에 대한 의존성
  public static let shared: [TargetDependency] = [
    .project(target: "PromisoShared", path: "../../Shared"),
    .project(target: "ResourceKit", path: "../../ResourceKit"),
    .project(target: "ExternalDependency", path: "../../ExternalDependency")
  ]
  
  // MARK: - Combined Dependencies
  
  public static let featureDefaultDeps: [TargetDependency] = shared
}
