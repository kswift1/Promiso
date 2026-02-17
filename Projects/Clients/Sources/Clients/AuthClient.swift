import AuthenticationServices
import ComposableArchitecture
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import Foundation
import GoogleSignIn
import GoogleSignInSwift
import PromisoShared
import UIKit

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

/// Firebase User를 모킹 가능하게 담는 스냅샷
public struct FirebaseUserSnapshot: Equatable, Sendable {
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
  
  public init?(user: FirebaseAuth.User?) {
    guard let user else { return nil }
    let providerInfo = user.providerData.first
    self.init(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      creationDate: user.metadata.creationDate,
      lastSignInDate: user.metadata.lastSignInDate,
      providerId: providerInfo?.providerID,
      providerUid: providerInfo?.uid,
      providerType: providerInfo?.providerID.providerTypeIdentifier
    )
  }
}

public struct ServiceTokenBundle: Equatable, Sendable {
  /// Firebase User 스냅샷
  public let firebaseUser: FirebaseUserSnapshot?
  /// 제공 토큰 번들
  public let providerTokenBundle: ProviderTokenBundle
  /// 신규 사용자 여부 (회원가입 시 true)
  public let isNewUser: Bool
  /// 프로필 이미지 URL (Provider에서 제공, Firebase에 없을 경우 사용)
  public var profileImageURL: URL? {
    // Firebase User의 photoURL 우선, 없으면 Provider의 profileImageURL 사용
    firebaseUser?.photoURL ?? providerTokenBundle.profileImageURL
  }

