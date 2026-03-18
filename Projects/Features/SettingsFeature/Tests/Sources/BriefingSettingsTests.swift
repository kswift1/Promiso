import Clients
import Testing
@testable import SettingsFeature

@Suite("BriefingSettings.Feature 테스트")
@MainActor
struct BriefingSettingsTests {
  // MARK: - 비Pro 사용자 테스트 (페이월 요청)

  @Test("비Pro 사용자가 프로 기능을 탭하면 페이월을 요청한다")
  func nonProFeatureTap_requestsPaywall() async {
    let store = makeStore(isPro: false)

    await store.send(.view(.proFeatureTapped))
    await store.receive(\.delegate.proPlanRequested)
  }

  // MARK: - Pro 사용자 기능 테스트

  @Test("Pro 사용자가 스타일을 선택하면 상태가 업데이트된다")
  func proStyleSelection_updatesState() async {
    let store = makeStore(isPro: true)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.styleSelected(.humorous))) {
      $0.selectedStyle = .humorous
    }
  }

  @Test("알림 권한이 있는 Pro 사용자가 알림 토글을 켜면 시간이 설정된다")
  func proNotificationToggleOn_withPermission_setsHour() async {
    var initialState = BriefingSettings.Feature.State(isPro: true)
    initialState.notificationAuthStatus = .authorized
    let store = TestStore(
      initialState: initialState
    ) {
      BriefingSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
      $0.authClient.currentUser = { nil }
      $0.userSettingsClient.updateBriefingNotificationHour = { _, _ in }
      $0.notificationClient.getAuthorizationStatus = { .authorized }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationHour = 8
    }
  }

  @Test("알림 권한이 없는 Pro 사용자가 알림 토글을 켜면 권한 요청 sheet이 표시된다")
  func proNotificationToggleOn_withoutPermission_showsPermissionSheet() async {
    let store = makeStore(isPro: true)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationPermission = .init(allowInteractiveDismiss: true)
    }
  }

  @Test("Pro 사용자가 알림 토글을 끄면 시간이 제거된다")
  func proNotificationToggleOff_clearsHour() async {
    var initialState = BriefingSettings.Feature.State(isPro: true)
    initialState.notificationHour = 8
    let store = TestStore(
      initialState: initialState
    ) {
      BriefingSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
      $0.authClient.currentUser = { nil }
      $0.userSettingsClient.updateBriefingNotificationHour = { _, _ in }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.notificationToggled(false))) {
      $0.notificationHour = nil
    }
  }

  @Test("Pro 사용자가 알림 시간을 변경하면 업데이트된다")
  func proNotificationHourChange_updates() async {
    let store = makeStore(isPro: true)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.notificationHourChanged(19))) {
      $0.notificationHour = 19
    }
  }

  @Test("비Pro 사용자 상태 확인")
  func nonProUserState_isCorrect() {
    let state = BriefingSettings.Feature.State(isPro: false)
    #expect(state.isPro == false)
  }

  @Test("Pro 사용자 상태 확인")
  func proUserState_isCorrect() {
    let state = BriefingSettings.Feature.State(isPro: true)
    #expect(state.isPro == true)
  }

  @Test("초기 선택 스타일은 friendly")
  func initialSelectedStyle_isFriendly() {
    let state = BriefingSettings.Feature.State(isPro: true)
    #expect(state.selectedStyle == .friendly)
  }

  @Test("초기 알림 시간은 nil")
  func initialNotificationHour_isNil() {
    let state = BriefingSettings.Feature.State(isPro: true)
    #expect(state.notificationHour == nil)
  }

  // MARK: - Helper

  private func makeStore(
    isPro: Bool,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<BriefingSettings.Feature> {
    TestStore(
      initialState: BriefingSettings.Feature.State(isPro: isPro)
    ) {
      BriefingSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
      $0.authClient.currentUser = { nil }
      $0.userSettingsClient.updateBriefingStyle = { _, _ in }
      $0.userSettingsClient.updateBriefingNotificationHour = { _, _ in }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      configure(&$0)
    }
  }
}
