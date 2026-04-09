import Foundation
import PromisoShared
import Security

private struct StoredServerSession: Codable, Equatable, Sendable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
  let deviceId: String
  let currentUser: AuthUserSnapshot
}

public actor ServerAuthSessionManager {
  public static let shared = ServerAuthSessionManager()

  private enum Constants {
    static let service = "com.promiso.server-auth"
    static let account = "primary-session"
  }

  private var cachedSession: StoredServerSession?

  public func currentUser() async -> AuthUserSnapshot? {
    (try? loadSession())?.currentUser
  }

  public func isAuthenticated() async -> Bool {
    (try? await currentAccessToken()) != nil
  }

  public func currentAccessToken() async throws -> String {
    guard let session = try loadSession() else {
      throw AuthClientError.invalidCredentials
    }

    if session.expiresAt > Date().addingTimeInterval(60) {
      return session.accessToken
    }

    return try await refreshSession(using: session)
  }

  public func saveSession(
    accessToken: String,
    refreshToken: String,
    expiresAt: Date,
    deviceId: String,
    currentUser: AuthUserSnapshot
  ) async throws {
    let session = StoredServerSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      deviceId: deviceId,
      currentUser: currentUser
    )
    try persist(session)
  }

  public func clear() async {
    cachedSession = nil
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Constants.service,
      kSecAttrAccount as String: Constants.account,
    ]
    SecItemDelete(query as CFDictionary)
  }

  public func logoutCurrentSession() async {
    do {
      let api = RustAPIClient()
      struct SuccessResponse: Decodable {
        let success: Bool
      }
      let _: SuccessResponse = try await api.post("/api/v1/auth/logout", body: EmptyBody())
    } catch {
      AppLogger.auth.error("Server logout failed: \(error.localizedDescription)")
    }

    await clear()
  }

  public func deleteCurrentAccount() async throws {
    do {
      let api = RustAPIClient()
      struct SuccessResponse: Decodable {
        let success: Bool
      }
      let _: SuccessResponse = try await api.delete("/api/v1/users/me")
      await clear()
    } catch let error as RustAPIError {
      if case let .serverError(code, _) = error, code == "failed-precondition" {
        throw AuthClientError.isGroupHost
      }
      throw mapRustError(error)
    } catch {
      throw AuthClientError.unknown
    }
  }

  private func refreshSession(using session: StoredServerSession) async throws -> String {
    let api = RustAPIClient(getAuthToken: nil)
    let request = RefreshRequest(
      refreshToken: session.refreshToken,
      deviceId: session.deviceId
    )
    let refreshed: RefreshResponse

    do {
      refreshed = try await api.post("/api/v1/auth/refresh", body: request)
    } catch {
      await clear()
      throw mapRustError(error)
    }

    let nextSession = StoredServerSession(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
      expiresAt: refreshed.expiresAt,
      deviceId: session.deviceId,
      currentUser: session.currentUser
    )
    try persist(nextSession)
    return nextSession.accessToken
  }

  private func loadSession() throws -> StoredServerSession? {
    if let cachedSession {
      return cachedSession
    }

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Constants.service,
      kSecAttrAccount as String: Constants.account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard let data = item as? Data else { return nil }
      let session = try JSONDecoder().decode(StoredServerSession.self, from: data)
      cachedSession = session
      return session
    case errSecItemNotFound:
      return nil
    default:
      throw AuthClientError.unknown
    }
  }

  private func persist(_ session: StoredServerSession) throws {
    let data = try JSONEncoder().encode(session)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Constants.service,
      kSecAttrAccount as String: Constants.account,
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecItemNotFound {
      var insertQuery = query
      insertQuery[kSecValueData as String] = data
      insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw AuthClientError.unknown
      }
    } else if updateStatus != errSecSuccess {
      throw AuthClientError.unknown
    }

    cachedSession = session
  }
}

private struct RefreshRequest: Encodable {
  let refreshToken: String
  let deviceId: String
}

private struct RefreshResponse: Decodable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
}

private struct EmptyBody: Encodable {}

private func mapRustError(_ error: Error) -> AuthClientError {
  guard let rustError = error as? RustAPIError else {
    return .unknown
  }

  switch rustError {
  case .httpError, .invalidResponse, .noData:
    return .network
  case let .serverError(code, _):
    switch code {
    case "unauthenticated":
      return .invalidCredentials
    case "failed-precondition":
      return .isGroupHost
    case "already-exists":
      return .alreadyExists
    default:
      return .unknown
    }
  }
}
