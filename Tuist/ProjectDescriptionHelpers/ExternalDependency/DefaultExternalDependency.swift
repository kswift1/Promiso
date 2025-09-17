import ProjectDescription

/// Feature에서 기본적으로 사용하는 외부 의존성들
public enum DefaultExternalDependency {
  
  /// Interface 타겟에서 기본적으로 사용하는 외부 의존성
  public static let interface: [TargetDependency] = [
    ExternalDependency.tca
  ]
  
  /// Implement 타겟에서 기본적으로 사용하는 외부 의존성
  public static let implement: [TargetDependency] = [
    ExternalDependency.tca
  ]
  
  /// Testing 타겟에서 기본적으로 사용하는 외부 의존성
  public static let testing: [TargetDependency] = []
  
  /// Tests 타겟에서 기본적으로 사용하는 외부 의존성
  public static let tests: [TargetDependency] = [
    ExternalDependency.tca
  ]
  
  /// Example 타겟에서 기본적으로 사용하는 외부 의존성
  public static let example: [TargetDependency] = [
    ExternalDependency.tca
  ]
}

// MARK: - FirebaseDefaultExternalDependency
extension DefaultExternalDependency {

  // 모듈 나열형
  public static func firebase(_ modules: FirebaseModule...) -> [TargetDependency] {
    modules.map { $0.dep }
  }

  // 배열도 지원
  public static func firebase(_ modules: [FirebaseModule]) -> [TargetDependency] {
    modules.map { $0.dep }
  }
}