  public init(
    firebaseUser: FirebaseUserSnapshot?,
    providerTokenBundle: ProviderTokenBundle,
    isNewUser: Bool = false
  ) {
    self.firebaseUser = firebaseUser
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

  public init(
    provider: AuthProvider,
    identityToken: String?,
    accessToken: String?,
    userIdentifier: String,
    email: String? = nil,
    fullName: String? = nil,
    profileImageURL: URL? = nil
  ) {
    self.provider = provider
    self.identityToken = identityToken
    self.accessToken = accessToken
    self.userIdentifier = userIdentifier
    self.email = email
    self.fullName = fullName
    self.profileImageURL = profileImageURL
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
  public var currentUser: @Sendable () async -> FirebaseUserSnapshot? = { nil }
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
        firebaseUser: .init(uid: "preview", email: "preview@apple.com", displayName: "Preview", photoURL: nil),
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
        firebaseUser: .init(uid: "preview-google", email: "preview@google.com", displayName: "Preview G", photoURL: nil),
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

// MARK: - Firebase 상수

private enum FirebaseConstants {
  static let region = "asia-northeast3"
  static let deleteUserFunction = "deleteUser"
  static let checkAppleCredentialFunction = "checkAppleCredential"
  static let generateWidgetTokenFunction = "generateWidgetToken"
}

extension AuthClient: DependencyKey {

  public static let liveValue: AuthClient = {
    let session = InMemoryAuthSession.shared
    let provider = PlatformAuthProvider()

    return AuthClient(
      logout: {
        await session.logout()
        try? Auth.auth().signOut()
      },
      currentUser: {
        if let user = await session.currentUser {
          return FirebaseUserSnapshot(user: user)
        } else {
          return FirebaseUserSnapshot(user: Auth.auth().currentUser)
        }
      },
      isAuthenticated: {
        if await session.isAuthed { return true }

        guard let user = Auth.auth().currentUser else { return false }

        do {
          try await user.reload()
          await session.login(with: user)
          return true
        } catch let error as NSError {
          if error.domain == NSURLErrorDomain {
            await session.login(with: nil)
            return true
          }

          if let authError = AuthErrorCode(rawValue: error.code) {
            switch authError {
            case .userTokenExpired, .userNotFound, .invalidUserToken:
              try? Auth.auth().signOut()
              return false
            default:
              break
            }
          }

          await session.login()
          return true
        }
      },
      signInWithApple: { authorization, nonce in
        let providerTokenBundle = try await provider.signInWithApple(authorization, nonce: nonce)

        // Firebase 인증
        guard let idTokenData = providerTokenBundle.identityToken else {
          throw AuthClientError.missingIdentityToken
        }
        let credential = OAuthProvider.appleCredential(
          withIDToken: idTokenData,
          rawNonce: nonce,
          fullName: nil
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        await session.login(with: authResult.user)

        // 신규 사용자 여부 확인
        let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

        return ServiceTokenBundle(
          firebaseUser: FirebaseUserSnapshot(user: authResult.user),
          providerTokenBundle: providerTokenBundle,
          isNewUser: isNewUser
        )
      },
      signInWithGoogle: {
        let providerTokenBundle = try await provider.signInWithGoogle()

        // Firebase 인증
        guard let idToken = providerTokenBundle.identityToken,
              let accessToken = providerTokenBundle.accessToken else {
          throw AuthClientError.invalidCredentials
        }

        let credential = GoogleAuthProvider.credential(
          withIDToken: idToken,
          accessToken: accessToken
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        await session.login(with: authResult.user)

        // 신규 사용자 여부 확인
        let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

        return ServiceTokenBundle(
          firebaseUser: FirebaseUserSnapshot(user: authResult.user),
          providerTokenBundle: providerTokenBundle,
          isNewUser: isNewUser
        )
      },
      clearSession: {
        await session.logout()
      },
      refreshWidgetAuthToken: {
        // Widget/LiveActivity Extension용 Firebase ID Token 갱신 및 저장
        guard let user = Auth.auth().currentUser else {
          // 로그인 안 됨 - 토큰 삭제
          WidgetAuthTokenStore.clear()
          return
        }

        do {
          let token = try await user.getIDToken()
          WidgetAuthTokenStore.save(token: token, userId: user.uid)
        } catch {
          #if DEBUG
          print("[AuthClient] Widget 토큰 갱신 실패: \(error)")
          #endif
        }
      },
      clearWidgetAuthToken: {
        WidgetAuthTokenStore.clear()
        WidgetTokenStore.clear()
      },
      requestWidgetToken: {
        // Widget 전용 Long-lived Token 발급 요청
        guard Auth.auth().currentUser != nil else {
          #if DEBUG
          print("[AuthClient] Widget Token 발급 실패: 로그인 안 됨")
          #endif
          return
        }

        // 이미 유효한 토큰이 있으면 스킵 (만료 7일 전까지)
        if WidgetTokenStore.isTokenValid() {
          #if DEBUG
          print("[AuthClient] Widget Token 유효함 - 갱신 스킵")
          #endif
          return
        }

        do {
          let functions = DefaultFunctionsProvider().functions
          let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

          let result = try await functions
            .httpsCallable(FirebaseConstants.generateWidgetTokenFunction)
            .call(["deviceId": deviceId])

          guard let data = result.data as? [String: Any],
                let widgetToken = data["widgetToken"] as? String,
                let expiresAt = data["expiresAt"] as? Int else {
            #if DEBUG
            print("[AuthClient] Widget Token 응답 파싱 실패")
            #endif
            return
          }

          // App Group에 저장
          WidgetTokenStore.save(token: widgetToken, expiresAt: TimeInterval(expiresAt))

          #if DEBUG
          print("[AuthClient] Widget Token 발급 완료 (만료: \(Date(timeIntervalSince1970: TimeInterval(expiresAt))))")
          #endif
        } catch {
          #if DEBUG
          print("[AuthClient] Widget Token 발급 실패: \(error)")
          #endif
        }
      },
      deleteAccount: {
        // 회원 탈퇴 - Firebase Function 호출
        guard let currentUser = Auth.auth().currentUser else {
          throw AuthClientError.invalidCredentials
        }

        // 토큰 갱신 (만료된 토큰으로 인한 UNAUTHENTICATED 방지)
        _ = try await currentUser.getIDToken(forcingRefresh: true)

        let functions = DefaultFunctionsProvider().functions

        do {
          _ = try await functions
            .httpsCallable(FirebaseConstants.deleteUserFunction)
            .call([:])

          // 로컬 세션 정리
          await session.logout()
          WidgetAuthTokenStore.clear()
          WidgetTokenStore.clear()
        } catch let error as NSError {
          #if DEBUG
          print("[AuthClient] 회원 탈퇴 실패: \(error)")
          print("[AuthClient] Error domain: \(error.domain), code: \(error.code)")
          print("[AuthClient] FunctionsErrorDomain: \(FunctionsErrorDomain)")
          print("[AuthClient] failedPrecondition rawValue: \(FunctionsErrorCode.failedPrecondition.rawValue)")
          #endif

          // Firebase Functions 에러 코드 확인
          if error.domain == FunctionsErrorDomain {
            // "failed-precondition" = 그룹 호스트인 경우
            if error.code == FunctionsErrorCode.failedPrecondition.rawValue {
              throw AuthClientError.isGroupHost
            }
          }
          throw AuthClientError.unknown
        }
      }
    )
  }()
}

// MARK: - Widget Auth Token Store (Firebase ID Token - Legacy)

/// Widget/LiveActivity Extension과 공유하는 Auth Token 저장소
private enum WidgetAuthTokenStore {
  /// Token 유효 시간 (Firebase ID Token은 1시간)
  private static let tokenValiditySeconds: TimeInterval = 3600

  static func save(token: String, userId: String) {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    let expiry = Date().addingTimeInterval(tokenValiditySeconds)

    defaults.set(token, forKey: LiveActivityIntentKey.authTokenKey)
    defaults.set(expiry, forKey: LiveActivityIntentKey.authTokenExpiryKey)

    // APNs 환경도 함께 저장 (Widget에서 백엔드 호출 시 사용)
    let apnsEnvironment = APNsEnvironment.current.apiValue
    defaults.set(apnsEnvironment, forKey: LiveActivityIntentKey.apnsEnvironmentKey)

    // Firebase Project ID 저장 (Widget에서 HTTP 호출용)
    if let projectId = FirebaseApp.app()?.options.projectID {
      defaults.set(projectId, forKey: LiveActivityIntentKey.firebaseProjectIdKey)
    }

    #if DEBUG
    print("[WidgetAuthTokenStore] 토큰 저장 완료 (만료: \(expiry), APNs: \(apnsEnvironment))")
    #endif
  }

  static func clear() {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    defaults.removeObject(forKey: LiveActivityIntentKey.authTokenKey)
    defaults.removeObject(forKey: LiveActivityIntentKey.authTokenExpiryKey)
    defaults.removeObject(forKey: LiveActivityIntentKey.apnsEnvironmentKey)

    #if DEBUG
    print("[WidgetAuthTokenStore] 토큰 삭제 완료")
    #endif
  }
}

// MARK: - Widget Token Store (Long-lived Token - 30일)

/// Widget 전용 Long-lived Token 저장소
private enum WidgetTokenStore {
  /// 토큰 갱신 권장 기간 (만료 7일 전)
  private static let refreshThresholdDays: TimeInterval = 7 * 24 * 60 * 60

  /// Widget Token 저장
  static func save(token: String, expiresAt: TimeInterval) {
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    let expiryDate = Date(timeIntervalSince1970: expiresAt)

    defaults.set(token, forKey: LiveActivityIntentKey.widgetTokenKey)
    defaults.set(expiryDate, forKey: LiveActivityIntentKey.widgetTokenExpiryKey)

    #if DEBUG
    print("[WidgetTokenStore] Widget Token 저장 완료 (만료: \(expiryDate))")
    #endif
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

    #if DEBUG
    print("[WidgetTokenStore] Widget Token 삭제 완료")
    #endif
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
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
