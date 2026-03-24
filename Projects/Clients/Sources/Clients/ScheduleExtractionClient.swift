import ComposableArchitecture
import FirebaseFunctions
import Foundation
import PromisoShared

// MARK: - Error

/// 일정 추출 API 에러
public enum ScheduleExtractionError: Error, Equatable {
  case notAuthenticated
  case networkError
  case invalidResponse
  case serverError(String)
  case textTooLong
  case emptyText

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
    case .textTooLong:
      return LocalizedStrings.Error.textTooLong
    case .emptyText:
      return LocalizedStrings.Error.emptyText
    }
  }
}

// MARK: - Client

/// 텍스트에서 일정 정보를 추출하는 Client (LLM 기반)
@DependencyClient
public struct ScheduleExtractionClient: Sendable {
  /// 텍스트에서 일정 정보 추출 (Firebase Function 호출)
  public var extractFromText: @Sendable (_ text: String) async throws -> PersonalEventModel
}

// MARK: - Test & Preview Values

extension ScheduleExtractionClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    extractFromText: { _ in
      try await Task.sleep(for: .seconds(1))
      return PersonalEventModel(
        title: "주말 모임",
        startAt: Date().addingTimeInterval(86400),
        location: LocationInfoModel(name: "강남역")
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var scheduleExtractionClient: ScheduleExtractionClient {
    get { self[ScheduleExtractionClient.self] }
    set { self[ScheduleExtractionClient.self] = newValue }
  }
}

// MARK: - ISO 8601 Parsing Helpers

private extension ISO8601DateFormatter {
  /// Gemini가 반환하는 다양한 ISO 8601 포맷을 파싱 (fractionalSeconds 포함)
  static let flexible: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// fractionalSeconds 없는 표준 버전
  static let standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}

/// ISO 8601 문자열을 Date로 파싱 (여러 포맷 시도)
private func parseISO8601Date(_ string: String) -> Date? {
  if let date = ISO8601DateFormatter.flexible.date(from: string) {
    return date
  }
  if let date = ISO8601DateFormatter.standard.date(from: string) {
    return date
  }
  // "2026-03-27T09:00:00+09:00" 형식도 처리
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
  formatter.locale = Locale(identifier: "en_US_POSIX")
  return formatter.date(from: string)
}

// MARK: - Live Implementation

extension ScheduleExtractionClient: DependencyKey {
  public static let liveValue: ScheduleExtractionClient = {
    let functions = DefaultFunctionsProvider().functions

    return Self(
      extractFromText: { text in
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
          throw ScheduleExtractionError.emptyText
        }
        guard trimmedText.count <= 2000 else {
          throw ScheduleExtractionError.textTooLong
        }

        AppLogger.general.debug("📋 [ScheduleExtraction] 일정 추출 시작 (\(trimmedText.count)자)")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
          let result = try await functions.httpsCallable("extractSchedule").call([
            "text": trimmedText,
            "timezone": TimeZone.current.identifier,
          ])

          guard let data = result.data as? [String: Any] else {
            AppLogger.general.error("❌ [ScheduleExtraction] 응답 파싱 실패")
            throw ScheduleExtractionError.invalidResponse
          }

          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.info("✅ [ScheduleExtraction] 추출 완료 (소요: \(String(format: "%.2f", totalTime))초)")

          // PersonalEventModel 구성
          var event = PersonalEventModel()

          if let title = data["title"] as? String, !title.isEmpty {
            event.title = String(title.prefix(30))
          }

          if let startDateStr = data["startDate"] as? String,
             let startDate = parseISO8601Date(startDateStr) {
            event.startAt = startDate
          }

          if let endDateStr = data["endDate"] as? String,
             let endDate = parseISO8601Date(endDateStr) {
            event.endAt = endDate
          }

          if let locationName = data["location"] as? String, !locationName.isEmpty {
            let address = data["address"] as? String
            event.location = LocationInfoModel(
              name: locationName,
              address: address
            )
          }

          if let description = data["description"] as? String, !description.isEmpty {
            event.description = String(description.prefix(500))
          }

          return event
        } catch let error as ScheduleExtractionError {
          throw error
        } catch let error as NSError {
          let totalTime = CFAbsoluteTimeGetCurrent() - startTime
          AppLogger.general.error("❌ [ScheduleExtraction] 에러: \(error.localizedDescription) (소요: \(String(format: "%.2f", totalTime))초)")

          if error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            switch code {
            case .unauthenticated:
              throw ScheduleExtractionError.notAuthenticated
            case .invalidArgument:
              throw ScheduleExtractionError.invalidResponse
            default:
              throw ScheduleExtractionError.serverError(error.localizedDescription)
            }
          }
          throw ScheduleExtractionError.networkError
        }
      }
    )
  }()
}
