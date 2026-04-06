import Foundation

/// Rust 백엔드 API 호출 클라이언트
public actor RustAPIClient {
  /// 환경별 기본 URL
  /// - Dev: 시뮬레이터에서 로컬 서버 접근 불가하므로 LAN IP 사용
  /// - Prod: Cloud Run 배포 후 URL 변경
  public static let defaultBaseURL: URL = {
    #if DEBUG
    return URL(string: "https://promiso-api-809932911903.asia-northeast3.run.app")!
    #else
    // TODO: Prod Cloud Run URL (별도 프로젝트에 배포 후 변경)
    return URL(string: "https://promiso-api-809932911903.asia-northeast3.run.app")!
    #endif
  }()

  private let baseURL: URL
  private let getAuthToken: () async throws -> String
  private let decoder: JSONDecoder

  public init(
    baseURL: URL = RustAPIClient.defaultBaseURL,
    getAuthToken: @escaping () async throws -> String
  ) {
    self.baseURL = baseURL
    self.getAuthToken = getAuthToken
    self.decoder = JSONDecoder()
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder.dateDecodingStrategy = .iso8601
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

    // Firebase ID 토큰 첨부
    let token = try await getAuthToken()
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    if let body = body, !(body is Empty) {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      urlRequest.httpBody = try encoder.encode(body)
    }

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RustAPIError.invalidResponse
    }

    if httpResponse.statusCode >= 400 {
      if let apiResponse = try? decoder.decode(ApiResponse<T>.self, from: data),
         let error = apiResponse.error {
        throw RustAPIError.serverError(code: error.code, message: error.message)
      }
      throw RustAPIError.httpError(statusCode: httpResponse.statusCode)
    }

    let apiResponse = try decoder.decode(ApiResponse<T>.self, from: data)
    guard let result = apiResponse.data else {
      throw RustAPIError.noData
    }
    return result
  }
}

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
