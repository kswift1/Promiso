import AuthenticationServices
import ComposableArchitecture
import CoreInfrastructure
import FirebaseCore
import FirebaseAuth
import Foundation
import GoogleSignIn
import GoogleSignInSwift
import UIKit

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

/// Firebase User를 모킹 가능하게 담는 스냅샷
public struct FirebaseUserSnapshot: Equatable, Sendable {
  public let uid: String
  public let email: String?
  public let displayName: String?
  public let photoURL: URL?
  public let creationDate: Date?
  public let lastSignInDate: Date?
  
  public init(
    uid: String,
    email: String?,
    displayName: String?,
    photoURL: URL?,
    creationDate: Date? = nil,
    lastSignInDate: Date? = nil
  ) {
    self.uid = uid
    self.email = email
    self.displayName = displayName
    self.photoURL = photoURL
    self.creationDate = creationDate
    self.lastSignInDate = lastSignInDate
  }
  
  public init?(user: FirebaseAuth.User?) {
    guard let user else { return nil }
    self.init(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      creationDate: user.metadata.creationDate,
      lastSignInDate: user.metadata.lastSignInDate
    )
  }
}

public struct ServiceTokenBundle: Equatable, Sendable {
  /// Firebase User 스냅샷
  public let firebaseUser: FirebaseUserSnapshot?
  /// 제공 토큰 번들
  public let providerTokenBundle: ProviderTokenBundle
  
  public init(firebaseUser: FirebaseUserSnapshot?, providerTokenBundle: ProviderTokenBundle) {
    self.firebaseUser = firebaseUser
    self.providerTokenBundle = providerTokenBundle
  }
}

public struct ProviderTokenBundle: Equatable, Sendable {
  /// 로그인 제공자 종류 (애플/구글)
  public let provider: AuthProvider
  /// 서버 검증에 사용되는 ID 토큰 (JWT)
  public let identityToken: String?
  /// 제공자 API 호출에 필요한 액세스 토큰
  public let accessToken: String?
  /// 제공자 내부의 사용자 고유 식별자
  public let userIdentifier: String
  /// 사용자 이메일 (동의/제공되는 경우)
  public let email: String?
  /// 사용자 이름 (동의/제공되는 경우)
  public let fullName: String?
  
  public init(
    provider: AuthProvider,
    identityToken: String?,
    accessToken: String?,
    userIdentifier: String,
    email: String? = nil,
    fullName: String? = nil
  ) {
    self.provider = provider
    self.identityToken = identityToken
    self.accessToken = accessToken
    self.userIdentifier = userIdentifier
    self.email = email
    self.fullName = fullName
  }
}

public enum AuthProvider: Equatable, Sendable {
  case apple
  case google
  
  var identifier: String {
    switch self {
    case .apple: return "apple"
    case .google: return "google"
    }
  }
}

// MARK: - Platform Auth Providers

public protocol PlatformAuthProviding {
  func signInWithApple(_ authorization: ASAuthorization, nonce: String) async throws -> ProviderTokenBundle
  func signInWithGoogle() async throws -> ProviderTokenBundle
}


public struct PlatformAuthProvider: PlatformAuthProviding, Sendable {
  public init() {}
  
  @MainActor
  public func signInWithApple(_ authorization: ASAuthorization, nonce: String) async throws -> ProviderTokenBundle {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      throw AuthClientError.invalidAppleCredential
    }
    _ = nonce
    guard let identityToken = appleIDCredential.identityToken,
          let tokenString = String(data: identityToken, encoding: .utf8) else {
      throw AuthClientError.missingIdentityToken
    }
    
    return ProviderTokenBundle(
      provider: .apple,
      identityToken: tokenString,
      accessToken: nil,
      userIdentifier: appleIDCredential.user,
      email: appleIDCredential.email,
      fullName: appleIDCredential.fullName?.formatted(.name(style: .medium))
    )
  }
  
  @MainActor
  public func signInWithGoogle() async throws -> ProviderTokenBundle {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      throw AuthClientError.providerUnavailable
    }
    
    let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    let user = signInResult.user
    return ProviderTokenBundle(
      provider: .google,
      identityToken: user.idToken?.tokenString,
      accessToken: user.accessToken.tokenString,
      userIdentifier: user.userID ?? "",
      email: user.profile?.email,
      fullName: user.profile?.name
    )
  }
}

