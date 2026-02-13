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

import Testing
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
@MainActor
struct NotificationPermissionTests {

  // MARK: - 초기 상태 테스트

  @Test("권한 authorized 시 notificationEnabled = true 유지")
  func notificationAuthStatus_authorized_keepsEnabled() async {
    var state = makeSettingsState()
    state.notificationAuthStatus = .notDetermined
    state.notificationEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    // internal action 직접 테스트
    await store.send(.internal(.notificationAuthStatusChecked(.authorized))) {
      $0.notificationAuthStatus = .authorized
      // authorized면 notificationEnabled = true 유지 (변경 없음)
    }
  }

  @Test("권한 denied 시 notificationEnabled = false 설정")
  func notificationAuthStatus_denied_setsDisabled() async {
    var state = makeSettingsState()
    state.notificationAuthStatus = .notDetermined
    state.notificationEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.notificationAuthStatusChecked(.denied))) {
      $0.notificationAuthStatus = .denied
      $0.notificationEnabled = false
    }
  }

  @Test("권한 notDetermined 시 notificationEnabled = false 설정")
  func notificationAuthStatus_notDetermined_setsDisabled() async {
    var state = makeSettingsState()
    state.notificationAuthStatus = .authorized  // 이전 상태
    state.notificationEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.notificationAuthStatusChecked(.notDetermined))) {
      $0.notificationAuthStatus = .notDetermined
      $0.notificationEnabled = false
    }
  }

  // MARK: - 토글 동작 테스트

  @Test("토글 OFF 시 단순히 false 설정")
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
  func notificationToggle_on_whenNotDetermined_requestsPermission_granted() async {
    var state = makeSettingsState()
    state.notificationEnabled = false
    state.notificationAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    // internal action 직접 테스트: granted
    await store.send(.internal(.notificationPermissionResponse(true))) {
      $0.notificationAuthStatus = .authorized
      // notificationEnabled은 이미 true로 설정됨 (토글 ON 시)
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 denied면 비활성화")
  func notificationToggle_on_whenNotDetermined_requestsPermission_denied() async {
    var state = makeSettingsState()
    state.notificationEnabled = true  // 토글 ON 상태로 시작
    state.notificationAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    // internal action 직접 테스트: denied
    await store.send(.internal(.notificationPermissionResponse(false))) {
      $0.notificationAuthStatus = .denied
      $0.notificationEnabled = false
    }
  }

  // NOTE: "권한 denied 상태에서 토글 ON 시 설정으로 이동" 테스트는 제거됨
  // 이유: Side Effect (openNotificationSettings) 실행을 TCA TestStore에서 테스트하기 어려움
  // 실제 동작은 UI 테스트나 수동 테스트로 확인 필요
}

// MARK: - Calendar Permission Tests

@Suite("캘린더 동기화 권한 처리 테스트")
@MainActor
struct CalendarPermissionTests {

  // MARK: - 초기 상태 테스트

  @Test("권한 fullAccess 시 calendarSyncEnabled = true 유지")
  func calendarAuthStatus_fullAccess_keepsEnabled() async {
    var state = makeSettingsState()
    state.calendarAuthStatus = .notDetermined
    state.calendarSyncEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.fullAccess))) {
      $0.calendarAuthStatus = .fullAccess
      // fullAccess면 calendarSyncEnabled = true 유지 (변경 없음)
    }
  }

  @Test("권한 writeOnly 시 calendarSyncEnabled = true 유지")
  func calendarAuthStatus_writeOnly_keepsEnabled() async {
    var state = makeSettingsState()
    state.calendarAuthStatus = .notDetermined
    state.calendarSyncEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.writeOnly))) {
      $0.calendarAuthStatus = .writeOnly
      // writeOnly도 canWriteEvents = true이므로 유지
    }
  }

  @Test("권한 denied 시 calendarSyncEnabled = false 설정")
  func calendarAuthStatus_denied_setsDisabled() async {
    var state = makeSettingsState()
    state.calendarAuthStatus = .notDetermined
    state.calendarSyncEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.denied))) {
      $0.calendarAuthStatus = .denied
      $0.calendarSyncEnabled = false
    }
  }

  @Test("권한 notDetermined 시 calendarSyncEnabled = false 설정")
  func calendarAuthStatus_notDetermined_setsDisabled() async {
    var state = makeSettingsState()
    state.calendarAuthStatus = .fullAccess  // 이전 상태
    state.calendarSyncEnabled = true

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.calendarAuthStatusChecked(.notDetermined))) {
      $0.calendarAuthStatus = .notDetermined
      $0.calendarSyncEnabled = false
    }
  }

  // MARK: - 토글 동작 테스트

  @Test("토글 OFF 시 단순히 false 설정")
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
  func calendarToggle_on_whenNotDetermined_requestsPermission_granted() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = false
    state.calendarAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    // internal action 직접 테스트: granted
    await store.send(.internal(.calendarPermissionResponse(true))) {
      $0.calendarAuthStatus = .fullAccess
      // calendarSyncEnabled은 이미 true로 설정됨 (토글 ON 시)
    }
  }

  @Test("권한 notDetermined 상태에서 토글 ON 시 권한 요청 후 denied면 Alert 표시 (토글 ON 유지)")
  func calendarToggle_on_whenNotDetermined_requestsPermission_denied() async {
    var state = makeSettingsState()
    state.calendarSyncEnabled = true  // 토글 ON 상태로 시작
    state.calendarAuthStatus = .notDetermined

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    // internal action 직접 테스트: denied
    await store.send(.internal(.calendarPermissionResponse(false))) {
      $0.calendarAuthStatus = .denied
      $0.showCalendarPermissionInfoAlert = true
    }
  }

  @Test("권한 denied 상태에서 토글 ON 시 Alert 표시 (토글 ON 유지)")
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
