import ComposableArchitecture
import Foundation
import Clarity

// MARK: - Client

public struct ClarityClient: Sendable {
  public struct UserInfo: Sendable {
    public let userId: String
    public let nickname: String
    public let email: String
    public let provider: String
    public let groupCount: Int
    public let createdAt: Date

    public init(userId: String, nickname: String, email: String, provider: String, groupCount: Int, createdAt: Date) {
      self.userId = userId
      self.nickname = nickname
      self.email = email
      self.provider = provider
      self.groupCount = groupCount
      self.createdAt = createdAt
    }
  }

  /// Clarity에 유저 정보 등록
  public var setUser: @Sendable (UserInfo) -> Void

  /// Clarity에서 유저 정보 제거
  public var clearUser: @Sendable () -> Void
}

// MARK: - Test / Preview

extension ClarityClient: TestDependencyKey {
  public static let previewValue = Self(
    setUser: { _ in },
    clearUser: { }
  )

  public static let testValue = Self(
    setUser: unimplemented("\(Self.self).setUser"),
    clearUser: unimplemented("\(Self.self).clearUser")
  )
}

// MARK: - Live

extension ClarityClient: DependencyKey {
  public static let liveValue = Self(
    setUser: { userInfo in
      let formatter = ISO8601DateFormatter()
      ClaritySDK.setCustomUserId(userInfo.userId)
      ClaritySDK.setCustomTag(key: "nickname", value: userInfo.nickname)
      ClaritySDK.setCustomTag(key: "email", value: userInfo.email)
      ClaritySDK.setCustomTag(key: "provider", value: userInfo.provider)
      ClaritySDK.setCustomTag(key: "groupCount", value: String(userInfo.groupCount))
      ClaritySDK.setCustomTag(key: "createdAt", value: formatter.string(from: userInfo.createdAt))
    },
    clearUser: {
      ClaritySDK.setCustomUserId("")
      ClaritySDK.setCustomTag(key: "nickname", value: "")
      ClaritySDK.setCustomTag(key: "email", value: "")
      ClaritySDK.setCustomTag(key: "provider", value: "")
      ClaritySDK.setCustomTag(key: "groupCount", value: "")
      ClaritySDK.setCustomTag(key: "createdAt", value: "")
    }
  )
}

// MARK: - Dependency Registration

public extension DependencyValues {
  var clarityClient: ClarityClient {
    get { self[ClarityClient.self] }
    set { self[ClarityClient.self] = newValue }
  }
}
