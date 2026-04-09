import ComposableArchitecture
import Foundation

public enum FeatureDomain: String, CaseIterable, Sendable {
  case users
  case groups
  case promises
  case notifications
  case subscription
  case settings
  case briefing
  case widget
  case emoji
  case places
}

@DependencyClient
public struct FeatureFlagsClient: Sendable {
  public var useRustAPI: @Sendable (_ domain: FeatureDomain) -> Bool = { _ in false }
}

extension FeatureFlagsClient: TestDependencyKey {
  public static let previewValue = Self(
    useRustAPI: { _ in false }
  )
  public static let testValue = Self(
    useRustAPI: { _ in false }
  )
}

extension FeatureFlagsClient: DependencyKey {
  static func defaultUseRustAPI(
    _ domain: FeatureDomain,
    userDefaults: UserDefaults = .standard,
    isDebug: Bool
  ) -> Bool {
    if isDebug {
      return true  // Dev 빌드: 전체 도메인 Rust API 사용
    }
    if domain == .promises || domain == .subscription || domain == .briefing {
      return true  // Big-bang cutover: release에서도 Rust authority 고정
    }
    return userDefaults.bool(forKey: "rust_api_\(domain.rawValue)")
  }

  public static let liveValue = Self(
    useRustAPI: { domain in
      #if DEBUG
      return Self.defaultUseRustAPI(domain, isDebug: true)
      #else
      return Self.defaultUseRustAPI(domain, isDebug: false)
      #endif
    }
  )
}

extension DependencyValues {
  public var featureFlags: FeatureFlagsClient {
    get { self[FeatureFlagsClient.self] }
    set { self[FeatureFlagsClient.self] = newValue }
  }
}
