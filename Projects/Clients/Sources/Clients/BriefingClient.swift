import ComposableArchitecture
import FirebaseFunctions
import Foundation
import PromisoShared

// MARK: - Error

/// 브리핑 생성 API 에러
public enum BriefingClientError: Error, Equatable {
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

// MARK: - Input

public struct BriefingInput: Equatable, Sendable {
  public let timezone: String
  public let language: String
  public let location: BriefingLocation?
  public let forceRefresh: Bool

  public struct BriefingLocation: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let title: String?

    public init(latitude: Double, longitude: Double, title: String?) {
      self.latitude = latitude
      self.longitude = longitude
      self.title = title
    }
  }

  public init(
    timezone: String,
    language: String,
    location: BriefingLocation?,
    forceRefresh: Bool = false
  ) {
    self.timezone = timezone
    self.language = language
    self.location = location
    self.forceRefresh = forceRefresh
  }
}

// MARK: - Result

public struct BriefingResult: Equatable, Sendable {
  public let summary: String
  public let detail: String

  public init(summary: String, detail: String) {
    self.summary = summary
    self.detail = detail
  }
}

// MARK: - Client

/// TCA용 브리핑 생성 클라이언트
@DependencyClient
public struct BriefingClient: Sendable {
  /// 오늘의 브리핑 생성 (Firebase Functions 사용)
  public var generate: @Sendable (_ input: BriefingInput) async throws -> BriefingResult
}

// MARK: - Test & Preview Values

extension BriefingClient: TestDependencyKey {
  public static let testValue = Self(
    generate: unimplemented("\(Self.self).generate", placeholder: BriefingResult(summary: "", detail: ""))
  )

  public static let previewValue = Self(
    generate: { _ in
      try await Task.sleep(for: .seconds(1))
      return BriefingResult(
        summary: "맑고 18°C, 오후 카페 모임 잊지 마세요!",
        detail: "오늘은 맑은 날씨에 기온이 18°C로 나들이하기 좋은 날이에요! 오후 2시에 카페 모임이 있으니 여유롭게 준비하세요. 즐거운 하루 보내세요 ☀️"
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var briefingClient: BriefingClient {
    get { self[BriefingClient.self] }
    set { self[BriefingClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension BriefingClient: DependencyKey {
  public static let liveValue: BriefingClient = {
    let functions = DefaultFunctionsProvider().functions

    return Self(
      generate: { input in
        var data: [String: Any] = [
          "timezone": input.timezone,
          "language": input.language,
          "forceRefresh": input.forceRefresh,
        ]
        if let location = input.location {
          var locationData: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
          ]
          if let title = location.title {
            locationData["title"] = title
          }
          data["location"] = locationData
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.briefing.debug("🎯 [BriefingClient] 브리핑 생성 시작 - timezone: \(input.timezone), location: \(input.location?.title ?? "없음")")

        do {
          let result = try await functions.httpsCallable("generateBriefing").call(data)

          guard let responseData = result.data as? [String: Any],
                let summary = responseData["summary"] as? String,
                let detail = responseData["detail"] as? String
          else {
            AppLogger.briefing.error("❌ [BriefingClient] 응답 파싱 실패")
            throw BriefingClientError.invalidResponse
          }

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.briefing.info("🎉 [BriefingClient] 브리핑 생성 완료 - 총 소요시간: \(String(format: "%.2f", totalTime))초")

          return BriefingResult(summary: summary, detail: detail)
        } catch let error as NSError {
          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.briefing.error("❌ [BriefingClient] Firebase Functions 에러: \(error.localizedDescription), 소요시간: \(String(format: "%.2f", totalTime))초")

          if error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            switch code {
            case .unauthenticated:
              throw BriefingClientError.notAuthenticated
            case .invalidArgument:
              throw BriefingClientError.invalidResponse
            default:
              throw BriefingClientError.serverError(error.localizedDescription)
            }
          }

          throw BriefingClientError.networkError
        }
      }
    )
  }()
}
