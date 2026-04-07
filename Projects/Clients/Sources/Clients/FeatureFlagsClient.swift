import ComposableArchitecture
import Foundation

public enum FeatureDomain: String, CaseIterable, Sendable {
  case users
  case groups
  case promises
  case notifications
  case subscription
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
  public static let liveValue = Self(
    useRustAPI: { domain in
      #if DEBUG
      return true  // Dev 빌드: 전체 도메인 Rust API 사용
      #endif
      return UserDefaults.standard.bool(forKey: "rust_api_\(domain.rawValue)")
    }
  )
}

extension DependencyValues {
  public var featureFlags: FeatureFlagsClient {
    get { self[FeatureFlagsClient.self] }
    set { self[FeatureFlagsClient.self] = newValue }
  }
}
