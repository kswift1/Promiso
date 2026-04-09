import AuthenticationServices
import ComposableArchitecture
import Foundation
import GoogleSignIn
import PromisoShared
import UIKit

// MARK: - Widget Token Rust Response DTO

private struct RustWidgetTokenResponse: Decodable {
  let widgetToken: String
  let expiresAt: Int64  // epoch seconds
}

private struct RustAuthUserResponse: Decodable {
  let userId: String
  let email: String?
  let provider: String
  let displayName: String?
  let profileImageUrl: String?
}

private struct RustAuthLoginResponse: Decodable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
  let user: RustAuthUserResponse
  let hasProfile: Bool
}

private struct AppleAuthRequest: Encodable {
  let identityToken: String
  let userIdentifier: String
  let email: String?
  let fullName: String?
  let rawNonce: String
  let authorizationCode: String?
  let deviceId: String
  let appVersion: String?
}

private struct GoogleAuthRequest: Encodable {
  let idToken: String
  let accessToken: String?
  let userIdentifier: String
  let email: String?
  let fullName: String?
  let profileImageUrl: String?
  let deviceId: String
  let appVersion: String?
}

// MARK: - Error

public enum AuthClientError: Error, Equatable {
  case invalidCredentials
  case alreadyExists
  case network
  case invalidAppleCredential
  case missingIdentityToken
  case providerUnavailable
  case isGroupHost
  case unknown
}

// MARK: - Models

/// 로그인 사용자를 모킹 가능하게 담는 스냅샷
public struct AuthUserSnapshot: Codable, Equatable, Sendable {
  public let uid: String
  public let email: String?
  public let displayName: String?
  public let photoURL: URL?
  public let creationDate: Date?
  public let lastSignInDate: Date?
  public let providerId: String?
  public let providerUid: String?
  public let providerType: String?
  
  public init(
    uid: String,
    email: String?,
    displayName: String?,
    photoURL: URL?,
    creationDate: Date? = nil,
    lastSignInDate: Date? = nil,
    providerId: String? = nil,
    providerUid: String? = nil,
    providerType: String? = nil
  ) {
    self.uid = uid
    self.email = email
    self.displayName = displayName
    self.photoURL = photoURL
    self.creationDate = creationDate
    self.lastSignInDate = lastSignInDate
    self.providerId = providerId
    self.providerUid = providerUid
    self.providerType = providerType
  }
}

public struct ServiceTokenBundle: Equatable, Sendable {
  /// 로그인 사용자 스냅샷
  public let authUser: AuthUserSnapshot?
  /// 제공 토큰 번들
  public let providerTokenBundle: ProviderTokenBundle
  /// 신규 사용자 여부 (회원가입 시 true)
  public let isNewUser: Bool
  /// 프로필 이미지 URL (Provider에서 제공, Auth User에 없을 경우 사용)
  public var profileImageURL: URL? {
    // Auth User의 photoURL 우선, 없으면 Provider의 profileImageURL 사용
    authUser?.photoURL ?? providerTokenBundle.profileImageURL
  }

