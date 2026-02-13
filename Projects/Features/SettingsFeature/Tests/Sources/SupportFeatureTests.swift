import Testing
@testable import SettingsFeature

@Suite("Support.Feature 테스트")
@MainActor
struct SupportFeatureTests {

  // MARK: - faqTapped 테스트

  @Test("faqTapped 시 haptic 호출")
  func faqTapped_triggersHaptic() async {
    let hapticCalled = LockIsolated(false)
    let store = makeStore {
      $0.hapticFeedback.selection = { hapticCalled.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.faqTapped))

    #expect(hapticCalled.value == true)
  }

  // MARK: - bugReportTapped 테스트

  @Test("bugReportTapped 시 메일 앱 열기")
  func bugReportTapped_opensMailApp() async {
    let urlOpened = LockIsolated(false)
    let store = makeStore {
      $0.openURL = .init { _ in
        urlOpened.setValue(true)
        return true
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.bugReportTapped))

    #expect(urlOpened.value == true)
  }
}

// MARK: - Helpers

private extension SupportFeatureTests {

  func makeStore(
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<Support.Feature> {
    TestStore(initialState: Support.Feature.State()) {
      Support.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.hapticFeedback.selection = {}
    deps.openURL = .init { _ in true }
  }
}
