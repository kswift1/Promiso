import Foundation

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
    // 1. Info.plist에서 로드
    if let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
       !key.isEmpty, key != "$(GEMINI_API_KEY)" {
      apiKey = key
      return
    }

    // 2. DEBUG: 환경변수에서 로드
    #if DEBUG
      if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
         !envKey.isEmpty {
        apiKey = envKey
      }
    #endif
  }

  /// API Key 직접 설정 (테스트용)
  public static func configure(apiKey: String) {
    self.apiKey = apiKey
  }

  /// API Key 초기화
  public static func reset() {
    apiKey = nil
  }
}