  public init(
    authUser: AuthUserSnapshot?,
    providerTokenBundle: ProviderTokenBundle,
    isNewUser: Bool = false
  ) {
    self.authUser = authUser
    self.providerTokenBundle = providerTokenBundle
    self.isNewUser = isNewUser
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
  /// 프로필 이미지 URL (Google 로그인 시 제공)
  public let profileImageURL: URL?
  /// Apple authorization code (필요 시 서버 교차 검증에 사용)
  public let authorizationCode: String?

  public init(
    provider: AuthProvider,
    identityToken: String?,
    accessToken: String?,
    userIdentifier: String,
    email: String? = nil,
    fullName: String? = nil,
    profileImageURL: URL? = nil,
    authorizationCode: String? = nil
  ) {
    self.provider = provider
    self.identityToken = identityToken
    self.accessToken = accessToken
    self.userIdentifier = userIdentifier
    self.email = email
    self.fullName = fullName
    self.profileImageURL = profileImageURL
    self.authorizationCode = authorizationCode
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

  var providerId: String {
    switch self {
    case .apple: return "apple.com"
    case .google: return "google.com"
    }
  }
}

// MARK: - Provider Identifier Helpers

public extension String {
  /// "google.com" -> "google", "apple.com" -> "apple" 등 간단한 매핑
  var providerTypeIdentifier: String {
    if self.contains("google") { return "google" }
    if self.contains("apple") { return "apple" }
    return self
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
      fullName: appleIDCredential.fullName?.formatted(.name(style: .medium)),
      authorizationCode: appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
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
    // Google 프로필 이미지 URL (200px 크기)
    let profileImageURL = user.profile?.imageURL(withDimension: 200)

    return ProviderTokenBundle(
      provider: .google,
      identityToken: user.idToken?.tokenString,
      accessToken: user.accessToken.tokenString,
      userIdentifier: user.userID ?? "",
      email: user.profile?.email,
      fullName: user.profile?.name,
      profileImageURL: profileImageURL
    )
  }
}

// MARK: - Client
public struct AuthClient: Sendable {
  private let session = InMemoryAuthSession()
  private let provider = PlatformAuthProvider()

  public var logout: @Sendable () async throws -> Void
  public var currentUser: @Sendable () async -> AuthUserSnapshot? = { nil }
  public var isAuthenticated: @Sendable () async -> Bool = { false }
  public var signInWithApple: @Sendable (_ authorization: ASAuthorization, _ nonce: String) async throws -> ServiceTokenBundle
  public var signInWithGoogle: @Sendable () async throws -> ServiceTokenBundle
  public var clearSession: @Sendable () async -> Void

  // MARK: - Widget Token Management

  /// Widget/LiveActivity Extension용 Firebase ID Token을 App Group에 저장
  /// - 로그인 후, 앱 활성화 시 호출 필요
  public var refreshWidgetAuthToken: @Sendable () async -> Void

  /// App Group에 저장된 Widget 토큰 삭제 (로그아웃 시)
  public var clearWidgetAuthToken: @Sendable () -> Void

  /// Widget 전용 Long-lived Token 발급 요청 (30일 유효)
  /// - 로그인 후, 앱 활성화 시, 토큰 만료 7일 전에 호출
  public var requestWidgetToken: @Sendable () async -> Void

  // MARK: - Account Management

  /// 회원 탈퇴
  /// - 그룹 호스트인 경우 먼저 호스트 양도 필요
  /// - 성공 시 Firebase Auth 계정 및 모든 데이터 삭제
  public var deleteAccount: @Sendable () async throws -> Void
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
  public static let previewValue = Self(
    logout: {},
    currentUser: { nil },
    isAuthenticated: { false },
    signInWithApple: {
      _, _ in .init(
        authUser: .init(uid: "preview", email: "preview@apple.com", displayName: "Preview", photoURL: nil),
        providerTokenBundle: .init(
          provider: .apple,
          identityToken: nil,
          accessToken: nil,
          userIdentifier: "preview",
          email: "preview@apple.com",
          fullName: "Preview User"
        ),
        isNewUser: false
      )
    },
    signInWithGoogle: {
      .init(
        authUser: .init(uid: "preview-google", email: "preview@google.com", displayName: "Preview G", photoURL: nil),
        providerTokenBundle: .init(
          provider: .google,
          identityToken: nil,
          accessToken: nil,
          userIdentifier: "preview-google",
          email: "preview@google.com",
          fullName: "Preview G"
        ),
        isNewUser: false
      )
    },
    clearSession: {},
    refreshWidgetAuthToken: {},
    clearWidgetAuthToken: {},
    requestWidgetToken: {},
    deleteAccount: {}
  )

  public static let testValue = Self(
    logout: unimplemented("\(Self.self).logout"),
    currentUser: unimplemented("\(Self.self).currentUser", placeholder: nil),
    isAuthenticated: unimplemented("\(Self.self).isAuthenticated", placeholder: false),
    signInWithApple: unimplemented("\(Self.self).signInWithApple"),
    signInWithGoogle: unimplemented("\(Self.self).signInWithGoogle"),
    clearSession: unimplemented("\(Self.self).clearSession"),
    refreshWidgetAuthToken: unimplemented("\(Self.self).refreshWidgetAuthToken"),
    clearWidgetAuthToken: unimplemented("\(Self.self).clearWidgetAuthToken"),
    requestWidgetToken: unimplemented("\(Self.self).requestWidgetToken"),
    deleteAccount: unimplemented("\(Self.self).deleteAccount")
  )
}

// MARK: - Live

actor InMemoryAuthSession {
  static let shared: InMemoryAuthSession = .init()
  private(set) var isAuthed: Bool = false
  private(set) var currentUser: AuthUserSnapshot? = nil

  func login(with user: AuthUserSnapshot? = nil) {
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
    let session = InMemoryAuthSession.shared
    let provider = PlatformAuthProvider()

    return AuthClient(
      logout: {
        await ServerAuthSessionManager.shared.logoutCurrentSession()
        await session.logout()
        WidgetAuthTokenStore.clear()
        WidgetTokenStore.clear()
        GIDSignIn.sharedInstance.signOut()
      },
      currentUser: {
        if let user = await session.currentUser {
          return user
        }
        let restoredUser = await ServerAuthSessionManager.shared.currentUser()
        if let restoredUser {
          await session.login(with: restoredUser)
        }
        return restoredUser
      },
      isAuthenticated: {
        let isAuthenticated = await ServerAuthSessionManager.shared.isAuthenticated()
        if isAuthenticated, let restoredUser = await ServerAuthSessionManager.shared.currentUser() {
          await session.login(with: restoredUser)
        } else if !isAuthenticated {
          await session.logout()
        }
        return isAuthenticated
      },
      signInWithApple: { authorization, nonce in
        let providerTokenBundle = try await provider.signInWithApple(authorization, nonce: nonce)

        guard let identityToken = providerTokenBundle.identityToken else {
          throw AuthClientError.missingIdentityToken
        }

        let deviceId = await currentDeviceId()
        let response: RustAuthLoginResponse = try await authClientRequest(
          path: "/api/v1/auth/apple",
          body: AppleAuthRequest(
            identityToken: identityToken,
            userIdentifier: providerTokenBundle.userIdentifier,
            email: providerTokenBundle.email,
            fullName: providerTokenBundle.fullName,
            rawNonce: nonce,
            authorizationCode: providerTokenBundle.authorizationCode,
            deviceId: deviceId,
            appVersion: appVersion()
          )
        )
        let userSnapshot = makeServerUserSnapshot(response.user, providerTokenBundle: providerTokenBundle)
        try await ServerAuthSessionManager.shared.saveSession(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          expiresAt: response.expiresAt,
          deviceId: deviceId,
          currentUser: userSnapshot
        )
        await session.login(with: userSnapshot)

        return ServiceTokenBundle(
          authUser: userSnapshot,
          providerTokenBundle: providerTokenBundle,
          isNewUser: !response.hasProfile
        )
      },
      signInWithGoogle: {
        let providerTokenBundle = try await provider.signInWithGoogle()

        guard let idToken = providerTokenBundle.identityToken else {
          throw AuthClientError.invalidCredentials
        }
        let deviceId = await currentDeviceId()
        let response: RustAuthLoginResponse = try await authClientRequest(
          path: "/api/v1/auth/google",
          body: GoogleAuthRequest(
            idToken: idToken,
            accessToken: providerTokenBundle.accessToken,
            userIdentifier: providerTokenBundle.userIdentifier,
            email: providerTokenBundle.email,
            fullName: providerTokenBundle.fullName,
            profileImageUrl: providerTokenBundle.profileImageURL?.absoluteString,
            deviceId: deviceId,
            appVersion: appVersion()
          )
        )
        let userSnapshot = makeServerUserSnapshot(response.user, providerTokenBundle: providerTokenBundle)
        try await ServerAuthSessionManager.shared.saveSession(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          expiresAt: response.expiresAt,
          deviceId: deviceId,
          currentUser: userSnapshot
        )
        await session.login(with: userSnapshot)

        return ServiceTokenBundle(
          authUser: userSnapshot,
          providerTokenBundle: providerTokenBundle,
          isNewUser: !response.hasProfile
        )
      },
      clearSession: {
        await session.logout()
        await ServerAuthSessionManager.shared.clear()
      },
      refreshWidgetAuthToken: {
        guard await ServerAuthSessionManager.shared.currentUser() != nil else {
          WidgetAuthTokenStore.clear()
          return
        }

        do {
          let token = try await ServerAuthSessionManager.shared.currentAccessToken()
          WidgetAuthTokenStore.save(token: token)
        } catch {
          AppLogger.auth.error("Widget auth token 갱신 실패: \(error.localizedDescription)")
        }
      },
      clearWidgetAuthToken: {
        WidgetAuthTokenStore.clear()
        WidgetTokenStore.clear()
      },
      requestWidgetToken: {
        guard await ServerAuthSessionManager.shared.isAuthenticated() else {
          return
        }

        let deviceId = await MainActor.run {
          UIDevice.current.identifierForVendor?.uuidString
        } ?? UUID().uuidString
        WidgetTokenStore.saveDeviceId(deviceId)

        guard !WidgetTokenStore.isTokenValid() else {
          return
        }

        do {
          let rustClient = RustAPIClient()

          struct WidgetTokenBody: Encodable { let deviceId: String }
          let response: RustWidgetTokenResponse = try await rustClient.post(
            "/api/v1/widget/token",
            body: WidgetTokenBody(deviceId: deviceId)
          )

          WidgetTokenStore.save(
            token: response.widgetToken,
            expiresAt: TimeInterval(response.expiresAt),
            deviceId: deviceId
          )
          AppLogger.auth.info("Widget token 발급 완료 (Rust)")
        } catch {
          AppLogger.auth.error("Widget long-lived token 발급 실패 (Rust): \(error.localizedDescription)")
        }
      },
      deleteAccount: {
        try await ServerAuthSessionManager.shared.deleteCurrentAccount()
        await session.logout()
        WidgetAuthTokenStore.clear()
        WidgetTokenStore.clear()
      }
    )
  }()
}

// MARK: - Widget Auth Token Store (Server Access Token Fallback)

/// Widget/LiveActivity Extension과 공유하는 Auth Token 저장소
private enum WidgetAuthTokenStore {
  /// Fallback 토큰 유효 시간
  private static let tokenValiditySeconds: TimeInterval = 3600

  static func save(token: String) {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    let expiry = Date().addingTimeInterval(tokenValiditySeconds)

    defaults.set(token, forKey: LiveActivityIntentKey.authTokenKey)
    defaults.set(expiry, forKey: LiveActivityIntentKey.authTokenExpiryKey)

    // APNs 환경도 함께 저장 (Widget에서 백엔드 호출 시 사용)
    let apnsEnvironment = APNsEnvironment.current.apiValue
    defaults.set(apnsEnvironment, forKey: LiveActivityIntentKey.apnsEnvironmentKey)
    defaults.set(RustAPIClient.defaultBaseURL.absoluteString, forKey: LiveActivityIntentKey.rustApiBaseUrlKey)
  }

  static func clear() {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    defaults.removeObject(forKey: LiveActivityIntentKey.authTokenKey)
    defaults.removeObject(forKey: LiveActivityIntentKey.authTokenExpiryKey)
    defaults.removeObject(forKey: LiveActivityIntentKey.apnsEnvironmentKey)
  }
}

// MARK: - Widget Token Store (Long-lived Token - 30일)

/// Widget 전용 Long-lived Token 저장소
private enum WidgetTokenStore {
  /// 토큰 갱신 권장 기간 (만료 7일 전)
  private static let refreshThresholdDays: TimeInterval = 7 * 24 * 60 * 60

  /// Widget Token 저장
  static func save(token: String, expiresAt: TimeInterval, deviceId: String) {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    let expiryDate = Date(timeIntervalSince1970: expiresAt)

    defaults.set(token, forKey: LiveActivityIntentKey.widgetTokenKey)
    defaults.set(expiryDate, forKey: LiveActivityIntentKey.widgetTokenExpiryKey)
    defaults.set(deviceId, forKey: LiveActivityIntentKey.widgetDeviceIdKey)
  }

  static func saveDeviceId(_ deviceId: String) {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }
    defaults.set(deviceId, forKey: LiveActivityIntentKey.widgetDeviceIdKey)
  }

  /// Widget Token이 유효한지 확인 (만료 7일 전까지 유효)
  static func isTokenValid() -> Bool {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName),
          let _ = defaults.string(forKey: LiveActivityIntentKey.widgetTokenKey),
          let expiry = defaults.object(forKey: LiveActivityIntentKey.widgetTokenExpiryKey) as? Date else {
      return false
    }

    // 만료 7일 전까지는 유효로 간주
    let refreshThreshold = expiry.addingTimeInterval(-refreshThresholdDays)
    return Date() < refreshThreshold
  }

