import Testing
@testable import SettingsFeature

@Suite("NotificationSettings.Feature 테스트")
@MainActor
struct NotificationSettingsFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = NotificationSettings.Feature.State(currentUserId: "user-1")

    #expect(state.systemAuthStatus == .notDetermined)
    #expect(state.groups.isEmpty)
    #expect(state.isLoadingGroups == false)
    #expect(state.isSystemNotificationEnabled == false)
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 권한 상태 조회 및 그룹 로드")
  func onAppear_loadsStatusAndGroups() async {
    let groups = [
      makeGroupInfo(id: "g1", joinedAt: Date(timeIntervalSince1970: 100)),
      makeGroupInfo(id: "g2", joinedAt: Date(timeIntervalSince1970: 200)),
    ]
    let user = UserPrivateModel(
      userId: "user-1", name: "테스트", nickname: "닉네임",
      email: "t@e.com", provider: "apple", metadata: .init(), groups: groups
    )

    let store = makeStore {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.userProfileClient.getPrivateProfile = { _ in user }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingGroups = true
    }
    await store.receive(\.internal.systemAuthStatusReceived) {
      $0.systemAuthStatus = .authorized
    }
    await store.receive(\.internal.groupsLoaded) {
      $0.groups = [groups[1], groups[0]]  // joinedAt 내림차순
      $0.isLoadingGroups = false
    }
  }

  @Test("onAppear 그룹 로드 실패 시 빈 배열")
  func onAppear_groupLoadFails_setsEmpty() async {
    let store = makeStore {
      $0.notificationClient.getAuthorizationStatus = { .denied }
      $0.userProfileClient.getPrivateProfile = { _ in throw NSError(domain: "test", code: 1) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingGroups = true
    }
    await store.receive(\.internal.systemAuthStatusReceived) {
      $0.systemAuthStatus = .denied
    }
    await store.receive(\.internal.groupsLoaded) {
      $0.groups = []
      $0.isLoadingGroups = false
    }
  }

  // MARK: - onSceneActive 테스트

  @Test("onSceneActive 시 권한 상태 갱신")
  func onSceneActive_refreshesStatus() async {
    let store = makeStore {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onSceneActive))
    await store.receive(\.internal.systemAuthStatusReceived) {
      $0.systemAuthStatus = .authorized
    }
  }

  // MARK: - systemNotificationToggleTapped 테스트

  @Test("systemNotificationToggleTapped 시 설정 앱 열기")
  func systemNotificationToggleTapped_opensSettings() async {
    let settingsOpened = LockIsolated(false)
    let store = makeStore {
      $0.notificationClient.openNotificationSettings = { settingsOpened.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.systemNotificationToggleTapped))

    #expect(settingsOpened.value == true)
  }

  // MARK: - isSystemNotificationEnabled 계산 프로퍼티 테스트

  @Test("authorized 상태에서 isSystemNotificationEnabled true")
  func isSystemNotificationEnabled_authorized_returnsTrue() {
    var state = NotificationSettings.Feature.State(currentUserId: "user-1")
    state.systemAuthStatus = .authorized
    #expect(state.isSystemNotificationEnabled == true)
  }

  @Test("denied 상태에서 isSystemNotificationEnabled false")
  func isSystemNotificationEnabled_denied_returnsFalse() {
    var state = NotificationSettings.Feature.State(currentUserId: "user-1")
    state.systemAuthStatus = .denied
    #expect(state.isSystemNotificationEnabled == false)
  }
}

// MARK: - Helpers

private extension NotificationSettingsFeatureTests {

  func makeStore(
    state: NotificationSettings.Feature.State = .init(currentUserId: "user-1"),
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<NotificationSettings.Feature> {
    TestStore(initialState: state) {
      NotificationSettings.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func makeGroupInfo(
    id: String,
    name: String = "테스트 그룹",
    joinedAt: Date? = nil
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name, joinedAt: joinedAt)
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.notificationClient.getAuthorizationStatus = { .notDetermined }
    deps.notificationClient.openNotificationSettings = {}
    deps.userProfileClient.getPrivateProfile = { _ in
      UserPrivateModel(
        userId: "user-1", name: "테스트", nickname: "테스트유저",
        email: "t@e.com", provider: "apple", metadata: .init(), groups: []
      )
    }
    deps.hapticFeedback.selection = {}
    deps.hapticFeedback.success = {}
    deps.hapticFeedback.error = {}
  }
}
