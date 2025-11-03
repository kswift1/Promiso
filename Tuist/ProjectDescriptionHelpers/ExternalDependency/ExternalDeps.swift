import ProjectDescription

/// 외부 라이브러리 의존성 상수
public enum ExternalDeps: CaseIterable {
  /// The Composable Architecture
  case tca

  /// Firebase
  case firebaseCore
  case firebaseAuth
  case firebaseFirestore
  case firebaseCrashlytics
  
  /// SwiftUI Debugging Tool
  case loupe

  public static func allExternalDeps() -> [TargetDependency] {
    ExternalDeps.allCases.map { $0.targetDependency }
  }

  private var targetDependency: TargetDependency {
    switch self {
    case .tca:
      return .external(name: "ComposableArchitecture")
    case .firebaseCore:
      return .external(name: "FirebaseCore")
    case .firebaseAuth:
      return .external(name: "FirebaseAuth")
    case .firebaseFirestore:
      return .external(name: "FirebaseFirestore")
    case .firebaseCrashlytics:
      return .external(name: "FirebaseCrashlytics")
    case .loupe:
      return .external(name: "RenderMeThis")
    }
  }
}
