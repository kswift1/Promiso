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
  /// 1. App Store Receipt URL 확인 → "sandboxReceipt" 포함 시 Sandbox
  /// 2. DEBUG 빌드 → Sandbox
  /// 3. 그 외 → Production (TestFlight, App Store)
  public static var current: APNsEnvironment {
    // 1. Receipt URL로 판단 (가장 정확)
    if let receiptURL = Bundle.main.appStoreReceiptURL {
      // sandboxReceipt → Xcode 직접 빌드 또는 TestFlight (단, TestFlight는 Production APNs 사용)
      // receipt → App Store
      //
      // 하지만 TestFlight도 sandboxReceipt를 사용하므로,
      // embedded.mobileprovision 파일 존재 여부로 추가 판단
      if receiptURL.lastPathComponent == "sandboxReceipt" {
        // embedded.mobileprovision이 있으면 Xcode 직접 빌드 (Development)
        // 없으면 TestFlight (Production APNs)
        if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
          return .sandbox
        } else {
          // TestFlight는 Production APNs 사용
          return .production
        }
      }
      // App Store 빌드
      return .production
    }

    // 2. Receipt URL이 없는 경우 (시뮬레이터 등)
    #if DEBUG
    return .sandbox
    #else
    return .production
    #endif
  }

  /// 백엔드 API에 전달할 값
  public var apiValue: String { rawValue }
}
