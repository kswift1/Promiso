import Foundation
import PromisoShared

/// Gemini API 설정 관리
public enum GeminiConfiguration {
  /// API Key (nil이면 설정되지 않음)
  public private(set) static var apiKey: String?

  /// API가 설정되어 있는지 확인
  public static var isConfigured: Bool {
    guard let key = apiKey else { return false }
    return !key.isEmpty && key != "$(GEMINI_API_KEY)"
  }

  /// Gemini API Base URL
  public static let baseURL = "https://generativelanguage.googleapis.com/v1beta"

  /// 사용할 모델
  public static let model = "gemini-2.0-flash"

  /// 환경에서 API Key 로드
  public static func loadFromEnvironment() {
    AppLogger.emoji.debug("🔑 [GeminiConfig] API Key 로드 시작")

    // 1. Info.plist에서 로드
    if let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
       !key.isEmpty, key != "$(GEMINI_API_KEY)" {
      apiKey = key
      let maskedKey = String(key.prefix(10)) + "***"
      AppLogger.emoji.info("✅ [GeminiConfig] Info.plist에서 API Key 로드 완료: \(maskedKey)")
      return
    }
    AppLogger.emoji.debug("⚠️ [GeminiConfig] Info.plist에 API Key 없음")

    // 2. DEBUG: 환경변수에서 로드
    #if DEBUG
      if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
         !envKey.isEmpty {
        apiKey = envKey
        let maskedKey = String(envKey.prefix(10)) + "***"
        AppLogger.emoji.info("✅ [GeminiConfig] 환경변수에서 API Key 로드 완료: \(maskedKey)")
        return
      }
      AppLogger.emoji.debug("⚠️ [GeminiConfig] 환경변수에 API Key 없음")
    #endif

    AppLogger.emoji.warning("❌ [GeminiConfig] API Key를 찾을 수 없음 - Fallback 모드로 동작")
  }

  /// API Key 직접 설정 (테스트용)
  public static func configure(apiKey: String) {
    self.apiKey = apiKey
    AppLogger.emoji.debug("🔧 [GeminiConfig] API Key 직접 설정됨")
  }

  /// API Key 초기화
  public static func reset() {
    apiKey = nil
    AppLogger.emoji.debug("🔄 [GeminiConfig] API Key 초기화됨")
  }
}
