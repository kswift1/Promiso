import Foundation
import Testing
@testable import Clients

@Suite("FeatureFlagsClient 기본 라우팅 테스트")
struct FeatureFlagsClientTests {
  @Test("debug 빌드에서는 도메인과 무관하게 Rust API를 사용한다")
  func debugAlwaysUseRustAPI() {
    let suiteName = "FeatureFlagsClientTests.debug"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults.set(false, forKey: "rust_api_users")

    #expect(
      FeatureFlagsClient.defaultUseRustAPI(
        .users,
        userDefaults: userDefaults,
        isDebug: true
      )
    )
  }

  @Test("release의 다른 도메인은 기존 UserDefaults 플래그를 따른다")
  func nonPromiseDomainsStillUseStoredFlagsInRelease() {
    let suiteName = "FeatureFlagsClientTests.users"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults.set(true, forKey: "rust_api_users")

    #expect(
      FeatureFlagsClient.defaultUseRustAPI(
        .users,
        userDefaults: userDefaults,
        isDebug: false
      )
    )

    userDefaults.set(false, forKey: "rust_api_users")

    #expect(
      !FeatureFlagsClient.defaultUseRustAPI(
        .users,
        userDefaults: userDefaults,
        isDebug: false
      )
    )
  }
}