// MARK: - Client

@DependencyClient
public struct AuthClient: Sendable {
  public var logout: @Sendable () async throws -> Void
  public var currentUser: @Sendable () async -> FirebaseUserSnapshot? = { nil }
  public var isAuthenticated: @Sendable () async -> Bool = { false }
  public var signInWithApple: @Sendable (_ authorization: ASAuthorization, _ nonce: String) async throws -> ServiceTokenBundle
  public var signInWithGoogle: @Sendable () async throws -> ServiceTokenBundle
  public var clearSession: @Sendable () async -> Void
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
  public static let previewValue = Self(
    logout: {},
    currentUser: { nil },
    isAuthenticated: { false },
    signInWithApple: {
      _, _ in .init(
        firebaseUser: .init(uid: "preview", email: "preview@apple.com", displayName: "Preview", photoURL: nil),
        providerTokenBundle: .init(
          provider: .apple,
          identityToken: nil,
          accessToken: nil,
          userIdentifier: "preview",
          email: "preview@apple.com",
          fullName: "Preview User"
        )
      )
    },
    signInWithGoogle: {
      .init(
        firebaseUser: .init(uid: "preview-google", email: "preview@google.com", displayName: "Preview G", photoURL: nil),
        providerTokenBundle: .init(
          provider: .google,
          identityToken: nil,
          accessToken: nil,
          userIdentifier: "preview-google",
          email: "preview@google.com",
          fullName: "Preview G"
        )
      )
    },
    clearSession: {}
  )
  
  public static let testValue = Self(
    logout: unimplemented("\(Self.self).logout"),
    currentUser: unimplemented("\(Self.self).currentUser", placeholder: nil),
    isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: false),
    signInWithApple: unimplemented("\(Self.self).signInWithApple"),
    signInWithGoogle: unimplemented("\(Self.self).signInWithGoogle"),
    clearSession: unimplemented("\(Self.self).clearSession")
  )
}

// MARK: - Live

private actor InMemoryAuthSession {
  private(set) var isAuthed: Bool = false
  private(set) var currentUser: User? = nil
  
  func login(with user: User? = nil) {
    isAuthed = true
    currentUser = user
  }
  
  func logout() {
    isAuthed = false
    currentUser = nil
  }
}

