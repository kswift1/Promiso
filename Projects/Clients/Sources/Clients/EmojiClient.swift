import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Error

/// 이모지 생성 API 에러
public enum EmojiClientError: Error, Equatable {
  case apiKeyNotConfigured
  case networkError
  case invalidResponse
  case rateLimitExceeded
  case serverError(String)

  public var localizedDescription: String {
    switch self {
    case .apiKeyNotConfigured:
      return "API 키가 설정되지 않았습니다"
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .invalidResponse:
      return "응답을 처리할 수 없습니다"
    case .rateLimitExceeded:
      return "요청 한도를 초과했습니다"
    case .serverError(let message):
      return "서버 오류: \(message)"
    }
  }
}

// MARK: - Client

/// TCA용 이모지 생성 클라이언트
@DependencyClient
public struct EmojiClient: Sendable {
  /// 제목에 어울리는 이모지 생성 (Gemini API 사용)
  public var generate: @Sendable (_ title: String) async throws -> String
}

// MARK: - Test & Preview Values

extension EmojiClient: TestDependencyKey {
  public static let testValue = Self(
    generate: unimplemented("\(Self.self).generate", placeholder: "📅")
  )

  public static let previewValue = Self(
    generate: { title in
      try await Task.sleep(for: .milliseconds(500))

      // 간단한 키워드 매핑 목업
      let lowercased = title.lowercased()
      if lowercased.contains("점심") || lowercased.contains("저녁") || lowercased.contains("식사") || lowercased.contains("밥") {
        return "🍽️"
      } else if lowercased.contains("커피") || lowercased.contains("카페") {
        return "☕"
      } else if lowercased.contains("영화") || lowercased.contains("관람") {
        return "🎬"
      } else if lowercased.contains("운동") || lowercased.contains("헬스") || lowercased.contains("gym") {
        return "💪"
      } else if lowercased.contains("회의") || lowercased.contains("미팅") || lowercased.contains("meeting") {
        return "💼"
      } else if lowercased.contains("생일") || lowercased.contains("birthday") {
        return "🎂"
      } else if lowercased.contains("여행") || lowercased.contains("trip") {
        return "✈️"
      } else if lowercased.contains("등산") || lowercased.contains("산") {
        return "⛰️"
      } else if lowercased.contains("술") || lowercased.contains("맥주") || lowercased.contains("소주") {
        return "🍺"
      } else if lowercased.contains("게임") || lowercased.contains("game") {
        return "🎮"
      }
      return "📅"
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var emojiClient: EmojiClient {
    get { self[EmojiClient.self] }
    set { self[EmojiClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension EmojiClient: DependencyKey {
  // MARK: - Constants

  private static let emojiGenerationPrompt = """
    당신은 약속 제목을 보고 가장 적절한 이모지를 추천하는 전문가입니다.

    규칙:
    - 이모지 1개만 출력
    - 다른 텍스트 절대 금지
    - 제목의 의미와 맥락에 가장 부합하는 이모지 선택
    - 동시에 사람들이 자주 사용하는 대중적인 이모지 우선 (예: 식사🍽️, 커피☕, 운동💪, 회의💼, 술🍺, 영화🎬, 여행✈️, 생일🎂, 쇼핑🛍️, 공부📚, 게임🎮)

    제목: %@
    """

  // MARK: - Helper Functions

  private static func makeURLRequest(title: String, apiKey: String) throws -> URLRequest {
    let urlString =
      "\(GeminiConfiguration.baseURL)/models/\(GeminiConfiguration.model):generateContent?key=***"
    AppLogger.emoji.debug("🌐 [EmojiClient] API URL: \(urlString)")

    let fullUrlString =
      "\(GeminiConfiguration.baseURL)/models/\(GeminiConfiguration.model):generateContent?key=\(apiKey)"
    guard let url = URL(string: fullUrlString) else {
      AppLogger.emoji.error("❌ [EmojiClient] URL 생성 실패")
      throw EmojiClientError.networkError
    }

    let prompt = String(format: emojiGenerationPrompt, title)
    AppLogger.emoji.debug("📝 [EmojiClient] 프롬프트 생성 완료")

    let request = GeminiRequest(prompt: prompt)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    urlRequest.timeoutInterval = 10

    return urlRequest
  }

  private static func handleResponse(data: Data, response: URLResponse) throws -> String {
    guard let httpResponse = response as? HTTPURLResponse else {
      AppLogger.emoji.error("❌ [EmojiClient] HTTP 응답 파싱 실패")
      throw EmojiClientError.networkError
    }

    AppLogger.emoji.debug("📊 [EmojiClient] HTTP 상태 코드: \(httpResponse.statusCode)")

    switch httpResponse.statusCode {
    case 200:
      AppLogger.emoji.debug("✅ [EmojiClient] HTTP 200 OK")
    case 429:
      AppLogger.emoji.warning("⚠️ [EmojiClient] Rate Limit 초과 (429)")
      throw EmojiClientError.rateLimitExceeded
    case 400...499:
      AppLogger.emoji.error("❌ [EmojiClient] 클라이언트 에러: \(httpResponse.statusCode)")
      throw EmojiClientError.invalidResponse
    default:
      AppLogger.emoji.error("❌ [EmojiClient] 서버 에러: \(httpResponse.statusCode)")
      throw EmojiClientError.serverError("HTTP \(httpResponse.statusCode)")
    }

    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
    AppLogger.emoji.debug("📦 [EmojiClient] JSON 파싱 완료")

    if let error = geminiResponse.error {
      AppLogger.emoji.error("❌ [EmojiClient] Gemini API 에러: \(error.message ?? "Unknown")")
      throw EmojiClientError.serverError(error.message ?? "Unknown error")
    }

    guard let text = geminiResponse.text else {
      AppLogger.emoji.error("❌ [EmojiClient] 응답 텍스트 없음")
      throw EmojiClientError.invalidResponse
    }
    AppLogger.emoji.debug("📄 [EmojiClient] 응답 텍스트: \(text)")

    guard let emoji = EmojiExtractor.extractFirst(from: text) else {
      AppLogger.emoji.error("❌ [EmojiClient] 이모지 추출 실패 - 텍스트: \(text)")
      throw EmojiClientError.invalidResponse
    }

    return emoji
  }

  // MARK: - Live Value

  public static let liveValue: EmojiClient = {
    return Self(
      generate: { title in
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.emoji.debug("🎯 [EmojiClient] 이모지 생성 시작 - 제목: \(title)")

        // API Key 확인
        guard GeminiConfiguration.isConfigured,
              let apiKey = GeminiConfiguration.apiKey
        else {
          AppLogger.emoji.error("❌ [EmojiClient] API Key 미설정")
          throw EmojiClientError.apiKeyNotConfigured
        }
        AppLogger.emoji.debug("✅ [EmojiClient] API Key 확인 완료")

        // Request 생성
        let urlRequest = try makeURLRequest(title: title, apiKey: apiKey)
        AppLogger.emoji.debug("📤 [EmojiClient] API 요청 시작...")

        // API 호출
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        let requestTime = CFAbsoluteTimeGetCurrent() - startTime
        AppLogger.emoji.debug("📥 [EmojiClient] API 응답 수신 - 소요시간: \(String(format: "%.2f", requestTime))초")

        // 응답 처리 및 이모지 추출
        let emoji = try handleResponse(data: data, response: response)

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        AppLogger.emoji.info("🎉 [EmojiClient] 이모지 생성 완료 - 결과: \(emoji), 총 소요시간: \(String(format: "%.2f", totalTime))초")

        return emoji
      }
    )
  }()
}
