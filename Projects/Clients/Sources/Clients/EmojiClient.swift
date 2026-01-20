import ComposableArchitecture
import Foundation

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
  public static let liveValue: EmojiClient = {
    return Self(
      generate: { title in
        // API Key 확인
        guard GeminiConfiguration.isConfigured,
              let apiKey = GeminiConfiguration.apiKey
        else {
          throw EmojiClientError.apiKeyNotConfigured
        }

        // URL 생성
        let urlString =
          "\(GeminiConfiguration.baseURL)/models/\(GeminiConfiguration.model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
          throw EmojiClientError.networkError
        }

        // 프롬프트 생성
        let prompt =
          "다음 약속 제목에 가장 어울리는 이모지 1개만 응답해. 이모지만 출력하고 다른 텍스트는 절대 포함하지 마.\n제목: \(title)"

        // Request 생성
        let request = GeminiRequest(prompt: prompt)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 10

        // API 호출
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // HTTP 상태 코드 확인
        guard let httpResponse = response as? HTTPURLResponse else {
          throw EmojiClientError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
          break
        case 429:
          throw EmojiClientError.rateLimitExceeded
        case 400...499:
          throw EmojiClientError.invalidResponse
        default:
          throw EmojiClientError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // 응답 파싱
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        // 에러 체크
        if let error = geminiResponse.error {
          throw EmojiClientError.serverError(error.message ?? "Unknown error")
        }

        // 텍스트에서 이모지 추출
        guard let text = geminiResponse.text else {
          throw EmojiClientError.invalidResponse
        }

        guard let emoji = EmojiExtractor.extractFirst(from: text) else {
          throw EmojiClientError.invalidResponse
        }

        return emoji
      }
    )
  }()
}