extension AuthClient: DependencyKey {
  public static let liveValue: AuthClient = {
    let session = InMemoryAuthSession()
    let provider = PlatformAuthProvider()
    let keychain = KeychainStorage()
    
    return Self(
      logout: {
        await session.logout()
        try? Auth.auth().signOut()
        try? clearStoredSession(in: keychain)
      },
      currentUser: {
        if let user = await session.currentUser {
          return FirebaseUserSnapshot(user: user)
        } else {
          return FirebaseUserSnapshot(user: Auth.auth().currentUser)
        }
      },
      isAuthenticated: {
        // InMemory 세션 먼저 체크
        if await session.isAuthed {
          return true
        }
        
        // Firebase currentUser 확인
        guard let user = Auth.auth().currentUser else {
          return false
        }
        printUser(user)
        // 3. 토큰 유효성 재검증 (네트워크 필요)
        do {
          try await user.reload()
          
          await session.login(with: user)
          
          return true
          
        } catch let error as NSError {
          
          // 네트워크 에러는 현재 상태 유지
          if error.domain == NSURLErrorDomain {
            print("⚠️ 네트워크 오류 - 현재 로그인 상태 유지")
            await session.login(with: nil)
            return true
          }
          
          // 토큰 만료 등 인증 에러는 로그아웃
          if let authError = AuthErrorCode(rawValue: error.code) {
            switch authError {
            case .userTokenExpired, .userNotFound, .invalidUserToken:
              try? Auth.auth().signOut()
              try? clearStoredSession(in: keychain)
              return false
            default:
              break
            }
          }
          
          // 기타 에러는 보수적으로 처리 (현재 상태 유지)
          await session.login()
          return true
        }
      },
      signInWithApple: { authorization, nonce in
        let providerTokenBundle = try await provider.signInWithApple(authorization, nonce: nonce)
        let serviceTokenBundle = try await signInWithFirebase(bundle: providerTokenBundle, rawNonce: nonce)
        await session.login()
        try store(bundle: providerTokenBundle, in: keychain)
        return serviceTokenBundle
      },
      signInWithGoogle: {
        let providerTokenBundle = try await provider.signInWithGoogle()
        let serviceTokenBundle = try await signInWithFirebase(bundle: providerTokenBundle)
        await session.login()
        try store(bundle: providerTokenBundle, in: keychain)
        return serviceTokenBundle
      },
      clearSession: {
        try? clearStoredSession(in: keychain)
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

// MARK: - Keychain helpers

private enum AuthKeychainKeys {
  static let provider = "auth.provider"
  static let userId = "auth.userId"
  static let idToken = "auth.idToken"
  static let accessToken = "auth.accessToken"
}

private func store(bundle: ProviderTokenBundle, in keychain: KeychainStorage) throws {
  try keychain.setString(bundle.provider.identifier, for: AuthKeychainKeys.provider)
  try keychain.setString(bundle.userIdentifier, for: AuthKeychainKeys.userId)
  
  if let idToken = bundle.identityToken {
    try keychain.setString(idToken, for: AuthKeychainKeys.idToken)
  } else {
    try? keychain.delete(AuthKeychainKeys.idToken)
  }
  
  if let accessToken = bundle.accessToken {
    try keychain.setString(accessToken, for: AuthKeychainKeys.accessToken)
  } else {
    try? keychain.delete(AuthKeychainKeys.accessToken)
  }
}

private func clearStoredSession(in keychain: KeychainStorage) throws {
  try? keychain.delete(AuthKeychainKeys.provider)
  try? keychain.delete(AuthKeychainKeys.userId)
  try? keychain.delete(AuthKeychainKeys.idToken)
  try? keychain.delete(AuthKeychainKeys.accessToken)
}

// MARK: - Firebase Auth linkage

private func signInWithFirebase(
  bundle: ProviderTokenBundle,
  rawNonce: String? = nil
) async throws -> ServiceTokenBundle {
  let credential = try bundle.createFirebaseCredential(rawNonce: rawNonce)
  let result = try await Auth.auth().signIn(with: credential)
  printUser(result.user)
  return ServiceTokenBundle(
    firebaseUser: FirebaseUserSnapshot(user: result.user),
    providerTokenBundle: bundle
  )
}

private extension ProviderTokenBundle {
  /// Firebase AuthCredential 생성
  func createFirebaseCredential(rawNonce: String? = nil) throws -> AuthCredential {
    switch provider {
    case .apple:
      guard let idToken = identityToken else {
        throw AuthClientError.missingIdentityToken
      }
      guard let rawNonce else {
        throw AuthClientError.invalidAppleCredential
      }
      
      var personNameComponents: PersonNameComponents? {
        guard let fullName else { return nil }
        return try? PersonNameComponents(fullName)
      }
      
      return OAuthProvider.appleCredential(
        withIDToken: idToken,
        rawNonce: rawNonce,
        fullName: personNameComponents
      )
      
    case .google:
      guard let idToken = identityToken,
            let accessToken = accessToken else {
        throw AuthClientError.missingIdentityToken
      }
      return GoogleAuthProvider.credential(
        withIDToken: idToken,
        accessToken: accessToken
      )
    }
  }
}

private func printUser(_ user: User) {
  print("=== Firebase User Info ===")
  print("UID: \(user.uid)")
  print("Email: \(user.email ?? "nil")")
  print("Display Name: \(user.displayName ?? "nil")")
  print("Photo URL: \(user.photoURL?.absoluteString ?? "nil")")
  print("Phone Number: \(user.phoneNumber ?? "nil")")
  print("Provider ID: \(user.providerID)")
  print("Is Anonymous: \(user.isAnonymous)")
  print("Is Email Verified: \(user.isEmailVerified)")
  print("Metadata:")
  print("  - Creation Date: \(user.metadata.creationDate ?? Date())")
  print("  - Last Sign In: \(user.metadata.lastSignInDate ?? Date())")
  print("Provider Data:")
  user.providerData.forEach { info in
    print("  - Provider: \(info.providerID)")
    print("    UID: \(info.uid)")
    print("    Email: \(info.email ?? "nil")")
    print("    Display Name: \(info.displayName ?? "nil")")
    print("    Photo URL: \(info.photoURL?.absoluteString ?? "nil")")
  }
  print("========================")
}
