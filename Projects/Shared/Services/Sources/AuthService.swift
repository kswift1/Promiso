//import Foundation
//import Dependencies
//import CoreDependencies
//import CoreNetworking
//import CoreStorage
//import CoreLogger
//import SharedModels
//
//// MARK: - Auth Request Models
//
///// 로그인 요청
//public struct LoginRequest: Codable {
//  public let email: String
//  public let password: String
//  
//  public init(email: String, password: String) {
//    self.email = email
//    self.password = password
//  }
//}
//
///// 회원가입 요청
//public struct SignupRequest: Codable {
//  public let email: String
//  public let password: String
//  public let name: String
//  public let phoneNumber: String?
//  
//  public init(email: String, password: String, name: String, phoneNumber: String? = nil) {
//    self.email = email
//    self.password = password
//    self.name = name
//    self.phoneNumber = phoneNumber
//  }
//}
//
///// 토큰 갱신 요청
//public struct RefreshTokenRequest: Codable {
//  public let refreshToken: String
//  
//  public init(refreshToken: String) {
//    self.refreshToken = refreshToken
//  }
//}
//
//// MARK: - Auth Response Models
//
///// 인증 응답
//public struct AuthResponse: Codable {
//  public let user: User
//  public let accessToken: String
//  public let refreshToken: String
//  public let expiresIn: Int
//  
//  public init(user: User, accessToken: String, refreshToken: String, expiresIn: Int) {
//    self.user = user
//    self.accessToken = accessToken
//    self.refreshToken = refreshToken
//    self.expiresIn = expiresIn
//  }
//}
//
//// MARK: - Auth API Requests
//
///// 로그인 API 요청
//struct LoginAPIRequest: APIRequest {
//  typealias Response = AuthResponse
//  
//  let body: Data?
//  
//  var path: String { "/auth/login" }
//  var method: HTTPMethod { .POST }
//  
//  init(request: LoginRequest) throws {
//    self.body = try JSONEncoder().encode(request)
//  }
//}
//
///// 회원가입 API 요청
//struct SignupAPIRequest: APIRequest {
//  typealias Response = AuthResponse
//  
//  let body: Data?
//  
//  var path: String { "/auth/signup" }
//  var method: HTTPMethod { .POST }
//  
//  init(request: SignupRequest) throws {
//    self.body = try JSONEncoder().encode(request)
//  }
//}
//
///// 토큰 갱신 API 요청
//struct RefreshTokenAPIRequest: APIRequest {
//  typealias Response = AuthResponse
//  
//  let body: Data?
//  
//  var path: String { "/auth/refresh" }
//  var method: HTTPMethod { .POST }
//  
//  init(request: RefreshTokenRequest) throws {
//    self.body = try JSONEncoder().encode(request)
//  }
//}
//
///// 로그아웃 API 요청
//struct LogoutAPIRequest: APIRequest {
//  typealias Response = EmptyResponse
//  
//  var path: String { "/auth/logout" }
//  var method: HTTPMethod { .POST }
//}
//
///// 빈 응답
//public struct EmptyResponse: Codable {
//  public init() {}
//}
//
//// MARK: - Auth Service Protocol
//
///// 인증 서비스 프로토콜
//public protocol AuthServiceProtocol: Sendable {
//  func login(email: String, password: String) async throws -> AuthResponse
//  func signup(email: String, password: String, name: String, phoneNumber: String?) async throws -> AuthResponse
//  func logout() async throws
//  func refreshToken() async throws -> AuthResponse
//  func getCurrentUser() async throws -> User?
//  func isAuthenticated() async -> Bool
//}
//
//// MARK: - Auth Service Implementation
//
///// 인증 서비스 구현
//public final class AuthService: AuthServiceProtocol, @unchecked Sendable {
//  @Dependency(\.apiClient) private var apiClient
//  @Dependency(\.keychain) private var keychain
//  @Dependency(\.userDefaults) private var userDefaults
//  @Dependency(\.logger) private var logger
//  
//  public init() {}
//  
//  public func login(email: String, password: String) async throws -> AuthResponse {
//    logger.info("Attempting login for email: \(email)", "Auth", #file, #function, #line)
//    
//    let request = LoginRequest(email: email, password: password)
//    let apiRequest = try LoginAPIRequest(request: request)
//    let response: AuthResponse = try await apiClient.send(apiRequest) as! AuthResponse
//    
//    // 토큰 저장
//    try await saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
//    
//    // 사용자 정보 저장
//    await saveUserInfo(response.user)
//    
//    logger.info("Login successful for user: \(response.user.id)", "Auth", #file, #function, #line)
//    return response
//  }
//  
//  public func signup(email: String, password: String, name: String, phoneNumber: String?) async throws -> AuthResponse {
//    logger.info("Attempting signup for email: \(email)", "Auth", #file, #function, #line)
//    
//    let request = SignupRequest(email: email, password: password, name: name, phoneNumber: phoneNumber)
//    let apiRequest = try SignupAPIRequest(request: request)
//    let response: AuthResponse = try await apiClient.send(apiRequest) as! AuthResponse
//    
//    // 토큰 저장
//    try await saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
//    
//    // 사용자 정보 저장
//    await saveUserInfo(response.user)
//    
//    logger.info("Signup successful for user: \(response.user.id)", "Auth", #file, #function, #line)
//    return response
//  }
//  
//  public func logout() async throws {
//    logger.info("Attempting logout", "Auth", #file, #function, #line)
//    
//    // 서버에 로그아웃 요청
//    let apiRequest = LogoutAPIRequest()
//    let _: EmptyResponse = try await apiClient.send(apiRequest) as! EmptyResponse
//    
//    // 로컬 토큰 및 사용자 정보 삭제
//    try await clearAuthData()
//    
//    logger.info("Logout successful", "Auth", #file, #function, #line)
//  }
//  
//  public func refreshToken() async throws -> AuthResponse {
//    logger.info("Attempting token refresh", "Auth", #file, #function, #line)
//    
//    guard let refreshToken = try await keychain.getString("auth.refreshToken") else {
//      throw APIError.networkError("No refresh token found")
//    }
//    
//    let request = RefreshTokenRequest(refreshToken: refreshToken)
//    let apiRequest = try RefreshTokenAPIRequest(request: request)
//    let response: AuthResponse = try await apiClient.send(apiRequest) as! AuthResponse
//    
//    // 새로운 토큰 저장
//    try await saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
//    
//    logger.info("Token refresh successful", "Auth", #file, #function, #line)
//    return response
//  }
//  
//  public func getCurrentUser() async throws -> User? {
//    let userId = userDefaults.getString("user.id")
//    let userEmail = userDefaults.getString("user.email")
//    
//    guard let userId = userId, let userEmail = userEmail else {
//      return nil
//    }
//    
//    // 실제로는 서버에서 최신 사용자 정보를 가져와야 함
//    // 여기서는 저장된 기본 정보만 반환
//    return User(
//      id: UUID(uuidString: userId) ?? UUID(),
//      email: userEmail,
//      name: userDefaults.getString("user.name") ?? ""
//    )
//  }
//  
//  public func isAuthenticated() async -> Bool {
//    do {
//      let accessToken = try await keychain.getString("auth.accessToken")
//      return accessToken.isNotEmpty
//    } catch {
//      return false
//    }
//  }
//}
//
//// MARK: - Private Methods
//
//private extension AuthService {
//  func saveTokens(accessToken: String, refreshToken: String) async throws {
//    try await keychain.setString(accessToken, "auth.accessToken")
//    try await keychain.setString(refreshToken, "auth.refreshToken")
//  }
//  
//  func saveUserInfo(_ user: User) async {
//    userDefaults.setString(user.id.uuidString, for: "user.id")
//    userDefaults.setString(user.email, for: "user.email")
//    userDefaults.setString(user.name, for: "user.name")
//  }
//  
//  func clearAuthData() async throws {
//    // 키체인에서 토큰 삭제
//    try await keychain.delete("auth.accessToken")
//    try await keychain.delete("auth.refreshToken")
//    
//    // UserDefaults에서 사용자 정보 삭제
//    userDefaults.remove("user.id")
//    userDefaults.remove("user.email")
//    userDefaults.remove("user.name")
//  }
//}
//
//// MARK: - Auth Service Dependency
//
///// TCA Dependency로 Auth Service 등록
//public struct AuthServiceClient: Sendable {
//  public var login: @Sendable (String, String) async throws -> AuthResponse
//  public var signup: @Sendable (String, String, String, String?) async throws -> AuthResponse
//  public var logout: @Sendable () async throws -> Void
//  public var refreshToken: @Sendable () async throws -> AuthResponse
//  public var getCurrentUser: @Sendable () async throws -> User?
//  public var isAuthenticated: @Sendable () async -> Bool
//  
//  public init(
//    login: @escaping @Sendable (String, String) async throws -> AuthResponse,
//    signup: @escaping @Sendable (String, String, String, String?) async throws -> AuthResponse,
//    logout: @escaping @Sendable () async throws -> Void,
//    refreshToken: @escaping @Sendable () async throws -> AuthResponse,
//    getCurrentUser: @escaping @Sendable () async throws -> User?,
//    isAuthenticated: @escaping @Sendable () async -> Bool
//  ) {
//    self.login = login
//    self.signup = signup
//    self.logout = logout
//    self.refreshToken = refreshToken
//    self.getCurrentUser = getCurrentUser
//    self.isAuthenticated = isAuthenticated
//  }
//}
//
//extension AuthServiceClient: DependencyKey {
//  public static let liveValue: AuthServiceClient = {
//    let service = AuthService()
//    
//    return AuthServiceClient(
//      login: service.login,
//      signup: service.signup,
//      logout: service.logout,
//      refreshToken: service.refreshToken,
//      getCurrentUser: service.getCurrentUser,
//      isAuthenticated: service.isAuthenticated
//    )
//  }()
//  
//  public static let testValue: AuthServiceClient = AuthServiceClient(
//    login: { _, _ in throw APIError.networkError("Test mode") },
//    signup: { _, _, _, _ in throw APIError.networkError("Test mode") },
//    logout: { throw APIError.networkError("Test mode") },
//    refreshToken: { throw APIError.networkError("Test mode") },
//    getCurrentUser: { nil },
//    isAuthenticated: { false }
//  )
//}
//
//extension DependencyValues {
//  public var authService: AuthServiceClient {
//    get { self[AuthServiceClient.self] }
//    set { self[AuthServiceClient.self] = newValue }
//  }
//}
