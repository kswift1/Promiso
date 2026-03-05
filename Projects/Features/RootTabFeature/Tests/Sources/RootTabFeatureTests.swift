import Testing
@testable import RootTabFeature

@Suite("RootTab.Feature 테스트")
@MainActor
struct RootTabFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = makeState(key: "initial")

    #expect(state.selectedTab == .home)
    #expect(state.livePromise == nil)
    #expect(state.livePromiseDetail == nil)
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

    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)
    await store.receive(\.internal.syncCalendar) {
      $0.isCalendarSyncInFlight = true
    }
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

    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)
    await store.receive(\.internal.syncCalendar)
    await store.receive(\.internal.syncCalendarFinished)

    await store.send(.onAppear)
    await store.receive(\.internal.refreshWidgetAuthToken)
    await store.receive(\.internal.requestWidgetToken)
    await store.receive(\.internal.observePushToStartToken)
    await store.receive(\.internal.observeActivityUpdates)

    await store.finish()
    #expect(await syncCounter.value() == 1)
  }

  // MARK: - 탭 선택 테스트

  @Test("group 탭 선택 시 selectedTab 업데이트")
  func tabSelected_group_updatesSelectedTab() async {
    let store = makeStore(state: makeState(key: "tab-group"))

    await store.send(.tabSelected(.promise(.group))) {
      $0.selectedTab = .promise(.group)
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
    state.selectedTab = .promise(.group)

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

  // MARK: - 딥링크/네비게이션 테스트

  @Test("openJoinGroupWithCode 시 그룹 탭으로 전환")
  func openJoinGroupWithCode_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "join-code"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openJoinGroupWithCode("INVITE123")) {
      $0.selectedTab = .promise(.group)
    }
    await store.receive(\.groupMain.view.joinGroupWithCode)
  }

  @Test("handleGroupDeeplink 시 그룹 탭으로 전환")
  func handleGroupDeeplink_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "group-deeplink"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.handleGroupDeeplink(.group(groupId: "group-1"))) {
      $0.selectedTab = .promise(.group)
    }
    await store.receive(\.groupMain.view.handleDeeplink)
  }

  @Test("openCreatePromiseIfPossible 시 그룹 탭으로 전환")
  func openCreatePromiseIfPossible_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "create-promise"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openCreatePromiseIfPossible) {
      $0.selectedTab = .promise(.group)
    }
    await store.receive(\.groupMain.view.openCreatePromiseIfPossible)
  }

  @Test("openPersonalEventDetail 시 개인 모드 탭 전환 후 딥링크 전달")
  func openPersonalEventDetail_switchesToPersonalModeTab() async {
    let store = makeStore(state: makeState(key: "personal-event-deeplink"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openPersonalEventDetail(eventId: "event-123")) {
      $0.promiseMode = .own
      $0.selectedTab = .promise(.own)
    }
    await store.receive(\.personalMode)
  }

  @Test("Home navigateToGroupWithPromise delegate 시 그룹 탭 전환")
  func homeNavigateToGroupWithPromise_switchesToGroupTab() async {
    let store = makeStore(state: makeState(key: "home-to-group"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.home(.delegate(.navigateToGroupWithPromise(groupId: "g-1", promiseId: "p-1")))) {
      $0.selectedTab = .promise(.group)
    }
    await store.receive(\.groupMain.view.handleDeeplink)
  }

  @Test("Home navigateToPromise delegate 시 그룹 없으면 탭만 변경")
  func homeNavigateToPromise_missingGroup_onlyChangesTab() async {
    let store = makeStore(state: makeState(key: "home-promise-missing"))

    await store.send(.home(.delegate(.navigateToPromise(promiseId: "promise-1", groupId: "missing")))) {
      $0.selectedTab = .promise(.group)
    }
  }

  @Test("Home navigateToAllPromises delegate 시 아무 동작 안 함")
  func homeNavigateToAllPromises_doesNothing() async {
    let store = makeStore(state: makeState(key: "home-all-promises"))
    await store.send(.home(.delegate(.navigateToAllPromises)))
  }

  // MARK: - LivePromise 테스트

  @Test("livePromise 없을 때 ETA 시트 요청 시 pending 플래그 설정")
  func openLiveActivityETASheet_withoutLivePromise_setsPendingFlag() async {
    let store = makeStore(state: makeState(key: "eta-without-live"))

    await store.send(.openLiveActivityETASheet) {
      $0.pendingETASheetRequest = true
    }
  }

  @Test("livePromise 있을 때 ETA 시트 요청 시 detail 생성 후 시트 표시")
  func openLiveActivityETASheet_withLivePromise_opensDetailAndSheet() async {
    let state = stateWithLivePromise(base: makeState(key: "eta-with-live"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openLiveActivityETASheet)
    #expect(store.state.livePromiseDetail != nil)
    await store.receive(\.internal.openETASheetAfterDelay) {
      $0.livePromiseDetail?.isETASheetPresented = true
    }
  }

  @Test("openLivePromiseDetail 시 livePromise 있으면 detail 생성")
  func openLivePromiseDetail_withLivePromise_setsDetail() async {
    let state = stateWithLivePromise(base: makeState(key: "open-live-detail"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.openLivePromiseDetail)
    #expect(store.state.livePromiseDetail != nil)
    await store.finish()
  }

  @Test("openLivePromiseDetail 시 livePromise 없으면 아무 동작 안 함")
  func openLivePromiseDetail_withoutLivePromise_doesNothing() async {
    let store = makeStore(state: makeState(key: "open-live-detail-nil"))
    await store.send(.openLivePromiseDetail)
  }

  @Test("livePromise delegate showDetail 시 detail 생성")
  func livePromiseShowDetail_setsDetail() async {
    let state = stateWithLivePromise(base: makeState(key: "delegate-show-detail"))
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.livePromise(.delegate(.showDetail)))
    #expect(store.state.livePromiseDetail != nil)
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

  @Test("activityUpdateReceived active면 livePromise 생성")
  func activityUpdateReceived_active_setsLivePromise() async {
    let update = makeActiveUpdate()
    let expectedData = makeLiveData(participants: update.contentState?.participants)
    let store = makeStore(state: makeState(key: "activity-active"))

    await store.send(.internal(.activityUpdateReceived(update))) {
      $0.livePromise = LivePromise.Feature.State(data: Shared(value: expectedData))
    }
    await store.receive(\.groupMain.internal.liveActivityChanged) {
      $0.groupMain.liveActivityPromiseId = "promise-1"
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
    #expect(store.state.livePromise != nil)
    await store.finish()
  }

  @Test("activityUpdateReceived inactive면 livePromise 제거")
  func activityUpdateReceived_inactive_clearsLivePromise() async {
    let state = stateWithLivePromise(base: makeState(key: "activity-inactive"))
    let update = ActivityUpdate(attributes: nil, contentState: nil, activityState: .ended)
    let store = makeStore(state: state)

    await store.send(.internal(.activityUpdateReceived(update))) {
      $0.livePromise = nil
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

  @Test("activityStateChanged dismissed면 livePromise 제거")
  func activityStateChanged_dismissed_clearsLivePromise() async {
    let state = stateWithLivePromise(base: makeState(key: "activity-dismissed"))
    let store = makeStore(state: state)

    await store.send(.internal(.activityStateChanged(.dismissed))) {
      $0.livePromise = nil
    }
    await store.receive(\.groupMain.internal.liveActivityChanged)
  }

  @Test("activityStateChanged ended면 livePromise 제거")
  func activityStateChanged_ended_clearsLivePromise() async {
    let state = stateWithLivePromise(base: makeState(key: "activity-ended"))
    let store = makeStore(state: state)

    await store.send(.internal(.activityStateChanged(.ended))) {
      $0.livePromise = nil
    }
    await store.receive(\.groupMain.internal.liveActivityChanged)
  }

  @Test("activityStateChanged active면 아무 동작 안 함")
  func activityStateChanged_active_doesNothing() async {
    let state = stateWithLivePromise(base: makeState(key: "activity-active-noop"))
    let store = makeStore(state: state)
    await store.send(.internal(.activityStateChanged(.active)))
  }

  @Test("openETASheetAfterDelay 시 detail ETA 시트 표시")
  func openETASheetAfterDelay_setsPresentedFlag() async {
    let state = stateWithLivePromiseDetail(base: stateWithLivePromise(base: makeState(key: "open-eta-delay")))
    let store = makeStore(state: state)

    await store.send(.internal(.openETASheetAfterDelay)) {
      $0.livePromiseDetail?.isETASheetPresented = true
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

  // MARK: - livePromiseDetail delegate 테스트

  @Test("livePromiseDetail updateETA 시 활성 Activity 없으면 무시")
  func livePromiseDetailUpdateETA_withoutActiveActivity_doesNothing() async {
    let state = stateWithLivePromiseDetail(base: stateWithLivePromise(base: makeState(key: "update-eta-no-activity")))
    let recorder = CallCounter()

    let store = makeStore(state: state) {
      $0.liveActivityClient.currentAttributes = { nil }
      $0.liveActivityClient.currentState = { nil }
      $0.promiseClient.updateETA = { _, _, _ in
        await recorder.increment()
      }
    }

    await store.send(.livePromiseDetail(.presented(.delegate(.updateETA(10)))))
    await store.finish()
    #expect(await recorder.value() == 0)
  }

  @Test("livePromiseDetail updateETA 시 활성 Activity 있으면 API 호출")
  func livePromiseDetailUpdateETA_withActiveActivity_callsPromiseClient() async {
    let state = stateWithLivePromiseDetail(base: stateWithLivePromise(base: makeState(key: "update-eta-active")))
    let attributes = makeActivityAttributes(channelId: "channel-1")
    let contentState = makeActivityContentState()
    let recorder = ETAUpdateRecorder()

    let store = makeStore(state: state) {
      $0.liveActivityClient.currentAttributes = { attributes }
      $0.liveActivityClient.currentState = { contentState }
      $0.promiseClient.updateETA = { channelId, participants, trackingDuration in
        await recorder.record(channelId: channelId, participants: participants, trackingDuration: trackingDuration)
      }
    }

    await store.send(.livePromiseDetail(.presented(.delegate(.updateETA(12)))))
    await store.finish()

    let snapshot = await recorder.value()
    #expect(snapshot?.channelId == "channel-1")
    #expect(snapshot?.trackingDuration == 30)
    #expect(snapshot?.participants.first(where: { $0.id == "test-user" })?.estimatedArrivalMinutes == 12)
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

  func stateWithLivePromise(base: RootTab.Feature.State) -> RootTab.Feature.State {
    var state = base
    state.livePromise = LivePromise.Feature.State(data: Shared(value: makeLiveData()))
    return state
  }

  func stateWithLivePromiseDetail(base: RootTab.Feature.State) -> RootTab.Feature.State {
    var state = base
    if let livePromise = state.livePromise {
      state.livePromiseDetail = LivePromise.Detail.State(data: livePromise.$data)
    }
    return state
  }

  func makeLiveData(participants: [ParticipantState]? = nil) -> LivePromise.Data {
    let resolvedParticipants = participants ?? [
      ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5),
      ParticipantState(id: "user-2", name: "친구", estimatedArrivalMinutes: 8)
    ]

    return LivePromise.Data(
      emoji: "📍",
      title: "약속",
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

  func makeActivityAttributes(channelId: String = "channel-1") -> PromiseActivityAttributes {
    PromiseActivityAttributes(
      promiseId: "promise-1",
      currentUserId: "test-user",
      emoji: "📍",
      title: "약속",
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

  func makeActivityContentState() -> PromiseActivityAttributes.ContentState {
    PromiseActivityAttributes.ContentState(
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

    dependencies.groupClient.fetchGroupSummaries = { [] }
    dependencies.groupClient.fetchGroup = { _ in group }
    dependencies.groupClient.fetchGroupMembers = { _ in [] }
    dependencies.groupClient.previewGroup = { _ in preview }
    dependencies.groupClient.clearGroupBadge = { _ in }

    dependencies.promiseClient.subscribeToPromises = { _, _ in
      AsyncStream { continuation in
        continuation.finish()
      }
    }
    dependencies.promiseClient.getPastPromises = { _, _, _ in [] }
    dependencies.promiseClient.updateETA = { _, _, _ in }
  }
}
