import ComposableArchitecture
import Foundation
import Clarity

// MARK: - Client

public struct ClarityClient: Sendable {
  /// Clarity에 유저 정보 등록
  public var setUser: @Sendable (String, String) -> Void

  /// Clarity에서 유저 정보 제거
  public var clearUser: @Sendable () -> Void
}

// MARK: - Test / Preview

extension ClarityClient: TestDependencyKey {
  public static let previewValue = Self(
    setUser: { _, _ in },
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
    setUser: { userId, nickname in
      ClaritySDK.setCustomUserId(userId)
      ClaritySDK.setCustomTag(key: "nickname", value: nickname)
    },
    clearUser: {
      ClaritySDK.setCustomUserId("")
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
