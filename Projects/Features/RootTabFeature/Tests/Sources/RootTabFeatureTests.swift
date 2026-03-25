import SwiftUI
import Testing
import PromisoShared
@testable import RootTabFeature

@Suite("RootTab.Feature 테스트")
@MainActor
struct RootTabFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = makeState(key: "initial")

    #expect(state.selectedTab == .home)
    #expect(state.liveSchedule == nil)
    #expect(state.liveScheduleDetail == nil)
    #expect(state.pendingETASheetRequest == false)
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 부트스트랩 내부 액션 시작")
  func onAppear_startsBootstrapFlow() async {
    let refreshCounter = CallCounter()
    let requestCounter = CallCounter()
    let syncRecorder = GroupIdsRecorder()

    let store = makeStore(state: makeState(key: "on-appear")) {
      $0.authClient.refreshWidgetAuthToken = {
        await refreshCounter.increment()
      }
      $0.authClient.requestWidgetToken = {
        await requestCounter.increment()
      }
      $0.calendarSyncClient.sync = { ids in
        await syncRecorder.record(ids)
        return CalendarSyncResult()
      }
      $0.calendarSyncClient.syncPersonalEvents = { _ in
        return CalendarSyncResult()
      }
    }

    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)
    await store.receive(\.internal.observeVoteActivityUpdates)
    await store.receive(\.internal.syncCalendar) {
      $0.isCalendarSyncInFlight = true
    }
    await store.receive(\.internal.observeSubscriptionStatus)
    await store.receive(\.internal.syncCalendar)
    await store.receive(\.internal.syncCalendarFinished) {
      $0.isCalendarSyncInFlight = false
      $0.hasInitialCalendarSyncBeenScheduled = true
    }
    await store.finish()

    #expect(await refreshCounter.value() == 1)
    #expect(await requestCounter.value() == 1)
    #expect(await syncRecorder.value() == Set<String>())
  }

  @Test("onAppear 시 캘린더 동기화는 최초 1회만 예약")
  func onAppear_schedulesCalendarSyncOnlyOnce() async {
    let syncCounter = CallCounter()

    let store = makeStore(state: makeState(key: "on-appear-once")) {
      $0.calendarSyncClient.sync = { _ in
        await syncCounter.increment()
        return CalendarSyncResult()
      }
      $0.calendarSyncClient.syncPersonalEvents = { _ in
        return CalendarSyncResult()
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 첫 번째 onAppear: syncCalendar 기본 1회 + 초기 예약 1회 (inflight guard로 실제 sync는 1회)
    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)
    await store.receive(\.internal.observeVoteActivityUpdates)
    await store.receive(\.internal.syncCalendar)
    await store.receive(\.internal.observeSubscriptionStatus)
    await store.receive(\.internal.syncCalendar)
    await store.receive(\.internal.syncCalendarFinished)

    // 두 번째 onAppear: syncCalendar 기본 1회만 (초기 예약은 hasInitialCalendarSyncBeenScheduled로 스킵)
    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)
    await store.receive(\.internal.observeVoteActivityUpdates)
    await store.receive(\.internal.syncCalendar)
    await store.receive(\.internal.observeSubscriptionStatus)
    await store.receive(\.internal.syncCalendarFinished)

    await store.finish()
    // 첫 번째에서 1회 + 두 번째에서 1회 = 총 2회 (초기 예약 중복은 inflight guard로 차단)
    #expect(await syncCounter.value() == 2)
  }

  // MARK: - 탭 선택 테스트

  @Test("group 탭 선택 시 selectedTab 업데이트")
  func tabSelected_group_updatesSelectedTab() async {
    let store = makeStore(state: makeState(key: "tab-group"))

    await store.send(.tabSelected(.schedule(.group))) {
      $0.selectedTab = .schedule(.group)
    }
    await store.receive(\.groupMain.view.tabReturned)
  }

  @Test("같은 탭 재선택 시 selectedTab 유지")
  func tabSelected_sameTab_keepsSelectedTab() async {
    let store = makeStore(state: makeState(key: "tab-same"))

    await store.send(.tabSelected(.home))
  }

  @Test("home 탭 선택 시 selectedTab 업데이트")
  func tabSelected_home_updatesSelectedTab() async {
    var state = makeState(key: "tab-home")
    state.selectedTab = .schedule(.group)

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.tabSelected(.home)) {
      $0.selectedTab = .home
    }
    await store.receive(\.home.view.refreshNotificationBadge)
  }

  @Test("calendar 탭 선택 시 refresh 전달")
  func tabSelected_calendar_sendsRefresh() async {
    var state = makeState(key: "tab-calendar")
    state.selectedTab = .home

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.tabSelected(.calendar)) {
      $0.selectedTab = .calendar
    }
    await store.receive(\.calendar.view.refresh)
  }

  @Test("settings 탭 선택 시 selectedTab 업데이트")
  func tabSelected_settings_updatesSelectedTab() async {
    let store = makeStore(state: makeState(key: "tab-settings"))

    await store.send(.tabSelected(.settings)) {
      $0.selectedTab = .settings
    }
  }

  // MARK: - Delegate 전달 테스트

  @Test("settings delegate didLogout 시 상위 delegate 전달")
  func settingsDidLogout_forwardsDelegate() async {
    let store = makeStore(state: makeState(key: "settings-logout"))

    await store.send(.settings(.delegate(.didLogout)))
    await store.receive(\.delegate.logoutRequested)
  }

  // MARK: - 구독 상태 테스트

  @Test("구독 상태 변경 시 shared isPro 값도 함께 동기화")
  func subscriptionStatusChanged_updatesSharedIsPro() async {
    @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro = true
    var state = makeState(key: "subscription-revoked")
    state.subscriptionStatus = .lifetime

    let store = makeStore(state: state)

    await store.send(.internal(.subscriptionStatusChanged(.revoked))) {
      $0.subscriptionStatus = .revoked
      $0.settings.subscriptionStatus = .revoked
      $isPro.withLock { $0 = false }
    }
    #expect(isPro == false)

    await store.send(.internal(.subscriptionStatusChanged(.lifetime))) {
      $0.subscriptionStatus = .lifetime
      $0.settings.subscriptionStatus = .lifetime
      $isPro.withLock { $0 = true }
    }
    #expect(isPro == true)

    await store.send(.internal(.subscriptionStatusChanged(.none))) {
      $0.subscriptionStatus = .none
      $0.settings.subscriptionStatus = .none
      $isPro.withLock { $0 = false }
    }
    #expect(isPro == false)
  }

  // MARK: - 딥링크/네비게이션 테스트

  @Test("openJoinGroupWithCode 시 그룹 탭으로 전환")
  func openJoinGroupWithCode_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "join-code"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openJoinGroupWithCode("INVITE123")) {
      $0.selectedTab = .schedule(.group)
    }
    await store.receive(\.groupMain.view.joinGroupWithCode)
  }

  @Test("handleGroupDeeplink 시 그룹 탭으로 전환")
  func handleGroupDeeplink_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "group-deeplink"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.handleGroupDeeplink(.group(groupId: "group-1"))) {
      $0.selectedTab = .schedule(.group)
    }
    await store.receive(\.groupMain.view.handleDeeplink)
  }

  @Test("openCreateScheduleIfPossible 시 그룹 탭으로 전환")
  func openCreateScheduleIfPossible_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "create-schedule"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openCreateScheduleIfPossible) {
      $0.selectedTab = .schedule(.group)
    }
    await store.receive(\.groupMain.view.openCreateScheduleIfPossible)
  }

  @Test("openPersonalEventDetail 시 개인 모드 탭 전환 후 딥링크 전달")
  func openPersonalEventDetail_switchesToPersonalModeTab() async {
    let store = makeStore(state: makeState(key: "personal-event-deeplink"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openPersonalEventDetail(eventId: "event-123")) {
      $0.scheduleMode = .own
      $0.selectedTab = .schedule(.own)
    }
    await store.receive(\.personalMode)
  }

  @Test("Home navigateToGroupWithSchedule delegate 시 그룹 탭 전환")
  func homeNavigateToGroupWithSchedule_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "home-to-group"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.home(.delegate(.navigateToGroupWithSchedule(groupId: "g-1", scheduleId: "p-1")))) {
      $0.selectedTab = .schedule(.group)
    }
    await store.receive(\.groupMain.view.handleDeeplink)
  }

  @Test("Home navigateToSchedule delegate 시 그룹 없으면 탭만 변경")
  func homeNavigateToSchedule_missingGroup_onlyChangesTab() async {
    let store = makeStore(state: makeState(key: "home-schedule-missing"))

    await store.send(.home(.delegate(.navigateToSchedule(scheduleId: "schedule-1", groupId: "missing")))) {
      $0.selectedTab = .schedule(.group)
    }
  }

  @Test("Home navigateToAllSchedules delegate 시 아무 동작 안 함")
  func homeNavigateToAllSchedules_doesNothing() async {
    let store = makeStore(state: makeState(key: "home-all-schedules"))
    await store.send(.home(.delegate(.navigateToAllSchedules)))
  }

  // MARK: - LiveSchedule 테스트

  @Test("liveSchedule 없을 때 ETA 시트 요청 시 pending 플래그 설정")
  func openLiveActivityETASheet_withoutLiveSchedule_setsPendingFlag() async {
    let store = makeStore(state: makeState(key: "eta-without-live"))

    await store.send(.openLiveActivityETASheet) {
      $0.pendingETASheetRequest = true
    }
  }

  @Test("liveSchedule 있을 때 ETA 시트 요청 시 detail 생성 후 시트 표시")
  func openLiveActivityETASheet_withLiveSchedule_opensDetailAndSheet() async {
    let state = stateWithLiveSchedule(base: makeState(key: "eta-with-live"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openLiveActivityETASheet)
    #expect(store.state.liveScheduleDetail != nil)
    await store.receive(\.internal.openETASheetAfterDelay) {
      $0.liveScheduleDetail?.isETASheetPresented = true
    }
  }

  @Test("openLiveScheduleDetail 시 liveSchedule 있으면 detail 생성")
  func openLiveScheduleDetail_withLiveSchedule_setsDetail() async {
    let state = stateWithLiveSchedule(base: makeState(key: "open-live-detail"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openLiveScheduleDetail)
    #expect(store.state.liveScheduleDetail != nil)
    await store.finish()
  }

  @Test("openLiveScheduleDetail 시 liveSchedule 없으면 pending 플래그 설정")
  func openLiveScheduleDetail_withoutLiveSchedule_setsPending() async {
    let store = makeStore(state: makeState(key: "open-live-detail-nil"))
    await store.send(.openLiveScheduleDetail) {
      $0.pendingLiveScheduleDetailRequest = true
    }
  }

  @Test("liveSchedule delegate showDetail 시 detail 생성")
  func liveScheduleShowDetail_setsDetail() async {
    let state = stateWithLiveSchedule(base: makeState(key: "delegate-show-detail"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.liveSchedule(.delegate(.showDetail)))
    #expect(store.state.liveScheduleDetail != nil)
  }

  // MARK: - 내부 액션 테스트 (Widget/Auth)

  @Test("refreshWidgetAuthToken 내부 액션 호출 시 authClient 실행")
  func refreshWidgetAuthToken_callsAuthClient() async {
    let recorder = CallCounter()
    let store = makeStore(state: makeState(key: "refresh-widget")) {
      $0.authClient.refreshWidgetAuthToken = {
        await recorder.increment()
      }
    }

    await store.send(.internal(.refreshWidgetAuthToken))
    await store.finish()
    #expect(await recorder.value() == 1)
  }

  @Test("requestWidgetToken 내부 액션 호출 시 authClient 실행")
  func requestWidgetToken_callsAuthClient() async {
    let recorder = CallCounter()
    let store = makeStore(state: makeState(key: "request-widget")) {
      $0.authClient.requestWidgetToken = {
        await recorder.increment()
      }
    }

    await store.send(.internal(.requestWidgetToken))
    await store.finish()
    #expect(await recorder.value() == 1)
  }

  // MARK: - 내부 액션 테스트 (Push Token)

  @Test("observePushToStartToken 구독 시 token 수신 후 저장")
  func observePushToStartToken_emitsAndSavesToken() async {
    let original = UserDefaults.standard.string(forKey: cacheKey)
    UserDefaults.standard.removeObject(forKey: cacheKey)
    defer { restoreCacheKey(original) }

    let recorder = TokenRecorder()

    let store = makeStore(state: makeState(key: "observe-push-token")) {
      $0.liveActivityClient.observePushToStartTokenUpdates = {
        AsyncStream { continuation in
          continuation.yield("token-1")
          continuation.finish()
        }
      }
      $0.notificationClient.saveLiveActivityPushToStartToken = { token in
        await recorder.record(token)
      }
    }

    await store.send(.internal(.observePushToStartToken))
    await store.receive(\.internal.pushToStartTokenReceived)
    await store.finish()
    #expect(await recorder.values() == ["token-1"])
  }

  @Test("pushToStartTokenReceived 중복 토큰이면 저장 생략")
  func pushToStartTokenReceived_duplicate_skipsSave() async {
    let original = UserDefaults.standard.string(forKey: cacheKey)
    UserDefaults.standard.set("same-token", forKey: cacheKey)
    defer { restoreCacheKey(original) }

    let recorder = CallCounter()

    let store = makeStore(state: makeState(key: "push-token-duplicate")) {
      $0.notificationClient.saveLiveActivityPushToStartToken = { _ in
        await recorder.increment()
      }
    }

    await store.send(.internal(.pushToStartTokenReceived("same-token")))
    await store.finish()
    #expect(await recorder.value() == 0)
  }

  // MARK: - 내부 액션 테스트 (LiveActivity)

  @Test("activityUpdateReceived active면 liveSchedule 생성")
  func activityUpdateReceived_active_setsLiveSchedule() async {
    let update = makeActiveUpdate()
    let expectedData = makeLiveData(participants: update.contentState?.participants)
    let store = makeStore(state: makeState(key: "activity-active"))

    await store.send(.internal(.activityUpdateReceived(update))) {
      $0.liveSchedule = LiveSchedule.Feature.State(data: Shared(value: expectedData))
    }
    await store.receive(\.groupMain.internal.liveActivityChanged) {
      $0.groupMain.liveActivityScheduleId = "schedule-1"
    }
  }

  @Test("activityUpdateReceived active + pendingETASheet이면 pending 소비 후 ETA 시트 열기")
  func activityUpdateReceived_active_withPendingETASheet_consumesPending() async {
    var state = makeState(key: "activity-pending-eta")
    state.pendingETASheetRequest = true
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.activityUpdateReceived(makeActiveUpdate())))
    #expect(store.state.pendingETASheetRequest == false)
    #expect(store.state.liveSchedule != nil)
    await store.finish()
  }

  @Test("activityUpdateReceived inactive면 liveSchedule 제거")
  func activityUpdateReceived_inactive_clearsLiveSchedule() async {
    let state = stateWithLiveSchedule(base: makeState(key: "activity-inactive"))
    let update = ActivityUpdate(attributes: nil, contentState: nil, activityState: .ended)
    let store = makeStore(state: state)

    await store.send(.internal(.activityUpdateReceived(update))) {
      $0.liveSchedule = nil
    }
    await store.receive(\.groupMain.internal.liveActivityChanged)
  }

  @Test("observeActivityState 스트림 있으면 activityStateChanged 전달")
  func observeActivityState_withStream_emitsStateChanged() async {
    let store = makeStore(state: makeState(key: "observe-activity-state")) {
      $0.liveActivityClient.observeActivityStateUpdates = { _ in
        AsyncStream { continuation in
          continuation.yield(.active)
          continuation.finish()
        }
      }
    }

    await store.send(.internal(.observeActivityState(activityId: "activity-1")))
    await store.receive(\.internal.activityStateChanged)
    await store.finish()
  }

  @Test("observeActivityState 스트림 nil이면 아무 동작 안 함")
  func observeActivityState_nilStream_doesNothing() async {
    let store = makeStore(state: makeState(key: "observe-activity-nil"))
    await store.send(.internal(.observeActivityState(activityId: "no-stream")))
  }

  @Test("activityStateChanged dismissed면 liveSchedule 제거")
  func activityStateChanged_dismissed_clearsLiveSchedule() async {
    let state = stateWithLiveSchedule(base: makeState(key: "activity-dismissed"))
    let store = makeStore(state: state)

    await store.send(.internal(.activityStateChanged(.dismissed))) {
      $0.liveSchedule = nil
    }
    await store.receive(\.groupMain.internal.liveActivityChanged)
  }

  @Test("activityStateChanged ended면 liveSchedule 제거")
  func activityStateChanged_ended_clearsLiveSchedule() async {
    let state = stateWithLiveSchedule(base: makeState(key: "activity-ended"))
    let store = makeStore(state: state)

    await store.send(.internal(.activityStateChanged(.ended))) {
      $0.liveSchedule = nil
    }
    await store.receive(\.groupMain.internal.liveActivityChanged)
  }

  @Test("activityStateChanged active면 아무 동작 안 함")
  func activityStateChanged_active_doesNothing() async {
    let state = stateWithLiveSchedule(base: makeState(key: "activity-active-noop"))
    let store = makeStore(state: state)
    await store.send(.internal(.activityStateChanged(.active)))
  }

  @Test("openETASheetAfterDelay 시 detail ETA 시트 표시")
  func openETASheetAfterDelay_setsPresentedFlag() async {
    let state = stateWithLiveScheduleDetail(base: stateWithLiveSchedule(base: makeState(key: "open-eta-delay")))
    let store = makeStore(state: state)

    await store.send(.internal(.openETASheetAfterDelay)) {
      $0.liveScheduleDetail?.isETASheetPresented = true
    }
    await store.finish()
  }

  // MARK: - 내부 액션 테스트 (Calendar)

  @Test("syncCalendar 시 calendarSync 활성 그룹만 동기화")
  func syncCalendar_syncsEnabledGroupsOnly() async {
    let enabled = UserGroupInfo(
      id: "group-enabled",
      name: "활성 그룹",
      notifications: GroupNotificationSettings(calendarSync: true)
    )
    let disabled = UserGroupInfo(
      id: "group-disabled",
      name: "비활성 그룹",
      notifications: GroupNotificationSettings(calendarSync: false)
    )
    let recorder = GroupIdsRecorder()
    let user = makeCurrentUser(groups: [enabled, disabled])

    let store = makeStore(state: makeState(user: user, key: "sync-calendar")) {
      $0.calendarSyncClient.sync = { ids in
        await recorder.record(ids)
        return CalendarSyncResult()
      }
    }

    await store.send(.internal(.syncCalendar)) {
      $0.isCalendarSyncInFlight = true
    }
    await store.receive(\.internal.syncCalendarFinished) {
      $0.isCalendarSyncInFlight = false
      $0.hasInitialCalendarSyncBeenScheduled = true
    }
    await store.finish()
    #expect(await recorder.value() == Set(["group-enabled"]))
  }

  @Test("syncCalendar 동시 호출 시 한 번만 실행")
  func syncCalendar_calledTwiceConcurrently_runsOnce() async {
    let counter = CallCounter()
    let gate = SyncGate()

    let store = makeStore(state: makeState(key: "sync-calendar-inflight")) {
      $0.calendarSyncClient.sync = { _ in
        await counter.increment()
        await gate.start()
        await gate.wait()
        return CalendarSyncResult()
      }
      $0.calendarSyncClient.syncPersonalEvents = { _ in
        return CalendarSyncResult()
      }
    }

    await store.send(.internal(.syncCalendar)) {
      $0.isCalendarSyncInFlight = true
    }
    await gate.waitForStart()
    await store.send(.internal(.syncCalendar))

    await gate.release()
    await store.receive(\.internal.syncCalendarFinished) {
      $0.isCalendarSyncInFlight = false
      $0.hasInitialCalendarSyncBeenScheduled = true
    }
    #expect(await counter.value() == 1)
  }

  @Test("syncCalendar 동기화 실패 후에도 in-flight 플래그가 해제됨")
  func syncCalendarError_alwaysFinishesAndAllowsRetry() async {
    let counter = CallCounter()

    let store = makeStore(state: makeState(key: "sync-calendar-error")) {
      $0.calendarSyncClient.sync = { _ in
        await counter.increment()
        throw NSError(domain: "test", code: 1)
      }
      $0.calendarSyncClient.syncPersonalEvents = { _ in
        return CalendarSyncResult()
      }
    }

    await store.send(.internal(.syncCalendar)) {
      $0.isCalendarSyncInFlight = true
    }
    await store.receive(\.internal.syncCalendarFinished) {
      $0.isCalendarSyncInFlight = false
    }
    #expect(await counter.value() == 1)

    // in-flight 플래그가 해제되었으므로 다시 호출되면 재시도 호출됨
    await store.send(.internal(.syncCalendar)) {
      $0.isCalendarSyncInFlight = true
    }
    await store.receive(\.internal.syncCalendarFinished) {
      $0.isCalendarSyncInFlight = false
    }
    #expect(await counter.value() == 2)
  }

  // MARK: - liveScheduleDetail delegate 테스트

  @Test("liveScheduleDetail updateETA 시 활성 Activity 없으면 무시")
  func liveScheduleDetailUpdateETA_withoutActiveActivity_doesNothing() async {
    let state = stateWithLiveScheduleDetail(base: stateWithLiveSchedule(base: makeState(key: "update-eta-no-activity")))
    let recorder = CallCounter()

    let store = makeStore(state: state) {
      $0.liveActivityClient.currentAttributes = { nil }
      $0.liveActivityClient.currentState = { nil }
      $0.scheduleClient.updateETA = { _, _, _ in
        await recorder.increment()
      }
    }

    await store.send(.liveScheduleDetail(.presented(.delegate(.updateETA(10)))))
    await store.finish()
    #expect(await recorder.value() == 0)
  }

  @Test("liveScheduleDetail updateETA 시 활성 Activity 있으면 API 호출")
  func liveScheduleDetailUpdateETA_withActiveActivity_callsScheduleClient() async {
    let state = stateWithLiveScheduleDetail(base: stateWithLiveSchedule(base: makeState(key: "update-eta-active")))
    let attributes = makeActivityAttributes(channelId: "channel-1")
    let contentState = makeActivityContentState()
    let recorder = ETAUpdateRecorder()

    let store = makeStore(state: state) {
      $0.liveActivityClient.currentAttributes = { attributes }
      $0.liveActivityClient.currentState = { contentState }
      $0.scheduleClient.updateETA = { channelId, participants, trackingDuration in
        await recorder.record(channelId: channelId, participants: participants, trackingDuration: trackingDuration)
      }
    }

    await store.send(.liveScheduleDetail(.presented(.delegate(.updateETA(12)))))
    await store.finish()

    let snapshot = await recorder.value()
    #expect(snapshot?.channelId == "channel-1")
    #expect(snapshot?.trackingDuration == 30)
    #expect(snapshot?.participants.first(where: { $0.id == "test-user" })?.estimatedArrivalMinutes == 12)
  }

  // MARK: - refreshSubscriptionStatus 만료 감지 + 재검증 테스트

  @Test("정상 구독 상태 (만료일 미래) - 서버 상태 그대로 반환")
  func refreshSubscription_notExpired_returnsServerStatus() async {
    let futureDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30) // 30일 후
    let serverStatus: SubscriptionStatus = .subscribed(productType: .monthly, expirationDate: futureDate)

    let store = makeStore(state: makeState(key: "refresh-not-expired")) {
      $0.subscriptionClient.fetchStatus = { serverStatus }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = serverStatus
      $0.settings.subscriptionStatus = serverStatus
    }
  }

  @Test("만료일 경과 + 로컬 StoreKit 활성 구독 확인 - 로컬 상태 우선 반영")
  func refreshSubscription_expired_localStoreKitActive_usesLocalStatus() async {
    let pastDate = Date(timeIntervalSinceNow: -60 * 60 * 24) // 1일 전
    let newFutureDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 30) // 30일 후
    let serverStatus: SubscriptionStatus = .subscribed(productType: .monthly, expirationDate: pastDate)
    let localStatus: SubscriptionStatus = .subscribed(productType: .monthly, expirationDate: newFutureDate)

    let store = makeStore(state: makeState(key: "refresh-expired-local-active")) {
      $0.subscriptionClient.fetchStatus = { serverStatus }
      $0.subscriptionClient.fetchLocalStatus = { localStatus }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = localStatus
      $0.settings.subscriptionStatus = localStatus
    }
  }

  @Test("만료일 경과 + 로컬 StoreKit 활성 구독 없음 - expired 처리")
  func refreshSubscription_expired_noLocalActive_setsExpired() async {
    let pastDate = Date(timeIntervalSinceNow: -60 * 60 * 24) // 1일 전
    let serverStatus: SubscriptionStatus = .subscribed(productType: .monthly, expirationDate: pastDate)

    let store = makeStore(state: makeState(key: "refresh-expired-no-local")) {
      $0.subscriptionClient.fetchStatus = { serverStatus }
      $0.subscriptionClient.fetchLocalStatus = { .none }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = .expired(expirationDate: pastDate)
      $0.settings.subscriptionStatus = .expired(expirationDate: pastDate)
    }
  }

  @Test("만료일 경과 + 로컬 조회 실패 - 서버 상태 그대로 사용")
  func refreshSubscription_expired_localFails_fallsBackToServerStatus() async {
    let pastDate = Date(timeIntervalSinceNow: -60 * 60 * 24) // 1일 전
    let serverStatus: SubscriptionStatus = .subscribed(productType: .monthly, expirationDate: pastDate)

    struct MockError: Error {}

    let store = makeStore(state: makeState(key: "refresh-expired-local-fail")) {
      $0.subscriptionClient.fetchStatus = { serverStatus }
      $0.subscriptionClient.fetchLocalStatus = { throw MockError() }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = serverStatus
      $0.settings.subscriptionStatus = serverStatus
    }
  }

  @Test("lifetime 구독 - 재검증 없이 그대로 반환")
  func refreshSubscription_lifetime_returnsWithoutReVerification() async {
    let store = makeStore(state: makeState(key: "refresh-lifetime")) {
      $0.subscriptionClient.fetchStatus = { .lifetime }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = .lifetime
      $0.settings.subscriptionStatus = .lifetime
    }
  }

  @Test("이미 expired 상태 - 재검증 없이 그대로 반환")
  func refreshSubscription_alreadyExpired_returnsWithoutReVerification() async {
    let expDate = Date(timeIntervalSinceNow: -60 * 60 * 24 * 7) // 7일 전

    let store = makeStore(state: makeState(key: "refresh-already-expired")) {
      $0.subscriptionClient.fetchStatus = { .expired(expirationDate: expDate) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = .expired(expirationDate: expDate)
      $0.settings.subscriptionStatus = .expired(expirationDate: expDate)
    }
  }

  @Test("gracePeriod 상태 - 재검증 없이 그대로 반환")
  func refreshSubscription_gracePeriod_returnsWithoutReVerification() async {
    let graceDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 3) // 3일 후

    let store = makeStore(state: makeState(key: "refresh-grace-period")) {
      $0.subscriptionClient.fetchStatus = { .gracePeriod(expirationDate: graceDate) }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.scenePhaseChanged(.active))
    await store.receive(\.internal.refreshSubscriptionStatus)
    await store.receive(\.internal.subscriptionStatusChanged) {
      $0.subscriptionStatus = .gracePeriod(expirationDate: graceDate)
      $0.settings.subscriptionStatus = .gracePeriod(expirationDate: graceDate)
    }
  }
}

