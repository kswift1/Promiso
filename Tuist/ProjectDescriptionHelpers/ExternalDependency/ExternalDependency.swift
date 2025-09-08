import ProjectDescription

/// 외부 라이브러리 의존성 상수
public enum ExternalDependency {
  /// The Composable Architecture
  public static let tca: TargetDependency = .external(name: "ComposableArchitecture")
  
  // 추가 외부 라이브러리들을 여기에 정의
  // 예시:
  // public static let alamofire: TargetDependency = .external(name: "Alamofire")
  // public static let kingfisher: TargetDependency = .external(name: "Kingfisher")
}
