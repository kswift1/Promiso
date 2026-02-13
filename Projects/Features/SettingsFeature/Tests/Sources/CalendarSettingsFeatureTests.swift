import Testing
@testable import SettingsFeature

@Suite("CalendarSettings.Feature 테스트")
@MainActor
struct CalendarSettingsFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = CalendarSettings.Feature.State()

    #expect(state.authorizationStatus == .notDetermined)
    #expect(state.isRequestingAccess == false)
    #expect(state.groups.isEmpty)
    #expect(state.updatingGroupIds.isEmpty)
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 권한 상태 설정 및 그룹 로드")
  func onAppear_setsStatusAndLoadsGroups() async {
    let groups = [makeGroupInfo(id: "g1"), makeGroupInfo(id: "g2")]

    let store = makeStore {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.groupClient.fetchGroupSummaries = { groups }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.authorizationStatus = .fullAccess
    }
    await store.receive(\.internal.groupsUpdated) {
      $0.groups = groups
    }
  }

  // MARK: - 캘린더 토글 테스트

  @Test("calendarToggleTapped notDetermined 시 권한 요청")
  func calendarToggleTapped_notDetermined_requestsAccess() async {
    let store = makeStore {
      $0.eventKitClient.requestAccess = { true }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.calendarToggleTapped)) {
      $0.isRequestingAccess = true
    }
    await store.receive(\.internal.accessRequestCompleted) {
      $0.isRequestingAccess = false
      $0.authorizationStatus = .fullAccess
    }
  }

  @Test("calendarToggleTapped denied 시 설정 앱 열기")
  func calendarToggleTapped_denied_opensSettings() async {
    var state = CalendarSettings.Feature.State()
    state.authorizationStatus = .denied

    let settingsOpened = LockIsolated(false)
    let store = makeStore(state: state) {
      $0.eventKitClient.openSettings = { settingsOpened.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.calendarToggleTapped))

    #expect(settingsOpened.value == true)
  }

  // MARK: - accessRequestCompleted 테스트

  @Test("accessRequestCompleted 거부 시 denied 상태")
  func accessRequestCompleted_denied_setsDenied() async {
    var state = CalendarSettings.Feature.State()
    state.isRequestingAccess = true

    let store = makeStore(state: state) {
      $0.eventKitClient.authorizationStatus = { .denied }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.accessRequestCompleted(false))) {
      $0.isRequestingAccess = false
      $0.authorizationStatus = .denied
    }
  }

  // MARK: - 그룹 캘린더 동기화 테스트

  @Test("groupCalendarSyncToggled 성공 시 optimistic update 유지")
  func groupCalendarSyncToggled_success_keepsUpdate() async {
    var state = CalendarSettings.Feature.State()
    state.groups = [makeGroupInfo(id: "g1")]

    let store = makeStore(state: state) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.groupCalendarSyncToggled(groupId: "g1", enabled: false))) {
      $0.updatingGroupIds.insert("g1")
    }
    await store.receive(\.internal.groupSettingsUpdateCompleted) {
      $0.updatingGroupIds.remove("g1")
    }
  }

  @Test("groupCalendarSyncToggled 실패 시 이전 값 롤백")
  func groupCalendarSyncToggled_failure_rollsBack() async {
    var state = CalendarSettings.Feature.State()
    state.groups = [makeGroupInfo(id: "g1")]

    let store = makeStore(state: state) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in
        throw NSError(domain: "test", code: 1)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.groupCalendarSyncToggled(groupId: "g1", enabled: false))) {
      $0.updatingGroupIds.insert("g1")
    }
    await store.receive(\.internal.groupSettingsUpdateCompleted)

    #expect(store.state.updatingGroupIds.isEmpty)
  }

  @Test("groupCalendarSyncToggled 존재하지 않는 그룹 시 무시")
  func groupCalendarSyncToggled_unknownGroup_ignored() async {
    let store = makeStore()

    await store.send(.view(.groupCalendarSyncToggled(groupId: "unknown", enabled: true)))
  }
}

// MARK: - Helpers

private extension CalendarSettingsFeatureTests {

  func makeStore(
    state: CalendarSettings.Feature.State = .init(),
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<CalendarSettings.Feature> {
    TestStore(initialState: state) {
      CalendarSettings.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func makeGroupInfo(
    id: String,
    name: String = "테스트 그룹"
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name)
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.eventKitClient.authorizationStatus = { .notDetermined }
    deps.eventKitClient.requestAccess = { false }
    deps.eventKitClient.openSettings = {}
    deps.groupClient.fetchGroupSummaries = { [] }
    deps.groupClient.updateGroupNotificationSettings = { _, _ in }
    deps.hapticFeedback.medium = {}
    deps.hapticFeedback.selection = {}
    deps.hapticFeedback.success = {}
    deps.hapticFeedback.error = {}
  }
}
