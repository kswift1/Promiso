import ProjectDescription

/// Shared, Core, Domain 모듈에 대한 의존성을 관리하는 헬퍼
public enum SharedDependencies {
  
  // MARK: - Core Dependencies
  
  public static let core: [TargetDependency] = coreInfrastructure + coreNetworking
  
  /// 기본적인 CoreInfrastructure 의존성
  public static let coreInfrastructure: [TargetDependency] = [
    .project(target: "CoreInfrastructure", path: "../../Core")
  ]
  
  /// 기본적인 CoreInfrastructure 의존성
  public static let coreNetworking: [TargetDependency] = [
    .project(target: "CoreNetworking", path: "../../Core")
  ]
  
  // MARK: - Domain Dependencies
  
  /// Domain 모듈에 대한 의존성
  public static let domain: [TargetDependency] = [
    .project(target: "Domain", path: "../../Domain")
  ]
  
  // MARK: - Shared Dependencies
  
  /// Shared 모듈들에 대한 의존성
  public static let shared: [TargetDependency] = [
    .project(target: "Shared", path: "../../Shared"),
    .project(target: "ResourceKit", path: "../../ResourceKit"),
  ]
  
  // MARK: - External Dependencies
  
  public static let externalDeps: [TargetDependency] = [.project(target: "ExternalDependency", path: "../../ExternalDependency"),]
  
  // MARK: - Combined Dependencies
  
  public static let featureDefaultDeps: [TargetDependency] = domain + shared + externalDeps
}