  /// Widget Token 삭제
  static func clear() {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    defaults.removeObject(forKey: LiveActivityIntentKey.widgetTokenKey)
    defaults.removeObject(forKey: LiveActivityIntentKey.widgetTokenExpiryKey)
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}

private func currentDeviceId() async -> String {
  await MainActor.run {
    UIDevice.current.identifierForVendor?.uuidString
  } ?? UUID().uuidString
}

private func appVersion() -> String? {
  Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
}

private func makeServerUserSnapshot(
  _ user: RustAuthUserResponse,
  providerTokenBundle: ProviderTokenBundle
) -> AuthUserSnapshot {
  AuthUserSnapshot(
    uid: user.userId,
    email: user.email,
    displayName: user.displayName,
    photoURL: user.profileImageUrl.flatMap(URL.init(string:)),
    providerId: providerTokenBundle.provider.providerId,
    providerUid: providerTokenBundle.userIdentifier,
    providerType: providerTokenBundle.provider.identifier
  )
}

private func authClientRequest<B: Encodable, T: Decodable>(
  path: String,
  body: B
) async throws -> T {
  do {
    return try await RustAPIClient(getAuthToken: nil).post(path, body: body)
  } catch {
    throw mapAuthClientError(error)
  }
}

private func mapAuthClientError(_ error: Error) -> AuthClientError {
  guard let rustError = error as? RustAPIError else {
    return .unknown
  }

  switch rustError {
  case .invalidResponse, .httpError, .noData:
    return .network
  case let .serverError(code, _):
    switch code {
    case "unauthenticated":
      return .invalidCredentials
    case "already-exists":
      return .alreadyExists
    case "failed-precondition":
      return .isGroupHost
    default:
      return .unknown
    }
  }
}
