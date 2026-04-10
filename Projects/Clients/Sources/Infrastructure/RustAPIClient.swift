import Foundation
import PromisoShared

/// Rust 백엔드 API 호출 클라이언트
public actor RustAPIClient {
  /// 환경별 기본 URL
  /// - Dev: 시뮬레이터에서 로컬 서버 접근 불가하므로 LAN IP 사용
  /// - Prod: Cloud Run 배포 후 URL 변경
  public static let defaultBaseURL: URL = {
    #if DEBUG
    return URL(string: "https://promiso-api-809932911903.asia-northeast3.run.app")!
    #else
    #warning("Prod Cloud Run URL이 설정되지 않았습니다. 배포 전 반드시 Prod URL로 변경하세요.")
    return URL(string: "https://promiso-api-809932911903.asia-northeast3.run.app")!
    #endif
  }()

  #if DEBUG
  private static let pulseDelegate = URLSessionProxyDelegate()
  private static let session = URLSession(
    configuration: .default,
    delegate: pulseDelegate,
    delegateQueue: nil
  )
  #else
  private static let session = URLSession.shared
  #endif

  public static func defaultAuthToken() async throws -> String {
    try await ServerAuthSessionManager.shared.currentAccessToken()
  }

  private let baseURL: URL
  private let getAuthToken: (() async throws -> String)?
  private let decoder: JSONDecoder

  public init(
    baseURL: URL = RustAPIClient.defaultBaseURL,
    getAuthToken: (() async throws -> String)? = RustAPIClient.defaultAuthToken
  ) {
    self.baseURL = baseURL
    self.getAuthToken = getAuthToken
    self.decoder = JSONDecoder()
    let isoWithFractional = ISO8601DateFormatter()
    isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithout = ISO8601DateFormatter()
    isoWithout.formatOptions = [.withInternetDateTime]
    self.decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      if let date = isoWithFractional.date(from: string) { return date }
      if let date = isoWithout.date(from: string) { return date }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
    }
  }

  /// API 응답 wrapper ({"data": T} 또는 {"error": {...}})
  private struct ApiResponse<T: Decodable>: Decodable {
    let data: T?
    let error: ApiError?
  }

  private struct ApiError: Decodable {
    let code: String
    let message: String
  }

  public func get<T: Decodable>(_ path: String) async throws -> T {
    try await request(method: "GET", path: path, body: nil as Empty?)
  }

  public func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
    try await request(method: "POST", path: path, body: body)
  }

  public func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
    try await request(method: "PATCH", path: path, body: body)
  }

  public func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
    try await request(method: "PUT", path: path, body: body)
  }

  public func delete<T: Decodable>(_ path: String) async throws -> T {
    try await request(method: "DELETE", path: path, body: nil as Empty?)
  }

  private struct Empty: Encodable {}

  private func request<B: Encodable, T: Decodable>(
    method: String,
    path: String,
    body: B?
  ) async throws -> T {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw RustAPIError.invalidResponse
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let getAuthToken {
      let token = try await getAuthToken()
      urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    if let body = body, !(body is Empty) {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      urlRequest.httpBody = try encoder.encode(body)
    }

    #if DEBUG
    if let httpBody = urlRequest.httpBody {
      AppLogger.network.info("➡️ \(method) \(path)\n\(prettyJSON(httpBody))")
    } else {
      AppLogger.network.info("➡️ \(method) \(path)")
    }
    #endif

    #if DEBUG
    let (data, response) = try await Self.session.data(for: urlRequest, delegate: Self.pulseDelegate)
    #else
    let (data, response) = try await Self.session.data(for: urlRequest)
    #endif

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RustAPIError.invalidResponse
    }

    #if DEBUG
    AppLogger.network.info("⬅️ \(httpResponse.statusCode) \(method) \(path)\n\(prettyJSON(data))")
    #endif

    if httpResponse.statusCode >= 400 {
      if let apiResponse = try? decoder.decode(ApiResponse<T>.self, from: data),
         let error = apiResponse.error {
        AppLogger.network.error("❌ \(method) \(path) - \(error.code): \(error.message)")
        throw RustAPIError.serverError(code: error.code, message: error.message)
      }
      AppLogger.network.error("❌ \(method) \(path) - HTTP \(httpResponse.statusCode)")
      throw RustAPIError.httpError(statusCode: httpResponse.statusCode)
    }

    let apiResponse = try decoder.decode(ApiResponse<T>.self, from: data)
    guard let result = apiResponse.data else {
      throw RustAPIError.noData
    }
    return result
  }
}

  #if DEBUG
private func prettyJSON(_ data: Data) -> String {
    guard
      let json = try? JSONSerialization.jsonObject(with: data),
      let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
      let string = String(data: pretty, encoding: .utf8)
    else {
      return String(data: data, encoding: .utf8) ?? "(\(data.count) bytes)"
    }
    return string
  }
  #endif

public enum RustAPIError: Error, LocalizedError {
  case invalidResponse
  case httpError(statusCode: Int)
  case serverError(code: String, message: String)
  case noData

  public var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Invalid response"
    case .httpError(let code):
      return "HTTP error: \(code)"
    case .serverError(_, let message):
      return message
    case .noData:
      return "No data in response"
    }
  }
}
