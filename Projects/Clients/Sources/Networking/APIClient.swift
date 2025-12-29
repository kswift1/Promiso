import Foundation
import ComposableArchitecture

// MARK: - HTTP Method

/// HTTP 메서드 정의
public enum HTTPMethod: String, CaseIterable {
  case GET = "GET"
  case POST = "POST"
  case PUT = "PUT"
  case PATCH = "PATCH"
  case DELETE = "DELETE"
}

// MARK: - API Request

/// API 요청을 정의하는 프로토콜
public protocol APIRequest {
  associatedtype Response: Codable
  
  var path: String { get }
  var method: HTTPMethod { get }
  var headers: [String: String] { get }
  var queryItems: [URLQueryItem] { get }
  var body: Data? { get }
}

public extension APIRequest {
  var headers: [String: String] { [:] }
  var queryItems: [URLQueryItem] { [] }
  var body: Data? { nil }
}

// MARK: - API Response

/// API 응답 래퍼
public struct APIResponse<T: Codable>: Codable {
  public let data: T
  public let statusCode: Int
  public let headers: [String: String]
  
  public init(data: T, statusCode: Int, headers: [String: String] = [:]) {
    self.data = data
    self.statusCode = statusCode
    self.headers = headers
  }
}

// MARK: - API Error

/// API 오류 정의
public enum APIError: Error, Equatable, LocalizedError {
  case invalidURL
  case noData
  case decodingError(String)
  case encodingError(String)
  case networkError(String)
  case httpError(Int, String)
  case timeout
  case cancelled
  case unknown(String)
  
  public var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "잘못된 URL입니다"
    case .noData:
      return "데이터가 없습니다"
    case .decodingError(let message):
      return "데이터 파싱 오류: \(message)"
    case .encodingError(let message):
      return "데이터 인코딩 오류: \(message)"
    case .networkError(let message):
      return "네트워크 오류: \(message)"
    case .httpError(let code, let message):
      return "HTTP 오류 (\(code)): \(message)"
    case .timeout:
      return "요청 시간이 초과되었습니다"
    case .cancelled:
      return "요청이 취소되었습니다"
    case .unknown(let message):
      return "알 수 없는 오류: \(message)"
    }
  }
}

// MARK: - API Client Protocol

/// API 클라이언트 프로토콜
public protocol APIClientProtocol: Sendable {
  func send<Request: APIRequest>(_ request: Request) async throws -> Request.Response
  func upload<Request: APIRequest>(
    _ request: Request,
    data: Data,
    contentType: String
  ) async throws -> Request.Response
}

// MARK: - API Client Implementation

/// 메인 API 클라이언트 구현
public final class APIClient: APIClientProtocol, @unchecked Sendable {
  private let session: URLSession
  private let baseURL: URL
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  
  public init(
    baseURL: URL,
    session: URLSession = .shared,
    decoder: JSONDecoder = .init(),
    encoder: JSONEncoder = .init()
  ) {
    self.baseURL = baseURL
    self.session = session
    self.decoder = decoder
    self.encoder = encoder
    
    // 기본 JSON 디코더 설정
    self.decoder.dateDecodingStrategy = .iso8601
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    // 기본 JSON 인코더 설정
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.keyEncodingStrategy = .convertToSnakeCase
  }
  
  public func send<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
    let urlRequest = try buildURLRequest(from: request)
    
//    logDebug("API Request: \(urlRequest.httpMethod ?? "GET") \(urlRequest.url?.absoluteString ?? "")", category: "Network")
    
