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
  public let currentDateTime: String
  public let currentLocation: String?
  public let weather: WeatherSummary?
  public let schedules: String

  public struct WeatherSummary: Equatable, Sendable {
    public let temp: Double
    public let condition: String
    public let rain: Int
    public let max: Double
    public let min: Double

    public init(temp: Double, condition: String, rain: Int, max: Double, min: Double) {
      self.temp = temp
      self.condition = condition
      self.rain = rain
      self.max = max
      self.min = min
    }
  }

  public init(
    currentDateTime: String,
    currentLocation: String?,
    weather: WeatherSummary?,
    schedules: String
  ) {
    self.currentDateTime = currentDateTime
    self.currentLocation = currentLocation
    self.weather = weather
    self.schedules = schedules
  }
}

// MARK: - Client

/// TCA용 브리핑 생성 클라이언트
@DependencyClient
public struct BriefingClient: Sendable {
  /// 오늘의 브리핑 생성 (Firebase Functions 사용)
  public var generate: @Sendable (_ input: BriefingInput) async throws -> String
}

// MARK: - Test & Preview Values

extension BriefingClient: TestDependencyKey {
  public static let testValue = Self(
    generate: unimplemented("\(Self.self).generate", placeholder: "")
  )

  public static let previewValue = Self(
    generate: { _ in
      try await Task.sleep(for: .seconds(1))
      return "오늘은 맑은 날씨에 기온이 18°C로 나들이하기 좋은 날이에요! 오후 2시에 카페 모임이 있으니 여유롭게 준비하세요. 즐거운 하루 보내세요 ☀️"
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
          "currentDateTime": input.currentDateTime,
          "schedules": input.schedules,
        ]
        if let location = input.currentLocation {
          data["currentLocation"] = location
        }
        if let weather = input.weather {
          data["weather"] = [
            "temp": weather.temp,
            "condition": weather.condition,
            "rain": weather.rain,
            "max": weather.max,
            "min": weather.min,
          ] as [String: Any]
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.briefing.debug("🎯 [BriefingClient] 브리핑 생성 시작 - 날짜: \(input.currentDateTime)")

        do {
          let result = try await functions.httpsCallable("generateBriefing").call(data)

          guard let responseData = result.data as? [String: Any],
                let briefing = responseData["briefing"] as? String
          else {
            AppLogger.briefing.error("❌ [BriefingClient] 응답 파싱 실패")
            throw BriefingClientError.invalidResponse
          }

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.briefing.info("🎉 [BriefingClient] 브리핑 생성 완료 - 총 소요시간: \(String(format: "%.2f", totalTime))초")

          return briefing
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
