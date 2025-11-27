import ProjectDescription

/// 외부 라이브러리 의존성 상수
public enum ExternalDeps: CaseIterable {
  /// The Composable Architecture
  case tca

  /// Firebase
  case firebaseSDK
  
  /// SwiftUI Debugging Tool
  case loupe
  
  /// Kakao
  case KakaoSDK

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
      
    case .KakaoSDK:
      return [
        "KakaoSDKCommon",
        "KakaoSDKAuth",
        "KakaoSDKUser"
      ].map { .external(name: $0) }
      
    case .loupe:
      return [.external(name: "RenderMeThis")]
    }
  }
}
