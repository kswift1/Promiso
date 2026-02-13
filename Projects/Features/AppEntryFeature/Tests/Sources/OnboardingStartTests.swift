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

  // MARK: - createGroupTapped

  @Test("createGroupTapped → delegate.createGroup")
  func createGroupTapped_delegatesCreateGroup() async {
    let store = TestStore(
      initialState: AppEntry.OnboardingStart.State(nickname: "테스터")
    ) {
      AppEntry.OnboardingStart()
    }
    await store.send(.view(.createGroupTapped))
    await store.receive(\.delegate)
  }

  // MARK: - enterInviteCodeTapped

  @Test("enterInviteCodeTapped → delegate.enterInviteCode")
  func enterInviteCodeTapped_delegatesEnterInviteCode() async {
    let store = TestStore(
      initialState: AppEntry.OnboardingStart.State(nickname: "테스터")
    ) {
      AppEntry.OnboardingStart()
    }
    await store.send(.view(.enterInviteCodeTapped))
    await store.receive(\.delegate)
  }

  // MARK: - personalScheduleTapped

  @Test("personalScheduleTapped → delegate.completed")
  func personalScheduleTapped_delegatesCompleted() async {
    let store = TestStore(
      initialState: AppEntry.OnboardingStart.State(nickname: "테스터")
    ) {
      AppEntry.OnboardingStart()
    }
    await store.send(.view(.personalScheduleTapped))
    await store.receive(\.delegate)
  }
}
