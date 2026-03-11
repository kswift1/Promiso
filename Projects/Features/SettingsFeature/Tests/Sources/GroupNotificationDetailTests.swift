import Testing
@testable import SettingsFeature

@Suite("GroupNotificationDetail.Feature 테스트")
@MainActor
struct GroupNotificationDetailTests {

  // MARK: - groupNotificationToggled 테스트

  @Test("groupNotificationToggled 성공 시 optimistic update 유지")
  func groupNotificationToggled_success_keepsUpdate() async {
    let group = makeGroupInfo(id: "g1", notifications: GroupNotificationSettings(enabled: true))

    let store = makeStore(group: group) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.groupNotificationToggled(false))) {
      $0.group = $0.group.withNotifications(
        GroupNotificationSettings(enabled: false)
      )
    }
    await store.receive(\.internal.updateSucceeded)
  }

  @Test("groupNotificationToggled 실패 시 이전 값 롤백")
  func groupNotificationToggled_failure_rollsBack() async {
    let settings = GroupNotificationSettings(enabled: true)
    let group = makeGroupInfo(id: "g1", notifications: settings)

    let store = makeStore(group: group) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in
        throw NSError(domain: "test", code: 1)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.groupNotificationToggled(false))) {
      $0.group = $0.group.withNotifications(
        GroupNotificationSettings(enabled: false)
      )
    }
    await store.receive(\.internal.updateFailed) {
      $0.group = $0.group.withNotifications(settings)
    }
  }

  // MARK: - preferenceToggled 테스트

  @Test("preferenceToggled 성공 시 optimistic update 유지")
  func preferenceToggled_success_keepsUpdate() async {
    let group = makeGroupInfo(id: "g1", notifications: GroupNotificationSettings())

    let store = makeStore(group: group) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.preferenceToggled(.scheduleInvitation, false))) {
      var updated = GroupNotificationSettings()
      updated.setValue(false, for: .scheduleInvitation)
      $0.group = $0.group.withNotifications(updated)
    }
    await store.receive(\.internal.updateSucceeded)
  }

  @Test("preferenceToggled 실패 시 이전 값 롤백")
  func preferenceToggled_failure_rollsBack() async {
    let settings = GroupNotificationSettings()
    let group = makeGroupInfo(id: "g1", notifications: settings)

    let store = makeStore(group: group) {
      $0.groupClient.updateGroupNotificationSettings = { _, _ in
        throw NSError(domain: "test", code: 1)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.preferenceToggled(.groupUpdate, false))) {
      var updated = settings
      updated.setValue(false, for: .groupUpdate)
      $0.group = $0.group.withNotifications(updated)
    }
    await store.receive(\.internal.updateFailed) {
      $0.group = $0.group.withNotifications(settings)
    }
  }

  // MARK: - updateSucceeded 테스트

  @Test("updateSucceeded 시 success haptic 호출")
  func updateSucceeded_triggersHaptic() async {
    let hapticCalled = LockIsolated(false)
    let group = makeGroupInfo(id: "g1", notifications: GroupNotificationSettings())

    let store = makeStore(group: group) {
      $0.hapticFeedback.success = { hapticCalled.setValue(true) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.updateSucceeded))

    #expect(hapticCalled.value == true)
  }

  // MARK: - isGroupEnabled 계산 프로퍼티 테스트

  @Test("notifications nil일 때 isGroupEnabled true (기본값)")
  func isGroupEnabled_nilNotifications_returnsTrue() {
    let state = GroupNotificationDetail.Feature.State(
      group: makeGroupInfo(id: "g1"),
      isSystemNotificationEnabled: true
    )
    #expect(state.isGroupEnabled == true)
  }

  @Test("notifications.enabled false일 때 isGroupEnabled false")
  func isGroupEnabled_disabledNotifications_returnsFalse() {
    let state = GroupNotificationDetail.Feature.State(
      group: makeGroupInfo(id: "g1", notifications: GroupNotificationSettings(enabled: false)),
      isSystemNotificationEnabled: true
    )
    #expect(state.isGroupEnabled == false)
  }
}

// MARK: - Helpers

private extension GroupNotificationDetailTests {

  func makeStore(
    group: UserGroupInfo = UserGroupInfo(id: "g1", name: "테스트 그룹"),
    isSystemNotificationEnabled: Bool = true,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<GroupNotificationDetail.Feature> {
    let state = GroupNotificationDetail.Feature.State(
      group: group,
      isSystemNotificationEnabled: isSystemNotificationEnabled
    )
    return TestStore(initialState: state) {
      GroupNotificationDetail.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func makeGroupInfo(
    id: String,
    name: String = "테스트 그룹",
    notifications: GroupNotificationSettings? = nil
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name, notifications: notifications)
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.groupClient.updateGroupNotificationSettings = { _, _ in }
    deps.hapticFeedback.selection = {}
    deps.hapticFeedback.success = {}
    deps.hapticFeedback.error = {}
  }
}
