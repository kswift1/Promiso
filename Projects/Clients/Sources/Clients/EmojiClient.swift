import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Error

/// 이모지 생성 API 에러
public enum EmojiClientError: Error, Equatable {
  case notAuthenticated
  case networkError
  case invalidResponse
  case serverError(String)

  public var localizedDescription: String {
    switch self {
    case .notAuthenticated:
      return LocalizedStrings.Error.userAuthRequired
    case .networkError:
      return LocalizedStrings.Error.networkError
    case .invalidResponse:
      return LocalizedStrings.Error.invalidResponse
    case .serverError(let message):
      return LocalizedStrings.Error.serverErrorWithMessage(message)
    }
  }
}

// MARK: - Client

/// TCA용 이모지 생성 클라이언트
@DependencyClient
public struct EmojiClient: Sendable {
  /// 제목에 어울리는 이모지 생성
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
      let sanitizedTitle = EmojiClient.sanitizeTitle(title)

      // 간단한 키워드 매핑 목업
      let lowercased = sanitizedTitle.lowercased()
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

// MARK: - Input Sanitization

private extension EmojiClient {
  static let maxTitleLength = 30

  static func sanitizeTitle(_ title: String) -> String {
    let collapsedWhitespace = title.replacingOccurrences(
      of: #"\s+"#,
      with: " ",
      options: .regularExpression
    )
    return String(
      collapsedWhitespace
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .prefix(maxTitleLength)
    )
  }
}

// MARK: - Rust Response DTO

private struct RustEmojiResponse: Decodable {
  let emoji: String
}

// MARK: - Live Implementation

extension EmojiClient: DependencyKey {
  public static let liveValue: EmojiClient = {
    return Self(
      generate: { title in
        let sanitizedTitle = EmojiClient.sanitizeTitle(title)
        guard !sanitizedTitle.isEmpty else {
          throw EmojiClientError.invalidResponse
        }

        do {
          let rustClient = RustAPIClient()

          struct EmojiBody: Encodable { let title: String }
          let response: RustEmojiResponse = try await rustClient.post(
            "/api/v1/emoji/generate",
            body: EmojiBody(title: sanitizedTitle)
          )

          return response.emoji
        } catch let error as EmojiClientError {
          throw error
        } catch {
          throw EmojiClientError.networkError
        }
      }
    )
  }()
}
