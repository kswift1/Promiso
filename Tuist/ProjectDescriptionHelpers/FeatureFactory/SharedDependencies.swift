import ProjectDescription

/// Shared, Core, Domain 모듈에 대한 의존성을 관리하는 헬퍼
public enum SharedDependencies {
  
  // MARK: - Core Dependencies
  
  /// Core 모듈들에 대한 의존성
  public static let core: [TargetDependency] = [
    .project(target: "CoreNetworking", path: "../../Core"),
    .project(target: "CoreInfrastructure", path: "../../Core")
  ]
  
  /// 기본적인 Core 의존성 (Interface 레이어용)
  public static let coreBasic: [TargetDependency] = [
    .project(target: "CoreInfrastructure", path: "../../Core")
  ]
  
  // MARK: - Domain Dependencies
  
  /// Domain 모듈에 대한 의존성
  public static let domain: [TargetDependency] = [
    .project(target: "Domain", path: "../../Domain")
  ]
  
  // MARK: - Shared Dependencies
  
  /// Shared 모듈들에 대한 의존성
  public static let shared: [TargetDependency] = [
    .project(target: "SharedServices", path: "../../Shared"),
    .project(target: "SharedDesignSystem", path: "../../Shared"),
    .project(target: "SharedExtensions", path: "../../Shared"),
    .project(target: "SharedConstants", path: "../../Shared"),
    .project(target: "SharedResources", path: "../../Shared")
  ]
  
  /// 기본적인 Shared 의존성 (Interface 레이어용)
  public static let sharedBasic: [TargetDependency] = [
    .project(target: "SharedConstants", path: "../../Shared")
  ]
  
  // MARK: - Combined Dependencies
  
  /// Interface 레이어에서 사용할 기본 의존성들
  public static let interface: [TargetDependency] = domain + coreBasic + sharedBasic
  
  /// Implement 레이어에서 사용할 전체 의존성들
  public static let implement: [TargetDependency] = domain + core + shared
  
  /// Testing 레이어에서 사용할 의존성들
  public static let testing: [TargetDependency] = [
    .project(target: "Domain", path: "../../Domain"),
    .project(target: "CoreInfrastructure", path: "../../Core")
  ]
  
  // MARK: - Feature-specific Dependencies
  
  /// Home Feature에서 필요한 추가 의존성들
  public static let homeSpecific: [TargetDependency] = []
  
  /// Promise Feature에서 필요한 추가 의존성들
  public static let promiseSpecific: [TargetDependency] = []
  
  /// Group Feature에서 필요한 추가 의존성들
  public static let groupSpecific: [TargetDependency] = []
  
  /// Calendar Feature에서 필요한 추가 의존성들
  public static let calendarSpecific: [TargetDependency] = []
  
  /// RootTab Feature에서 필요한 추가 의존성들 (다른 Features의 Interface만)
  public static let rootTabSpecific: [TargetDependency] = []
}