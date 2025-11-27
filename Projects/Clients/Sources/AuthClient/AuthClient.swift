import ComposableArchitecture
import Foundation

// MARK: - Error

public enum AuthClientError: Error, Equatable {
  case invalidCredentials
  case alreadyExists
  case network
  case unknown
  
  public var localizedDescription: String {
    switch self {
    case .invalidCredentials:
      return "이메일 또는 비밀번호가 올바르지 않습니다."
    case .alreadyExists:
      return "이미 가입된 계정입니다."
    case .network:
      return "네트워크 연결을 확인해주세요."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}

// MARK: - Client

@DependencyClient
public struct AuthClient: Sendable {
  public var login: @Sendable (_ email: String, _ password: String) async throws -> Void = { _, _ in }
  public var signup: @Sendable (_ email: String, _ password: String, _ name: String, _ phone: String?) async throws -> Void = { _, _, _, _ in }
  public var logout: @Sendable () async throws -> Void = {}
  public var isAuthenticated: @Sendable () async -> Bool = { false }
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
  public static let previewValue = Self(
    login: { _, _ in },
    signup: { _, _, _, _ in },
    logout: {},
    isAuthenticated: { false }
  )
  
  public static let testValue = Self(
    login: unimplemented("\(Self.self).login"),
    signup: unimplemented("\(Self.self).signup"),
    logout: unimplemented("\(Self.self).logout"),
    isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: false)
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
