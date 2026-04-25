import Foundation
import PromisoShared

// MARK: - Request DTOs

private struct RustBriefingRequest: Encodable {
  let timezone: String
  let language: String
  let location: RustBriefingLocation?
  let forceRefresh: Bool?
  let style: String?
}

private struct RustBriefingLocation: Encodable {
  let latitude: Double
  let longitude: Double
  let title: String?
}

// MARK: - Response DTOs

private struct RustBriefingResponse: Decodable {
  let summary: String
  let detail: String
  let isUpdated: Bool?
  let style: String?
  let availableTransports: [String]?
  let notificationHour: Int?
}

// MARK: - Data Source

/// Rust 백엔드를 통한 브리핑 생성 데이터 관리
public actor BriefingRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Briefing Operations

  /// 오늘의 브리핑 생성
  public func generate(input: BriefingInput) async throws -> BriefingResult {
    let location = input.location.map {
      RustBriefingLocation(
        latitude: $0.latitude,
        longitude: $0.longitude,
        title: $0.title
      )
    }

    let body = RustBriefingRequest(
      timezone: input.timezone,
      language: input.language,
      location: location,
      forceRefresh: input.forceRefresh,
      style: input.style?.rawValue
    )

    let response: RustBriefingResponse = try await api.post("/api/v1/briefing/generate", body: body)
    return response.toModel()
  }
}

// MARK: - DTO → Model 변환

extension RustBriefingResponse {
  func toModel() -> BriefingResult {
    let resultStyle = style.flatMap { BriefingStyle(rawValue: $0) }
    let resultTransports: Set<AvailableTransport>? = availableTransports.map { raws in
      Set(raws.compactMap { AvailableTransport(rawValue: $0) })
    }

    return BriefingResult(
      summary: summary,
      detail: detail,
      isUpdated: isUpdated ?? false,
      style: resultStyle,
      availableTransports: resultTransports,
      notificationHour: notificationHour
    )
  }
}
