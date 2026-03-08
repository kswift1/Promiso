import ComposableArchitecture
import Testing
@testable import SettingsFeature

@Suite("ConflictThresholdSettings.Feature 테스트")
struct ConflictThresholdSettingsTests {

  @Test("비프로 사용자가 충돌 감지 토글을 탭하면 페이월을 요청한다")
  func nonProToggleTap_requestsPaywall() async {
    let store = TestStore(
      initialState: ConflictThresholdSettings.Feature.State(isPro: false)
    ) {
      ConflictThresholdSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }

    await store.send(.view(.enabledToggled(true)))
    await store.receive(.delegate(.proPlanRequested))
  }

  @Test("비프로 사용자가 여유시간 영역을 탭하면 페이월을 요청한다")
  func nonProThresholdTap_requestsPaywall() async {
    let store = TestStore(
      initialState: ConflictThresholdSettings.Feature.State(isPro: false)
    ) {
      ConflictThresholdSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }

    await store.send(.view(.proFeatureTapped))
    await store.receive(.delegate(.proPlanRequested))
  }
}
