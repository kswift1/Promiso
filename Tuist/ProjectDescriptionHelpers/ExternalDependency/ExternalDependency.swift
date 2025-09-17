import ProjectDescription

/// 외부 라이브러리 의존성 상수
public enum ExternalDependency {
  /// The Composable Architecture
  public static let tca: TargetDependency = .external(name: "ComposableArchitecture")
  
  /// Dependencies
  public static let dependencies: TargetDependency = .external(name: "Dependencies")
  
  /// Firebase (필요한 모듈별 정의)
  public static let firebaseAuth: TargetDependency = .external(name: "FirebaseAuth")
  public static let firebaseFirestore: TargetDependency = .external(name: "FirebaseFirestore")
  public static let firebaseMessaging: TargetDependency = .external(name: "FirebaseMessaging")
  public static let firebaseCrashlytics: TargetDependency = .external(name: "FirebaseCrashlytics")
  public static let firebaseAnalytics: TargetDependency = .external(name: "FirebaseAnalytics")
  // 추가 외부 라이브러리들을 여기에 정의
  // 예시:
  // public static let alamofire: TargetDependency = .external(name: "Alamofire")
  // public static let kingfisher: TargetDependency = .external(name: "Kingfisher")
}