private extension RootTabFeatureTests {
  var cacheKey: String { "lastPushToStartToken" }

  func restoreCacheKey(_ original: String?) {
    if let original {
      UserDefaults.standard.set(original, forKey: cacheKey)
    } else {
      UserDefaults.standard.removeObject(forKey: cacheKey)
    }
  }

  actor CallCounter {
    private var count = 0

    func increment() {
      count += 1
    }

    func value() -> Int {
      count
    }
  }

  actor SyncGate {
    private var started = false
    private var released = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func start() {
      started = true
      startContinuation?.resume()
      startContinuation = nil
    }

    func waitForStart() async {
      guard !started else { return }
      await withCheckedContinuation { continuation in
        startContinuation = continuation
      }
    }

    func wait() async {
      guard !released else { return }
      await withCheckedContinuation { continuation in
        releaseContinuation = continuation
      }
    }

    func release() {
      released = true
      releaseContinuation?.resume()
      releaseContinuation = nil
    }
  }

  actor TokenRecorder {
    private var tokens: [String] = []

    func record(_ token: String) {
      tokens.append(token)
    }

    func values() -> [String] {
      tokens
    }
  }

  actor GroupIdsRecorder {
    private var groupIds: Set<String> = []

    func record(_ ids: Set<String>) {
      groupIds = ids
    }

    func value() -> Set<String> {
      groupIds
    }
  }

