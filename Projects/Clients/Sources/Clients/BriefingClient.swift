import ComposableArchitecture
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

// MARK: - Input

public struct BriefingInput: Equatable, Sendable {
  public let timezone: String
  public let language: String
  public let location: BriefingLocation?
  public let forceRefresh: Bool
  public let style: BriefingStyle?

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
    forceRefresh: Bool = false,
    style: BriefingStyle? = nil
  ) {
    self.timezone = timezone
    self.language = language
    self.location = location
    self.forceRefresh = forceRefresh
    self.style = style
  }
}

// MARK: - Result

public struct BriefingResult: Equatable, Sendable {
  public let summary: String
  public let detail: String
  /// 일정/날씨 변경으로 캐시가 재생성된 경우 true
  public let isUpdated: Bool
  /// 브리핑 생성에 사용된 스타일
  public let style: BriefingStyle?
  /// 이용 가능 교통수단
  public let availableTransports: Set<AvailableTransport>?
  /// 알림 시간 (0~23, nil=비활성화)
  public let notificationHour: Int?

  public init(
    summary: String,
    detail: String,
    isUpdated: Bool = false,
    style: BriefingStyle? = nil,
    availableTransports: Set<AvailableTransport>? = nil,
    notificationHour: Int? = nil
  ) {
    self.summary = summary
    self.detail = detail
    self.isUpdated = isUpdated
    self.style = style
    self.availableTransports = availableTransports
    self.notificationHour = notificationHour
  }
}

// MARK: - Client

/// TCA용 브리핑 생성 클라이언트
@DependencyClient
public struct BriefingClient: Sendable {
  /// 오늘의 브리핑 생성
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
    let rustDataSource = BriefingRustDataSource(
      api: RustAPIClient()
    )

    return Self(
      generate: { input in
        try await rustDataSource.generate(input: input)
      }
    )
  }()
}
