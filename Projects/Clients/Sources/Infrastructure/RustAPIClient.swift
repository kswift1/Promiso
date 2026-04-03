import Foundation

/// Rust 백엔드 API 호출 클라이언트
public actor RustAPIClient {
  private let baseURL: URL
  private let getAuthToken: () async throws -> String
  private let decoder: JSONDecoder

  public init(
    baseURL: URL = URL(string: "http://localhost:8080")!,
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

  private struct Empty: Encodable {}

  private func request<B: Encodable, T: Decodable>(
    method: String,
    path: String,
    body: B?
  ) async throws -> T {
    var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
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
