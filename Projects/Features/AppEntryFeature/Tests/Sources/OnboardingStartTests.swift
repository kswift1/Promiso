import Testing
@testable import AppEntryFeature

@Suite("AppEntry.OnboardingStart 테스트")
@MainActor
struct OnboardingStartTests {

  // MARK: - 초기 상태

  @Test("초기 상태 nickname 설정")
  func initialState_setsNickname() {
    let state = AppEntry.OnboardingStart.State(nickname: "테스터")
    #expect(state.nickname == "테스터")
  }

  // MARK: - startTapped

  @Test("startTapped → delegate.completed")
  func startTapped_delegatesCompleted() async {
    let store = TestStore(
      initialState: AppEntry.OnboardingStart.State(nickname: "테스터")
    ) {
      AppEntry.OnboardingStart()
    }
    await store.send(.view(.startTapped))
    await store.receive(\.delegate)
  }
}
