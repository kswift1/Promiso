//
//  CreateGroupPermissionTests.swift
//  GroupFeature
//
//  CreateGroup 설정 화면의 알림/캘린더 권한 처리 테스트
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreateGroup/Main/CreateGroupFeature.swift`
//
//  ## 테스트 시나리오
//  - 푸시 알림 권한 처리 (authorized, denied, notDetermined)
//  - 캘린더 동기화 권한 처리 (fullAccess, writeOnly, denied, notDetermined)
//  - 권한 상태에 따른 초기값 설정
//  - 토글 동작 및 권한 요청 흐름
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
@testable import GroupFeature

// MARK: - Test Helpers

private func makeTestUser() -> UserPrivateModel {
  UserPrivateModel(
    userId: "test-user-id",
    name: "테스트",
    nickname: "테스터",
    email: "test@test.com",
    provider: "apple",
    metadata: Metadata()
  )
}

private func makeTestGroupResult() -> GroupCreationResultModel {
  GroupCreationResultModel(
    id: "test-group-id",
    name: "테스트 그룹",
    inviteCode: "ABC123"
  )
}

private func makeSuccessState() -> CreateGroup.Feature.State {
  var state = CreateGroup.Feature.State(currentUser: makeTestUser())
  state.step = .success(makeTestGroupResult())
  return state
}

private func makeSettingsState() -> CreateGroup.Feature.State {
  var state = CreateGroup.Feature.State(currentUser: makeTestUser())
  state.step = .settings(makeTestGroupResult())
  return state
}

// MARK: - Notification Permission Tests

@Suite("푸시 알림 권한 처리 테스트")
struct NotificationPermissionTests {

  // MARK: - 초기 상태 테스트

  @Test("권한 authorized 시 notificationEnabled = true 유지")
  @MainActor
  func notificationAuthStatus_authorized_keepsEnabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }

    // settings 단계로 진입
    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .authorized
      // authorized면 notificationEnabled = true 유지
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .fullAccess
    }
  }

  @Test("권한 denied 시 notificationEnabled = false 설정")
  @MainActor
  func notificationAuthStatus_denied_setsDisabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .denied }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .denied
      $0.notificationEnabled = false  // denied면 OFF
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .fullAccess
    }
  }

  @Test("권한 notDetermined 시 notificationEnabled = false 설정")
  @MainActor
  func notificationAuthStatus_notDetermined_setsDisabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .notDetermined
      $0.notificationEnabled = false  // notDetermined면 OFF
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .fullAccess
    }
  }

  // MARK: - 토글 동작 테스트

  @Test("토글 OFF 시 단순히 false 설정")
  @MainActor
  func notificationToggle_off_simplyDisables() async {
    var state = makeSettingsState()
    state.notificationEnabled = true
    state.notificationAuthStatus = .authorized

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.notificationToggled(false))) {
      $0.notificationEnabled = false
    }
  }

  @Test("권한 authorized 상태에서 토글 ON 시 바로 활성화")
  @MainActor
  func notificationToggle_on_whenAuthorized_enables() async {
    var state = makeSettingsState()
    state.notificationEnabled = false
    state.notificationAuthStatus = .authorized

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationEnabled = true
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 granted면 활성화")
  @MainActor
  func notificationToggle_on_whenNotDetermined_requestsPermission_granted() async {
    var state = makeSettingsState()
    state.notificationEnabled = false
    state.notificationAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.requestAuthorization = { true }
    }

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationEnabled = true
    }

    await store.receive(\.internal.notificationPermissionResponse) {
      $0.notificationAuthStatus = .authorized
      // notificationEnabled은 이미 true
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 denied면 비활성화")
  @MainActor
  func notificationToggle_on_whenNotDetermined_requestsPermission_denied() async {
    var state = makeSettingsState()
    state.notificationEnabled = false
    state.notificationAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.requestAuthorization = { false }
    }

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationEnabled = true
    }

    await store.receive(\.internal.notificationPermissionResponse) {
      $0.notificationAuthStatus = .denied
      $0.notificationEnabled = false  // 거부 시 OFF
    }
  }

  @Test("권한 denied 상태에서 토글 ON 시 설정으로 이동, 토글은 OFF 유지")
  @MainActor
  func notificationToggle_on_whenDenied_opensSettings() async {
    var state = makeSettingsState()
    state.notificationEnabled = false
    state.notificationAuthStatus = .denied

    let openSettingsCalled = LockIsolated(false)

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.openNotificationSettings = {
        openSettingsCalled.setValue(true)
      }
    }

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationEnabled = false  // denied면 OFF 유지
    }

    // Effect 완료 대기
    await store.finish()

    #expect(openSettingsCalled.value == true)
  }
}

// MARK: - Calendar Permission Tests

@Suite("캘린더 동기화 권한 처리 테스트")
struct CalendarPermissionTests {

  // MARK: - 초기 상태 테스트

  @Test("권한 fullAccess 시 calendarSyncEnabled = true 유지")
  @MainActor
  func calendarAuthStatus_fullAccess_keepsEnabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .authorized
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .fullAccess
      // fullAccess면 calendarSyncEnabled = true 유지
    }
  }

  @Test("권한 writeOnly 시 calendarSyncEnabled = true 유지")
  @MainActor
  func calendarAuthStatus_writeOnly_keepsEnabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .writeOnly }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .authorized
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .writeOnly
      // writeOnly도 쓰기 가능하므로 calendarSyncEnabled = true 유지
    }
  }

  @Test("권한 denied 시 calendarSyncEnabled = false 설정")
  @MainActor
  func calendarAuthStatus_denied_setsDisabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .denied }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .authorized
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .denied
      $0.calendarSyncEnabled = false  // denied면 OFF
    }
  }

  @Test("권한 notDetermined 시 calendarSyncEnabled = false 설정")
  @MainActor
  func calendarAuthStatus_notDetermined_setsDisabled() async {
    let store = TestStore(
      initialState: makeSuccessState()
    ) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .notDetermined }
    }

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(makeTestGroupResult())
    }

    await store.receive(\.internal.notificationAuthStatusChecked) {
      $0.notificationAuthStatus = .authorized
    }

    await store.receive(\.internal.calendarAuthStatusChecked) {
      $0.calendarAuthStatus = .notDetermined
      $0.calendarSyncEnabled = false  // notDetermined면 OFF (canWriteEvents = false)
    }
  }

  // MARK: - 토글 동작 테스트

  @Test("토글 OFF 시 단순히 false 설정")
  @MainActor
  func calendarToggle_off_simplyDisables() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = true
    state.calendarAuthStatus = .fullAccess

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.calendarSyncToggled(false))) {
      $0.calendarSyncEnabled = false
    }
  }

  @Test("권한 fullAccess 상태에서 토글 ON 시 바로 활성화")
  @MainActor
  func calendarToggle_on_whenFullAccess_enables() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .fullAccess

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.calendarSyncToggled(true))) {
      $0.calendarSyncEnabled = true
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 granted면 활성화")
  @MainActor
  func calendarToggle_on_whenNotDetermined_requestsPermission_granted() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.eventKitClient.requestAccess = { true }
    }

    await store.send(.view(.calendarSyncToggled(true))) {
      $0.calendarSyncEnabled = true
    }

    await store.receive(\.internal.calendarPermissionResponse) {
      $0.calendarAuthStatus = .fullAccess
      // calendarSyncEnabled은 이미 true
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 denied면 Alert 표시 (토글 ON 유지)")
  @MainActor
  func calendarToggle_on_whenNotDetermined_requestsPermission_denied() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.eventKitClient.requestAccess = { false }
    }

    await store.send(.view(.calendarSyncToggled(true))) {
      $0.calendarSyncEnabled = true
    }

    await store.receive(\.internal.calendarPermissionResponse) {
      $0.calendarAuthStatus = .denied
      $0.showCalendarPermissionInfoAlert = true  // Alert 표시
      // calendarSyncEnabled은 true 유지 (푸시 알림과 다른 동작)
    }
  }

  @Test("권한 denied 상태에서 토글 ON 시 Alert 표시 (토글 ON 유지)")
  @MainActor
  func calendarToggle_on_whenDenied_showsAlert() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .denied

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.calendarSyncToggled(true))) {
      $0.calendarSyncEnabled = true  // ON 유지
      $0.showCalendarPermissionInfoAlert = true  // Alert 표시
    }
  }

  @Test("Calendar Permission Info Alert dismiss")
  @MainActor
  func calendarPermissionInfoAlert_dismiss() async {
    var state = makeSettingsState()
    state.showCalendarPermissionInfoAlert = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.calendarPermissionInfoAlertDismissed)) {
      $0.showCalendarPermissionInfoAlert = false
    }
  }
}
