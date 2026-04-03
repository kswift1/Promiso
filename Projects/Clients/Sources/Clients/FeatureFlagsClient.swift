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
      // Dev: 기본 OFF. UserDefaults로 토글 가능 (Settings 번들 또는 디버그 메뉴)
      UserDefaults.standard.bool(forKey: "rust_api_\(domain.rawValue)")
    }
  )
}

extension DependencyValues {
  public var featureFlags: FeatureFlagsClient {
    get { self[FeatureFlagsClient.self] }
    set { self[FeatureFlagsClient.self] = newValue }
  }
}