  actor ETAUpdateRecorder {
    struct Snapshot: Equatable {
      var channelId: String
      var participants: [ParticipantState]
      var trackingDuration: Int
    }

    private var snapshot: Snapshot?

    func record(channelId: String, participants: [ParticipantState], trackingDuration: Int) {
      snapshot = Snapshot(
        channelId: channelId,
        participants: participants,
        trackingDuration: trackingDuration
      )
    }

    func value() -> Snapshot? {
      snapshot
    }
  }

  func makeStore(
    state: RootTab.Feature.State,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<RootTab.Feature> {
    TestStore(initialState: state) {
      RootTab.Feature()
    } withDependencies: {
      applyRootTabDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func makeCurrentUser(
    id: String = "test-user",
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: id,
      name: "테스트",
      nickname: "테스트유저",
      email: "\(id)@example.com",
      provider: "apple",
      metadata: .init(),
      groups: groups
    )
  }

  func makeState(
    user: UserPrivateModel? = nil,
    key: String
  ) -> RootTab.Feature.State {
    let resolvedUser = user ?? makeCurrentUser()
    @Shared(.inMemory("root-tab-\(key)")) var currentUser = resolvedUser
    return RootTab.Feature.State(currentUser: $currentUser)
  }

  func stateWithLiveSchedule(base: RootTab.Feature.State) -> RootTab.Feature.State {
    var state = base
    state.liveSchedule = LiveSchedule.Feature.State(data: Shared(value: makeLiveData()))
    return state
  }

  func stateWithLiveScheduleDetail(base: RootTab.Feature.State) -> RootTab.Feature.State {
    var state = base
    if let liveSchedule = state.liveSchedule {
      state.liveScheduleDetail = LiveSchedule.Detail.State(data: liveSchedule.$data)
    }
    return state
  }

  func makeLiveData(participants: [ParticipantState]? = nil) -> LiveSchedule.Data {
    let resolvedParticipants = participants ?? [
      ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5),
      ParticipantState(id: "user-2", name: "친구", estimatedArrivalMinutes: 8)
    ]

    return LiveSchedule.Data(
      emoji: "📍",
      title: "일정",
      location: "강남역",
      scheduledTime: Date(timeIntervalSince1970: 1_700_000_000),
      participants: resolvedParticipants,
      currentUserId: "test-user",
      trackingDurationMinutes: 30,
      hostId: "host-1",
      hostName: "호스트",
      groupName: "테스트 그룹",
      groupImageUrl: nil
    )
  }

  func makeActivityAttributes(channelId: String = "channel-1") -> ScheduleActivityAttributes {
    ScheduleActivityAttributes(
      scheduleId: "schedule-1",
      currentUserId: "test-user",
      emoji: "📍",
      title: "일정",
      location: "강남역",
      scheduledTime: Date(timeIntervalSince1970: 1_700_000_000),
      trackingDurationMinutes: 30,
      hostId: "host-1",
      hostName: "호스트",
      channelId: channelId,
      groupName: "테스트 그룹",
      groupImageUrl: nil
    )
  }

  func makeActivityContentState() -> ScheduleActivityAttributes.ContentState {
    ScheduleActivityAttributes.ContentState(
      trackingDurationMinutes: 30,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5),
        ParticipantState(id: "user-2", name: "친구", estimatedArrivalMinutes: 15)
      ]
    )
  }

  func makeActiveUpdate() -> ActivityUpdate {
    ActivityUpdate(
      attributes: makeActivityAttributes(),
      contentState: makeActivityContentState(),
      activityState: .active
    )
  }
  func applyRootTabDefaultDependencies(_ dependencies: inout DependencyValues) {
    let group = GroupModel(
      id: "default-group",
      name: "기본 그룹",
      maxMembers: 10,
      inviteCode: "DEFAULT",
      createdBy: "host"
    )
    let preview = GroupPreviewModel(group: group, members: [])

    dependencies.authClient.refreshWidgetAuthToken = {}
    dependencies.authClient.requestWidgetToken = {}

    dependencies.liveActivityClient.observePushToStartTokenUpdates = {
      AsyncStream { $0.finish() }
    }
    dependencies.liveActivityClient.observeActivityUpdates = {
      AsyncStream { $0.finish() }
    }
    dependencies.voteLiveActivityClient.observeActivityUpdates = {
      AsyncStream { $0.finish() }
    }
    dependencies.liveActivityClient.observeActivityStateUpdates = { _ in nil }
    dependencies.liveActivityClient.activeActivityId = { nil }
    dependencies.liveActivityClient.currentAttributes = { nil }
    dependencies.liveActivityClient.currentState = { nil }

    dependencies.notificationClient.saveLiveActivityPushToStartToken = { _ in }
    dependencies.notificationClient.getUnreadCount = { _ in 0 }
    dependencies.notificationClient.setBadgeCount = { _ in }

    dependencies.calendarSyncClient.sync = { _ in CalendarSyncResult() }
    dependencies.calendarSyncClient.syncPersonalEvents = { _ in CalendarSyncResult() }
    dependencies.analyticsClient.logEvent = { _, _ in }
    dependencies.eventKitClient.authorizationStatus = { .notDetermined }
    dependencies.personalEventClient.getActiveEvents = { _ in [] }
    dependencies.personalEventClient.getEvent = { _ in nil }
    dependencies.personalEventClient.getEventsByDateRange = { _, _ in [] }

    dependencies.groupClient.fetchGroupSummaries = { [] }
    dependencies.groupClient.fetchGroup = { _ in group }
    dependencies.groupClient.fetchGroupMembers = { _ in [] }
    dependencies.groupClient.previewGroup = { _ in preview }
    dependencies.groupClient.clearGroupBadge = { _ in }

    dependencies.scheduleClient.subscribeToSchedules = { _, _ in
      AsyncStream { continuation in
        continuation.finish()
      }
    }
    dependencies.scheduleClient.getPastSchedules = { _, _, _ in [] }
    dependencies.scheduleClient.updateETA = { _, _, _ in }

    dependencies.subscriptionClient.fetchStatus = { .none }
    dependencies.subscriptionClient.unifiedStatusStream = { AsyncStream { $0.finish() } }

    dependencies.appReviewClient.recordFirstLaunchIfNeeded = { }
    dependencies.appReviewClient.incrementSessionCount = { }
  }
}
