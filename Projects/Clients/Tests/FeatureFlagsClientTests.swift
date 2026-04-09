import Foundation
import Testing
@testable import Clients

@Suite("FeatureFlagsClient 기본 라우팅 테스트")
struct FeatureFlagsClientTests {
  @Test("release에서도 promises는 Rust API를 강제 사용한다")
  func promisesAlwaysUseRustInRelease() {
    let userDefaults = UserDefaults(suiteName: "FeatureFlagsClientTests.promises")!
    userDefaults.removePersistentDomain(forName: "FeatureFlagsClientTests.promises")

    #expect(
      FeatureFlagsClient.defaultUseRustAPI(
        .promises,
        userDefaults: userDefaults,
        isDebug: false
      )
    )
  }

  @Test("release에서도 subscription은 Rust API를 강제 사용한다")
  func subscriptionAlwaysUseRustInRelease() {
    let userDefaults = UserDefaults(suiteName: "FeatureFlagsClientTests.subscription")!
    userDefaults.removePersistentDomain(forName: "FeatureFlagsClientTests.subscription")

    #expect(
      FeatureFlagsClient.defaultUseRustAPI(
        .subscription,
        userDefaults: userDefaults,
        isDebug: false
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
