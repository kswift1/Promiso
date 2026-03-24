import ExternalDependency
import Foundation

// MARK: - Client

public struct CrashlyticsClient: Sendable {
  public struct UserInfo: Sendable {
    public let userId: String
    public let nickname: String
    public let provider: String
    public let groupCount: Int

    public init(userId: String, nickname: String, provider: String, groupCount: Int) {
      self.userId = userId
      self.nickname = nickname
      self.provider = provider
      self.groupCount = groupCount
    }
  }

  /// Crashlytics에 유저 정보 등록
  public var setUser: @Sendable (UserInfo) -> Void

  /// Crashlytics에서 유저 정보 제거
  public var clearUser: @Sendable () -> Void
}

// MARK: - Test / Preview

extension CrashlyticsClient: TestDependencyKey {
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

extension CrashlyticsClient: DependencyKey {
  public static let liveValue = Self(
    setUser: { userInfo in
      let crashlytics = Crashlytics.crashlytics()
      crashlytics.setUserID(userInfo.userId)
      crashlytics.setCustomValue(userInfo.nickname, forKey: "nickname")
      crashlytics.setCustomValue(userInfo.provider, forKey: "provider")
      crashlytics.setCustomValue(userInfo.groupCount, forKey: "groupCount")
    },
    clearUser: {
      let crashlytics = Crashlytics.crashlytics()
      crashlytics.setUserID("")
      crashlytics.setCustomValue("", forKey: "nickname")
      crashlytics.setCustomValue("", forKey: "provider")
      crashlytics.setCustomValue(0, forKey: "groupCount")
    }
  )
}

// MARK: - Dependency Registration

public extension DependencyValues {
  var crashlyticsClient: CrashlyticsClient {
    get { self[CrashlyticsClient.self] }
    set { self[CrashlyticsClient.self] = newValue }
  }
}
