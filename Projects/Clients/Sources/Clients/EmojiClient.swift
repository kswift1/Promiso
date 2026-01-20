import ComposableArchitecture
import FirebaseFunctions
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
      return "로그인이 필요합니다"
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .invalidResponse:
      return "응답을 처리할 수 없습니다"
    case .serverError(let message):
      return "서버 오류: \(message)"
    }
  }
}

// MARK: - Client

/// TCA용 이모지 생성 클라이언트
@DependencyClient
public struct EmojiClient: Sendable {
  /// 제목에 어울리는 이모지 생성 (Firebase Functions 사용)
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
    let functions = Functions.functions(region: "asia-northeast3")

    return Self(
      generate: { title in
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.emoji.debug("🎯 [EmojiClient] 이모지 생성 시작 - 제목: \(title)")

        do {
          // Firebase Functions 호출
          let result = try await functions.httpsCallable("generateEmoji").call(["title": title])

          guard let data = result.data as? [String: Any],
                let emoji = data["emoji"] as? String
          else {
            AppLogger.emoji.error("❌ [EmojiClient] 응답 파싱 실패")
            throw EmojiClientError.invalidResponse
          }

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.emoji.info("🎉 [EmojiClient] 이모지 생성 완료 - 결과: \(emoji), 총 소요시간: \(String(format: "%.2f", totalTime))초")

          return emoji
        } catch let error as NSError {
          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.emoji.error("❌ [EmojiClient] Firebase Functions 에러: \(error.localizedDescription), 소요시간: \(String(format: "%.2f", totalTime))초")

          // Firebase Functions 에러 코드 처리
          if error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            switch code {
            case .unauthenticated:
              throw EmojiClientError.notAuthenticated
            case .invalidArgument:
              throw EmojiClientError.invalidResponse
            default:
              throw EmojiClientError.serverError(error.localizedDescription)
            }
          }

          throw EmojiClientError.networkError
        }
      }
    )
  }()
}
