import ProjectDescription

/// 외부 라이브러리 의존성 상수
public enum ExternalDeps: CaseIterable {
  /// The Composable Architecture
  case tca

  /// Firebase
  case firebaseSDK
  case googleSDK
  
  /// SwiftUI Debugging Tool
  case loupe

  public static func allExternalDeps() -> [TargetDependency] {
    ExternalDeps.allCases.flatMap { $0.targetDependency }
  }

  private var targetDependency: [TargetDependency] {
    switch self {
    case .tca:
      return [.external(name: "ComposableArchitecture")]
      
    case .firebaseSDK:
      return [
        "FirebaseCore",
        "FirebaseAuth",
        "FirebaseFirestore",
        "FirebaseCrashlytics"
      ].map { .external(name: $0) }
      
    case .googleSDK:
      return [.external(name: "GoogleSignInSwift")]
      
    case .loupe:
      return [.external(name: "RenderMeThis")]
    }
  }
}
