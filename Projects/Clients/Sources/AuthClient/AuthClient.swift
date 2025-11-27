import AuthenticationServices
import ComposableArchitecture
import FirebaseCore
import Foundation
import UIKit
import GoogleSignIn
import GoogleSignInSwift
import KakaoSDKAuth
import KakaoSDKUser

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
  public let identityToken: String?
  public let accessToken: String?
  public let refreshToken: String?
  public let userIdentifier: String
  
  public init(
    provider: AuthProvider,
    identityToken: String?,
    accessToken: String?,
    refreshToken: String?,
    userIdentifier: String
  ) {
    self.provider = provider
    self.identityToken = identityToken
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.userIdentifier = userIdentifier
  }
}

public enum AuthProvider: Equatable {
  case apple
  case kakao
  case google
}

// MARK: - Platform Auth Providers

public protocol PlatformAuthProviding {
  func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthTokenBundle
  func signInWithKakao() async throws -> AuthTokenBundle
  func signInWithGoogle() async throws -> AuthTokenBundle
}


public struct PlatformAuthProvider: PlatformAuthProviding, Sendable {
  public init() {}
  
  @MainActor
  public func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthTokenBundle {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      throw AuthClientError.invalidAppleCredential
    }
    guard let identityToken = appleIDCredential.identityToken,
          let tokenString = String(data: identityToken, encoding: .utf8) else {
      throw AuthClientError.missingIdentityToken
    }
    
    return AuthTokenBundle(
      provider: .apple,
      identityToken: tokenString,
      accessToken: nil,
      refreshToken: nil,
      userIdentifier: appleIDCredential.user
    )
  }
  
  @MainActor
  public func signInWithKakao() async throws -> AuthTokenBundle {
    let oauthToken = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OAuthToken, Error>) in
      if UserApi.isKakaoTalkLoginAvailable() {
        UserApi.shared.loginWithKakaoTalk { token, error in
          if let error { continuation.resume(throwing: error); return }
          guard let token else { continuation.resume(throwing: AuthClientError.unknown); return }
          continuation.resume(returning: token)
        }
      } else {
        UserApi.shared.loginWithKakaoAccount { token, error in
          if let error { continuation.resume(throwing: error); return }
          guard let token else { continuation.resume(throwing: AuthClientError.unknown); return }
          continuation.resume(returning: token)
        }
      }
    }
    
    let userId: String = try await withCheckedThrowingContinuation { continuation in
      UserApi.shared.me { user, error in
        if let error { continuation.resume(throwing: error); return }
        if let id = user?.id {
          continuation.resume(returning: String(id))
        } else {
          continuation.resume(throwing: AuthClientError.unknown)
        }
      }
    }
    
    return AuthTokenBundle(
      provider: .kakao,
      identityToken: oauthToken.idToken,
      accessToken: oauthToken.accessToken,
      refreshToken: oauthToken.refreshToken,
      userIdentifier: userId
    )
  }
  
  @MainActor
  public func signInWithGoogle() async throws -> AuthTokenBundle {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      throw AuthClientError.providerUnavailable
    }
    
    let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    let user = signInResult.user
    
    return AuthTokenBundle(
      provider: .google,
      identityToken: user.idToken?.tokenString,
      accessToken: user.accessToken.tokenString,
      refreshToken: nil,
      userIdentifier: user.userID ?? ""
    )
  }
}

// MARK: - Client

@DependencyClient
public struct AuthClient: Sendable {
  public var login: @Sendable (_ email: String, _ password: String) async throws -> Void = { _, _ in }
  public var signup: @Sendable (_ email: String, _ password: String, _ name: String, _ phone: String?) async throws -> Void = { _, _, _, _ in }
  public var logout: @Sendable () async throws -> Void = {}
  public var isAuthenticated: @Sendable () async -> Bool = { false }
  public var signInWithApple: @Sendable (_ authorization: ASAuthorization) async throws -> AuthTokenBundle = { _ in .init(provider: .apple, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "") }
  public var signInWithKakao: @Sendable () async throws -> AuthTokenBundle = { .init(provider: .kakao, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "") }
  public var signInWithGoogle: @Sendable () async throws -> AuthTokenBundle = { .init(provider: .google, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "") }
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
  public static let previewValue = Self(
    login: { _, _ in },
    signup: { _, _, _, _ in },
    logout: {},
    isAuthenticated: { false },
    signInWithApple: { _ in .init(provider: .apple, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "preview") },
    signInWithKakao: { .init(provider: .kakao, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "preview") },
    signInWithGoogle: { .init(provider: .google, identityToken: nil, accessToken: nil, refreshToken: nil, userIdentifier: "preview") }
  )
  
  public static let testValue = Self(
    login: unimplemented("\(Self.self).login"),
    signup: unimplemented("\(Self.self).signup"),
    logout: unimplemented("\(Self.self).logout"),
    isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: false),
    signInWithApple: unimplemented("\(Self.self).signInWithApple"),
    signInWithKakao: unimplemented("\(Self.self).signInWithKakao"),
    signInWithGoogle: unimplemented("\(Self.self).signInWithGoogle")
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
        await session.login()
        return tokenBundle
      },
      signInWithKakao: {
        let tokenBundle = try await provider.signInWithKakao()
        await session.login()
        return tokenBundle
      },
      signInWithGoogle: {
        let tokenBundle = try await provider.signInWithGoogle()
        await session.login()
        return tokenBundle
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
