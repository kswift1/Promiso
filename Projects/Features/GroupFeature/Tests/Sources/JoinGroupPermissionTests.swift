//
//  JoinGroupPermissionTests.swift
//  GroupFeature
//
//  JoinGroup 설정 화면의 알림/캘린더 권한 처리 테스트
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/JoinGroup/Main/JoinGroupFeature.swift`
//
//  ## 테스트 시나리오
//  - 푸시 알림 권한 처리 (authorized, denied, notDetermined)
//  - 캘린더 동기화 권한 처리 (fullAccess, writeOnly, denied, notDetermined)
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

private func makeTestGroup() -> GroupModel {
  GroupModel(
    id: "test-group-id",
    name: "테스트 그룹",
    maxMembers: 5,
    inviteCode: "ABC123",
    createdBy: "creator-id"
  )
}

private func makeSettingsState() -> JoinGroup.Feature.State {
  var state = JoinGroup.Feature.State(currentUser: makeTestUser())
  state.step = .settings(makeTestGroup())
  return state
}

// MARK: - JoinGroup Notification Permission Tests

@Suite("JoinGroup 푸시 알림 권한 처리 테스트")
struct JoinGroupNotificationPermissionTests {

  @Test("권한 authorized 시 notificationEnabled = true 유지")
  @MainActor
  func notificationAuthStatus_authorized_keepsEnabled() async {
    let store = TestStore(
      initialState: makeSettingsState()
    ) {
      JoinGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }

    await store.send(.internal(.notificationAuthStatusChecked(.authorized))) {
      $0.notificationAuthStatus = .authorized
      // authorized면 notificationEnabled = true 유지
    }
  }

  @Test("권한 denied 시 notificationEnabled = false 설정")
  @MainActor
  func notificationAuthStatus_denied_setsDisabled() async {
    let store = TestStore(
      initialState: makeSettingsState()
    ) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.notificationAuthStatusChecked(.denied))) {
      $0.notificationAuthStatus = .denied
      $0.notificationEnabled = false
    }
  }

  @Test("토글 OFF 시 단순히 false 설정")
  @MainActor
  func notificationToggle_off_simplyDisables() async {
    var state = makeSettingsState()
    state.notificationEnabled = true
    state.notificationAuthStatus = .authorized

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
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
      JoinGroup.Feature()
    }

    await store.send(.view(.notificationToggled(true))) {
      $0.notificationEnabled = true
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
      JoinGroup.Feature()
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

// MARK: - JoinGroup Calendar Permission Tests

@Suite("JoinGroup 캘린더 동기화 권한 처리 테스트")
struct JoinGroupCalendarPermissionTests {

  @Test("권한 fullAccess 시 calendarSyncEnabled = true 유지")
  @MainActor
  func calendarAuthStatus_fullAccess_keepsEnabled() async {
    let store = TestStore(
      initialState: makeSettingsState()
    ) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.fullAccess))) {
      $0.calendarAuthStatus = .fullAccess
      // fullAccess면 calendarSyncEnabled = true 유지
    }
  }

  @Test("권한 denied 시 calendarSyncEnabled = false 설정")
  @MainActor
  func calendarAuthStatus_denied_setsDisabled() async {
    let store = TestStore(
      initialState: makeSettingsState()
    ) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.denied))) {
      $0.calendarAuthStatus = .denied
      $0.calendarSyncEnabled = false
    }
  }

  @Test("토글 OFF 시 단순히 false 설정")
  @MainActor
  func calendarToggle_off_simplyDisables() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = true
    state.calendarAuthStatus = .fullAccess

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    }

    await store.send(.view(.calendarSyncToggled(false))) {
      $0.calendarSyncEnabled = false
    }
  }

  @Test("권한 denied 상태에서 토글 ON 시 Alert 표시 (토글 ON 유지)")
  @MainActor
  func calendarToggle_on_whenDenied_showsAlert() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .denied

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
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
      JoinGroup.Feature()
    }

    await store.send(.view(.calendarPermissionInfoAlertDismissed)) {
      $0.showCalendarPermissionInfoAlert = false
    }
  }
}