    do {
      let (data, response) = try await session.data(for: urlRequest)
      return try handleResponse(data: data, response: response, for: request)
    } catch {
      if error is CancellationError {
        throw APIError.cancelled
      } else if let urlError = error as? URLError {
        throw mapURLError(urlError)
      } else {
        throw APIError.unknown(error.localizedDescription)
      }
    }
  }
  
  public func upload<Request: APIRequest>(
    _ request: Request,
    data: Data,
    contentType: String
  ) async throws -> Request.Response {
    var urlRequest = try buildURLRequest(from: request)
    urlRequest.httpBody = data
    urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
    
//    logDebug("API Upload: \(urlRequest.httpMethod ?? "POST") \(urlRequest.url?.absoluteString ?? "")", category: "Network")
    
    do {
      let (responseData, response) = try await session.data(for: urlRequest)
      return try handleResponse(data: responseData, response: response, for: request)
    } catch {
      if error is CancellationError {
        throw APIError.cancelled
      } else if let urlError = error as? URLError {
        throw mapURLError(urlError)
      } else {
        throw APIError.unknown(error.localizedDescription)
      }
    }
  }
}

// MARK: - Private Methods

private extension APIClient {
  func buildURLRequest<Request: APIRequest>(from request: Request) throws -> URLRequest {
    guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: true) else {
      throw APIError.invalidURL
    }
    
    if !request.queryItems.isEmpty {
      components.queryItems = request.queryItems
    }
    
    guard let url = components.url else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    
    // 기본 헤더 설정
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    if request.body != nil {
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    // 커스텀 헤더 추가
    for (key, value) in request.headers {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }
    
    return urlRequest
  }
  
  func handleResponse<Request: APIRequest>(
    data: Data,
    response: URLResponse,
    for request: Request
  ) throws -> Request.Response {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.networkError("Invalid response type")
    }
    
//    logDebug("API Response: \(httpResponse.statusCode)", category: "Network")
    
    // HTTP 상태 코드 확인
    guard 200...299 ~= httpResponse.statusCode else {
      let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw APIError.httpError(httpResponse.statusCode, errorMessage)
    }
    
    // 빈 응답 처리
    if data.isEmpty {
      throw APIError.noData
    }
    
    // JSON 디코딩
    do {
      let decodedResponse = try decoder.decode(Request.Response.self, from: data)
      return decodedResponse
    } catch {
      let decodingError = error.localizedDescription
//      logError("Decoding error: \(decodingError)", category: "Network")
      throw APIError.decodingError(decodingError)
    }
  }
  
  func mapURLError(_ error: URLError) -> APIError {
    switch error.code {
    case .timedOut:
      return .timeout
    case .cancelled:
      return .cancelled
    case .notConnectedToInternet, .networkConnectionLost:
      return .networkError("인터넷 연결을 확인해주세요")
    default:
      return .networkError(error.localizedDescription)
    }
  }
}

// MARK: - API Client Dependency

/// TCA Dependency로 API 클라이언트 등록
public struct APIClientDependency: Sendable {
  public var send: @Sendable (any APIRequest) async throws -> Any
  public var upload: @Sendable (any APIRequest, Data, String) async throws -> Any
  
  public init(
    send: @escaping @Sendable (any APIRequest) async throws -> Any,
    upload: @escaping @Sendable (any APIRequest, Data, String) async throws -> Any
  ) {
    self.send = send
    self.upload = upload
  }
}

extension APIClientDependency: DependencyKey {
  public static let liveValue: APIClientDependency = {
    guard let baseURL = URL(string: "https://api.promiso.com") else {
      fatalError("Invalid base URL")
    }
    let client = APIClient(baseURL: baseURL)
    
    return APIClientDependency(
      send: { request in
        return try await client.send(request)
      },
      upload: { request, data, contentType in
        return try await client.upload(request, data: data, contentType: contentType)
      }
    )
  }()
  
  public static let testValue: APIClientDependency = APIClientDependency(
    send: { _ in throw APIError.networkError("Test mode") },
    upload: { _, _, _ in throw APIError.networkError("Test mode") }
  )
}

extension DependencyValues {
  public var apiClient: APIClientDependency {
    get { self[APIClientDependency.self] }
    set { self[APIClientDependency.self] = newValue }
  }
}
