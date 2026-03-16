import Testing
@testable import AppEntryFeature

@Suite("AppEntry.OnboardingIntro 테스트")
@MainActor
struct OnboardingIntroTests {

  // MARK: - 초기 상태

  @Test("초기 상태 기본값")
  func initialState_defaults() {
    let state = AppEntry.OnboardingIntro.State()
    #expect(state.currentScreen == .cinematicHero)
    #expect(state.isAnimationComplete == false)
    #expect(state.isNextButtonEnabled == true)
    #expect(state.isFirstScreen == true)
    #expect(state.isLastScreen == false)
    #expect(state.screenProgress == 0)
    #expect(state.screenCount == 6)
  }

  // MARK: - nextTapped

  @Test("일반 화면에서 nextTapped → 다음 화면")
  func nextTapped_normalScreen_advances() async {
    let store = TestStore(initialState: AppEntry.OnboardingIntro.State()) {
      AppEntry.OnboardingIntro()
    }

    await store.send(.view(.nextTapped)) {
      $0.isAnimationComplete = false
      $0.isNextButtonEnabled = true
      $0.isGoingBack = false
      $0.currentScreen = .benefitConfirm
    }
  }

  @Test("signIn 화면에서 nextTapped → 무시")
  func nextTapped_signInScreen_ignored() async {
    var state = AppEntry.OnboardingIntro.State()
    state.currentScreen = .signIn

    let store = TestStore(initialState: state) {
      AppEntry.OnboardingIntro()
    }

    await store.send(.view(.nextTapped))
  }

  @Test("연속 next로 signIn 직전까지 이동")
  func nextTapped_sequentialAdvance() async {
    let store = TestStore(initialState: AppEntry.OnboardingIntro.State()) {
      AppEntry.OnboardingIntro()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // cinematicHero → benefitConfirm
    await store.send(.view(.nextTapped)) {
      $0.currentScreen = .benefitConfirm
    }
    // benefitConfirm → benefitHome
    await store.send(.view(.nextTapped)) {
      $0.currentScreen = .benefitHome
    }
    // benefitHome → benefitPro
    await store.send(.view(.nextTapped)) {
      $0.currentScreen = .benefitPro
    }
    // benefitPro → benefitLive
    await store.send(.view(.nextTapped)) {
      $0.currentScreen = .benefitLive
    }
    // benefitLive → signIn
    await store.send(.view(.nextTapped)) {
      $0.currentScreen = .signIn
    }
    // signIn → 무시
    await store.send(.view(.nextTapped))
  }

  // MARK: - backTapped

  @Test("첫 화면에서 backTapped → 무시")
  func backTapped_firstScreen_ignored() async {
    let store = TestStore(initialState: AppEntry.OnboardingIntro.State()) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.backTapped))
  }

  @Test("일반 화면에서 backTapped → 이전 화면")
  func backTapped_normalScreen_goesBack() async {
    var state = AppEntry.OnboardingIntro.State()
    state.currentScreen = .benefitHome

    let store = TestStore(initialState: state) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.backTapped)) {
      $0.isAnimationComplete = false
      $0.isNextButtonEnabled = true
      $0.isGoingBack = true
      $0.currentScreen = .benefitConfirm
    }
  }

  // MARK: - skipTapped

  @Test("skipTapped → signIn 화면으로 이동")
  func skipTapped_goesToSignIn() async {
    let store = TestStore(initialState: AppEntry.OnboardingIntro.State()) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.skipTapped)) {
      $0.currentScreen = .signIn
      $0.isAnimationComplete = true
      $0.isNextButtonEnabled = true
    }
  }

  // MARK: - screenAnimationCompleted

  @Test("일반 화면 애니메이션 완료 → isAnimationComplete=true")
  func screenAnimationCompleted_normal() async {
    let store = TestStore(initialState: AppEntry.OnboardingIntro.State()) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.screenAnimationCompleted)) {
      $0.isAnimationComplete = true
    }
  }

  @Test("benefitLive 애니메이션 완료 → nextButton 비활성")
  func screenAnimationCompleted_benefitLive_disablesNext() async {
    var state = AppEntry.OnboardingIntro.State()
    state.currentScreen = .benefitLive

    let store = TestStore(initialState: state) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.screenAnimationCompleted)) {
      $0.isAnimationComplete = true
      $0.isNextButtonEnabled = false
    }
  }

  // MARK: - screenInteractionCompleted

  @Test("screenInteractionCompleted → nextButton 활성")
  func screenInteractionCompleted_enablesNext() async {
    var state = AppEntry.OnboardingIntro.State()
    state.isNextButtonEnabled = false

    let store = TestStore(initialState: state) {
      AppEntry.OnboardingIntro()
    }
    await store.send(.view(.screenInteractionCompleted)) {
      $0.isNextButtonEnabled = true
    }
  }
}
