import AuthenticationServices
import ComposableArchitecture
import Foundation

// MARK: - Error

public enum AuthClientError: Error, Equatable {
  case invalidCredentials
  case alreadyExists
  case network
  case invalidAppleCredential
  case missingIdentityToken
  case providerUnavailable
  case unknown
  
  public var localizedDescription: String {
    switch self {
    case .invalidCredentials:
      return "이메일 또는 비밀번호가 올바르지 않습니다."
    case .alreadyExists:
      return "이미 가입된 계정입니다."
    case .network:
      return "네트워크 연결을 확인해주세요."
    case .invalidAppleCredential:
      return "애플 인증 정보를 가져오지 못했습니다."
    case .missingIdentityToken:
      return "애플 인증 토큰을 가져오지 못했습니다."
    case .providerUnavailable:
      return "해당 로그인 제공자를 사용할 수 없습니다."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}

// MARK: - Models

public struct AuthTokenBundle: Equatable {
  public let provider: AuthProvider
  public let identityToken: String
  public let userIdentifier: String
  
  public init(provider: AuthProvider, identityToken: String, userIdentifier: String) {
    self.provider = provider
    self.identityToken = identityToken
    self.userIdentifier = userIdentifier
  }
}

// MARK: - Client

@DependencyClient
public struct AuthClient: Sendable {
  public var login: @Sendable (_ email: String, _ password: String) async throws -> Void = { _, _ in }
  public var signup: @Sendable (_ email: String, _ password: String, _ name: String, _ phone: String?) async throws -> Void = { _, _, _, _ in }
  public var logout: @Sendable () async throws -> Void = {}
  public var isAuthenticated: @Sendable () async -> Bool = { false }
  public var signInWithApple: @Sendable (_ authorization: ASAuthorization) async throws -> Void = { _ in }
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
  public static let previewValue = Self(
    login: { _, _ in },
    signup: { _, _, _, _ in },
    logout: {},
    isAuthenticated: { false },
    signInWithApple: { _ in }
  )
  
  public static let testValue = Self(
    login: unimplemented("\(Self.self).login"),
    signup: unimplemented("\(Self.self).signup"),
    logout: unimplemented("\(Self.self).logout"),
    isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: false),
    signInWithApple: unimplemented("\(Self.self).signInWithApple")
  )
}

// MARK: - Live

private actor InMemoryAuthSession {
  private var isAuthed: Bool = false
  
  func login() {
    isAuthed = true
  }
  
  func logout() {
    isAuthed = false
  }
  
  func status() -> Bool {
    isAuthed
  }
}

extension AuthClient: DependencyKey {
  public static let liveValue: AuthClient = {
    let session = InMemoryAuthSession()
    let provider = PlatformAuthProvider()
    
    return Self(
      login: { email, password in
        guard !email.isEmpty, !password.isEmpty else {
          throw AuthClientError.invalidCredentials
        }
        await session.login()
      },
      signup: { email, password, _, _ in
        guard !email.isEmpty, !password.isEmpty else {
          throw AuthClientError.invalidCredentials
        }
        await session.login()
      },
      logout: {
        await session.logout()
      },
      isAuthenticated: {
        await session.status()
      },
      signInWithApple: { authorization in
        let tokenBundle = try await provider.signInWithApple(authorization)
        
        // TODO: 서버 교환 로직 추가 (tokenBundle.identityToken 전달)
        _ = tokenBundle.userIdentifier
        await session.login()
      }
    )
  }()
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}
