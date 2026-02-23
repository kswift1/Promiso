import Foundation

/// APNs 환경 (Sandbox vs Production)
///
/// Firebase 환경(stage/prod)과 APNs 환경은 별개입니다:
/// - Xcode 직접 빌드: Sandbox
/// - TestFlight/App Store: Production
///
/// 앱에서 자동 감지하여 백엔드에 전달하면,
/// 백엔드가 올바른 APNs 서버로 Push를 전송합니다.
public enum APNsEnvironment: String, Codable, Sendable {
  case sandbox
  case production

  /// 현재 앱의 APNs 환경을 자동 감지
  ///
  /// 감지 로직:
  /// 1. embedded.mobileprovision 존재 시 Sandbox (개발/직접 배포)
  /// 2. 시뮬레이터 또는 DEBUG 빌드 → Sandbox
  /// 3. 그 외 → Production (TestFlight, App Store)
  public static var current: APNsEnvironment {
    if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
      return .sandbox
    }

    #if targetEnvironment(simulator)
    return .sandbox
    #elseif DEBUG
    return .sandbox
    #else
    return .production
    #endif
  }

  /// 백엔드 API에 전달할 값
  public var apiValue: String { rawValue }
}
