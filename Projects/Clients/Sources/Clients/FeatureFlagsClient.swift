import ComposableArchitecture
import Foundation

public enum FeatureDomain: String, CaseIterable, Sendable {
  case users
  case groups
  case promises
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
      // TODO: 검증 완료 후 UserDefaults 토글로 복원
      // UserDefaults.standard.bool(forKey: "rust_api_\(domain.rawValue)")
      domain == .users  // users만 Rust ON, 나머지 OFF
    }
  )
}

extension DependencyValues {
  public var featureFlags: FeatureFlagsClient {
    get { self[FeatureFlagsClient.self] }
    set { self[FeatureFlagsClient.self] = newValue }
  }
}
