import Testing
@testable import SettingsFeature

@Suite("LegalInfo.Feature 테스트")
@MainActor
struct LegalInfoFeatureTests {

  // MARK: - privacyPolicyTapped 테스트

  @Test("privacyPolicyTapped 시 haptic 호출")
  func privacyPolicyTapped_triggersHaptic() async {
    let hapticCalled = LockIsolated(false)
    let store = makeStore {
      $0.hapticFeedback.selection = { hapticCalled.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.privacyPolicyTapped))

    #expect(hapticCalled.value == true)
  }

  // MARK: - termsOfServiceTapped 테스트

  @Test("termsOfServiceTapped 시 haptic 호출")
  func termsOfServiceTapped_triggersHaptic() async {
    let hapticCalled = LockIsolated(false)
    let store = makeStore {
      $0.hapticFeedback.selection = { hapticCalled.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.termsOfServiceTapped))

    #expect(hapticCalled.value == true)
  }
}

// MARK: - Helpers

private extension LegalInfoFeatureTests {

  func makeStore(
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<LegalInfo.Feature> {
    TestStore(initialState: LegalInfo.Feature.State()) {
      LegalInfo.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.hapticFeedback.selection = {}
  }
}
