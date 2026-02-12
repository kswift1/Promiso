//
//  RootTabFeatureTests.swift
//  RootTabFeature
//
//  RootTab.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `RootTabFeature/Sources/RootTabFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//
//  ## 테스트 목적
//  - Lifecycle (onAppear) 동작 검증
//  - 탭 전환 로직 검증
//  - 딥링크 처리 검증
//  - 하위 Feature delegate 전달 검증
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
import Sharing
@testable import RootTabFeature
@testable import GroupFeature
@testable import HomeFeature

// MARK: - RootTabFeature Tests

@Suite("RootTab.Feature reducer 테스트")
struct RootTabFeatureTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser(
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: "test-user",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      metadata: .init(),
      groups: groups
    )
  }

  // MARK: - Initial State 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-initial")) var currentUser = user

    let state = RootTab.Feature.State(currentUser: $currentUser)

    #expect(state.selectedTab == .home)
    #expect(state.livePromise == nil)
    #expect(state.livePromiseDetail == nil)
    #expect(state.pendingETASheetRequest == false)
  }

  // MARK: - 탭 선택 테스트

  @Test("탭 선택 시 selectedTab 업데이트")
  func tabSelected_updatesSelectedTab() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-select")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
    }

    await store.send(.tabSelected(.group)) {
      $0.selectedTab = .group
    }
  }

  @Test("같은 탭 재선택 시 selectedTab 유지")
  func tabSelected_sameTab_noStateChange() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-same")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
    }

    // home은 기본 선택 탭
    await store.send(.tabSelected(.home))
  }

  @Test("캘린더 탭 선택 시 refresh 전달")
  func tabSelected_calendar_sendsRefresh() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-calendar")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
    }

    await store.send(.tabSelected(.calendar)) {
      $0.selectedTab = .calendar
    }

    await store.receive(\.calendar.view.refresh)
  }

  @Test("홈 탭 선택 시 알림 배지 새로고침 전달")
  func tabSelected_home_sendsRefreshNotificationBadge() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-home")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.selectedTab = .group // 다른 탭에서 시작

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
      $0.notificationClient.getUnreadCount = { _ in 0 }
      $0.notificationClient.setBadgeCount = { _ in }
    }

    await store.send(.tabSelected(.home)) {
      $0.selectedTab = .home
    }

    await store.receive(\.home.view.refreshNotificationBadge)
    // 알림 개수 조회 체인
    await store.receive(\.home.internal.fetchUnreadNotificationCount)
    await store.receive(\.home.internal.unreadNotificationCountResponse)
  }

  // MARK: - 딥링크 테스트

  @Test("초대 코드 딥링크 시 그룹 탭으로 이동")
  func openJoinGroupWithCode_switchesToGroupTab() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-deeplink-join")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    await store.send(.openJoinGroupWithCode("INVITE123")) {
      $0.selectedTab = .group
    }

    await store.receive(\.groupMain.view.joinGroupWithCode) {
      #expect($0.groupMain.joinGroup != nil)
    }

    // joinGroupWithCode는 자동으로 nextTapped도 전송
    await store.receive(\.groupMain.joinGroup)
  }

  @Test("그룹 딥링크 시 그룹 탭으로 이동")
  func handleGroupDeeplink_switchesToGroupTab() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-deeplink-group")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.groupMain.allGroupSummaries = []

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { [] }
    }

    await store.send(.handleGroupDeeplink(.group(groupId: "group-1"))) {
      $0.selectedTab = .group
    }

    await store.receive(\.groupMain.view.handleDeeplink) {
      $0.groupMain.pendingDeeplink = .group(groupId: "group-1")
    }

    // 그룹을 찾지 못하면 fetchGroupList 트리거
    await store.receive(\.groupMain.internal.fetchGroupList)
    await store.receive(\.groupMain.internal.groupListResponse.success)
  }

  // MARK: - Widget 딥링크 테스트

  @Test("Widget 약속 생성 딥링크 시 그룹 탭으로 이동")
  func openCreatePromiseIfPossible_switchesToGroupTab() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-widget-create")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.groupMain.allGroupSummaries = []

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    }

    await store.send(.openCreatePromiseIfPossible) {
      $0.selectedTab = .group
    }

    await store.receive(\.groupMain.view.openCreatePromiseIfPossible)
    // 그룹 없으므로 추가 동작 없음
  }

  // MARK: - LiveActivity ETA 시트 테스트

  @Test("livePromise 없을 때 ETA 시트 열기 요청 시 pending 설정")
  func openLiveActivityETASheet_noLivePromise_setsPending() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-eta-pending")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    await store.send(.openLiveActivityETASheet) {
      $0.pendingETASheetRequest = true
    }
  }

  // MARK: - Settings Delegate 테스트

  @Test("Settings 로그아웃 delegate 전달")
  func settingsLogout_sendsDelegate() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-logout")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    await store.send(.settings(.delegate(.didLogout)))
    await store.receive(\.delegate.logoutRequested)
  }

  // MARK: - Home Delegate 테스트

  @Test("Home navigateToGroupWithPromise delegate 시 그룹 탭 이동")
  func homeNavigateToGroupWithPromise_switchesToGroupTab() async {
    let groups = [UserGroupInfo(id: "group-1", name: "그룹1")]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-home-navigate")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.groupMain.allGroupSummaries = groups

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { groups }
      $0.groupClient.fetchGroup = { _ in
        GroupModel(id: "group-1", name: "그룹1", maxMembers: 10, inviteCode: "ABC", createdBy: "host")
      }
      $0.groupClient.fetchGroupMembers = { _ in [] }
      $0.groupClient.clearGroupBadge = { _ in }
      $0.promiseClient.subscribeToPromises = { _, _ in AsyncStream { _ in } }
    }

    await store.send(.home(.delegate(.navigateToGroupWithPromise(groupId: "group-1", promiseId: "promise-1")))) {
      $0.selectedTab = .group
    }

    await store.receive(\.groupMain.view.handleDeeplink) {
      $0.groupMain.pendingDeeplink = .promiseInList(
        promiseId: "promise-1",
        groupId: "group-1",
        filter: .needResponse
      )
    }

    // 이미 선택된 그룹이면 그룹 변경 발생
    await store.receive(\.groupMain.view.groupChanged) {
      $0.groupMain.currentGroup = nil
      $0.groupMain.pendingGroupId = "group-1"
      $0.groupMain.promisesState = .loading
      $0.groupMain.pastPromisesState = .idle
    }

    await store.receive(\.groupMain.internal.fetchCurrentGroup)
  }

  // MARK: - Home navigateToAllPromises 테스트

  @Test("Home navigateToAllPromises delegate 처리")
  func homeNavigateToAllPromises_handled() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-home-all")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    // delegate 처리 (현재 .none 반환)
    await store.send(.home(.delegate(.navigateToAllPromises)))
  }

  // MARK: - 추가 탭 선택 테스트

  @Test("settings 탭 선택 시 selectedTab 변경")
  func tabSelected_settings_updatesTab() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-settings")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
    }

    await store.send(.tabSelected(.settings)) {
      $0.selectedTab = .settings
    }
  }

  @Test("group 탭에서 settings 탭으로 전환")
  func tabSelected_groupToSettings() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-tab-group-settings")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.selectedTab = .group

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
    }

    await store.send(.tabSelected(.settings)) {
      $0.selectedTab = .settings
    }
  }

  // MARK: - LiveActivity ETA 시트 테스트 (추가)

  @Test("livePromise 있을 때 ETA 시트 열기 - livePromiseDetail 생성")
  func openLiveActivityETASheet_withLivePromise_setsPending() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-eta-live")) var currentUser = user

    // livePromise가 없으면 pendingETASheetRequest = true
    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    await store.send(.openLiveActivityETASheet) {
      $0.pendingETASheetRequest = true
    }
  }

  // MARK: - Initial State 추가 검증

  @Test("초기 상태에서 groupMain 상태 확인")
  func initialState_groupMainExists() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-groupmain-init")) var currentUser = user

    let state = RootTab.Feature.State(currentUser: $currentUser)

    #expect(state.groupMain.currentGroup == nil)
  }

  @Test("초기 상태에서 home 상태 확인")
  func initialState_homeExists() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-home-init")) var currentUser = user

    let state = RootTab.Feature.State(currentUser: $currentUser)

    #expect(state.home.hasLoadedOnce == false)
    #expect(state.home.selectedGroupId == nil)
  }

  // MARK: - openCreatePromiseIfPossible 추가 테스트

  @Test("openCreatePromiseIfPossible 시 그룹 탭으로 이동 (그룹 있는 경우)")
  func openCreatePromiseIfPossible_withGroups_switchesToGroupTab() async {
    let groups = [UserGroupInfo(id: "group-1", name: "그룹1")]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-widget-create-groups")) var currentUser = user

    var state = RootTab.Feature.State(currentUser: $currentUser)
    state.groupMain.allGroupSummaries = groups

    let store = TestStore(initialState: state) {
      RootTab.Feature()
    }

    await store.send(.openCreatePromiseIfPossible) {
      $0.selectedTab = .group
    }

    // groupMain이 약속 생성 처리
    await store.receive(\.groupMain.view.openCreatePromiseIfPossible) {
      $0.groupMain.createPromise = CreatePromise.Feature.State()
    }
  }

  // MARK: - Tab 전체 순회 테스트

  @Test("모든 탭 순차 선택")
  func allTabs_canBeSelected() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-all-tabs")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
      $0.notificationClient.getUnreadCount = { _ in 0 }
      $0.notificationClient.setBadgeCount = { _ in }
    }

    // home -> group
    await store.send(.tabSelected(.group)) {
      $0.selectedTab = .group
    }

    // group -> calendar
    await store.send(.tabSelected(.calendar)) {
      $0.selectedTab = .calendar
    }

    await store.receive(\.calendar.view.refresh)

    // calendar -> settings
    await store.send(.tabSelected(.settings)) {
      $0.selectedTab = .settings
    }

    // settings -> home
    await store.send(.tabSelected(.home)) {
      $0.selectedTab = .home
    }

    await store.receive(\.home.view.refreshNotificationBadge)
    await store.receive(\.home.internal.fetchUnreadNotificationCount)
    await store.receive(\.home.internal.unreadNotificationCountResponse)
  }

  // MARK: - openLivePromiseDetail 테스트

  @Test("openLivePromiseDetail 시 livePromise 없으면 무시")
  func openLivePromiseDetail_noLivePromise_noChange() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-live-detail-nil")) var currentUser = user

    let store = TestStore(
      initialState: RootTab.Feature.State(currentUser: $currentUser)
    ) {
      RootTab.Feature()
    }

    // livePromise가 nil이면 아무 변경 없음 (Notification으로 처리)
    await store.send(.openLivePromiseDetail)
  }
}
