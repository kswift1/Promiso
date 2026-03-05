import Testing
@testable import CalendarFeature

@Suite("CalendarFeature.Feature 테스트")
@MainActor
struct CalendarFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = makeState(key: "initial")

    #expect(state.displayMode == .week)
    #expect(state.isLoadingPromises == false)
    #expect(state.isTransitioning == false)
    #expect(state.calendarPermissionStatus == .notDetermined)
    #expect(state.calendarEvents.isEmpty)
    #expect(state.cachedPromisesByMonth.isEmpty)
    #expect(state.loadedMonths.isEmpty)
  }

  // MARK: - onAppear / refresh 테스트

  @Test("onAppear 시 권한 확인과 초기 데이터 로드 시작")
  func onAppear_startsPermissionCheckAndInitialLoad() async {
    let store = makeStore(state: makeState(key: "on-appear"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear))
    await store.receive(\.internal.checkCalendarPermission)
    await store.receive(\.internal.loadInitialData)
    await store.receive(\.internal.fetchSettings)
    await store.finish()
  }

  @Test("refresh 시 권한 확인과 초기 데이터 로드 시작")
  func refresh_startsPermissionCheckAndInitialLoad() async {
    let store = makeStore(state: makeState(key: "refresh"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.refresh))
    await store.receive(\.internal.checkCalendarPermission)
    await store.receive(\.internal.loadInitialData)
    await store.finish()
  }

  // MARK: - 디스플레이 모드 전환 테스트

  @Test("toggleDisplayMode 시 주간에서 월간으로 전환 후 transition 종료")
  func toggleDisplayMode_weekToMonth_completesTransition() async {
    var state = makeState(key: "toggle-mode")
    state.loadedMonths.insert(state.selectedDate.startOfMonth)

    let store = makeStore(state: state)

    await store.send(.view(.toggleDisplayMode)) {
      $0.isTransitioning = true
      $0.displayMode = .month
    }
    await store.receive(\.internal.transitionCompleted, timeout: 5_000_000_000) {
      $0.isTransitioning = false
    }
  }

  // MARK: - 날짜 선택 / 이동 테스트

  @Test("selectDate 시 월이 바뀌면 fetchPromisesForMonth 트리거")
  func selectDate_whenMonthChanges_sendsFetchPromisesForMonth() async {
    let january = makeDate(year: 2026, month: 1, day: 15)
    let february = makeDate(year: 2026, month: 2, day: 3)

    let state = makeState(key: "select-date-month-change", selectedDate: january)
    let store = makeStore(state: state)

    await store.send(.view(.selectDate(february))) {
      $0.selectedDate = february
      $0.currentWeekStart = february.startOfWeek
    }
    await store.receive(\.internal.fetchPromisesForMonth)
  }

  @Test("moveToToday 시 selectedDate/currentWeekStart/currentMonth 동기화")
  func moveToToday_updatesCalendarAnchors() async {
    var state = makeState(
      key: "move-today",
      selectedDate: makeDate(year: 2024, month: 3, day: 10)
    )
    state.loadedMonths.insert(Date().startOfMonth)

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.moveToToday))

    #expect(Calendar.current.isDateInToday(store.state.selectedDate))
    #expect(Calendar.current.isDate(store.state.currentWeekStart, inSameDayAs: store.state.selectedDate.startOfWeek))
    #expect(Calendar.current.isDate(store.state.currentMonth, inSameDayAs: store.state.selectedDate.startOfMonth))
  }

  @Test("resetScroll 시 scrolledID 초기화")
  func resetScroll_clearsScrolledID() async {
    var state = makeState(key: "reset-scroll")
    state.scrolledID = makeDate(year: 2026, month: 1, day: 15)

    let store = makeStore(state: state)

    await store.send(.view(.resetScroll)) {
      $0.scrolledID = nil
    }
  }

  // MARK: - 약속 데이터 로드 테스트

  @Test("loadInitialData 시 현재 월만 선택적 무효화 후 약속 로드")
  func loadInitialData_withGroups_selectivelyInvalidatesAndLoadsCurrentMonth() async {
    let selectedDate = makeDate(year: 2026, month: 1, day: 20)
    let monthStart = selectedDate.startOfMonth
    let staleMonth = makeDate(year: 2025, month: 12, day: 1).startOfMonth
    let stalePromise = makePromise(id: "stale", groupId: "group-1", startAt: staleMonth)
    let recorder = PromiseRangeRecorder()

    var state = makeState(
      user: makeCurrentUser(groups: [makeGroupInfo(id: "group-1")]),
      key: "load-initial-data",
      selectedDate: selectedDate
    )
    state.cachedPromisesByMonth[staleMonth] = [stalePromise]
    state.loadedMonths.insert(staleMonth)

    let loadedPromise = makePromise(id: "loaded-1", groupId: "group-1", startAt: selectedDate)
    let store = makeStore(state: state) {
      $0.promiseClient.getPromisesByDateRange = { groupIds, startDate, endDate in
        await recorder.record(groupIds: groupIds, startDate: startDate, endDate: endDate)
        return [loadedPromise]
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 현재 월(2026-01)의 loadedMonths 항목만 제거, staleMonth(2025-12) 캐시는 유지됨
    await store.send(.internal(.loadInitialData)) {
      // loadedMonths에서 현재 월만 제거 (staleMonth는 그대로)
      $0.loadedMonths = [staleMonth]
    }
    await store.receive(\.internal.fetchPromisesForMonth)
    await store.receive(\.internal.promisesResponseForMonth)

    let requests = await recorder.values()
    #expect(requests.count == 1)
    #expect(requests.first?.groupIds == ["group-1"])
    #expect(requests.first?.startDate == monthStart)
    #expect(store.state.loadedMonths.contains(monthStart))
    // staleMonth 캐시는 삭제되지 않음
    #expect(store.state.cachedPromisesByMonth[staleMonth]?.count == 1)
    #expect(store.state.cachedPromisesByMonth[monthStart]?.count == 1)
    #expect(store.state.isLoadingPromises == false)
  }

  @Test("fetchPromisesForMonth 이미 로드된 월이면 API 호출 스킵")
  func fetchPromisesForMonth_whenAlreadyLoaded_skipsRequest() async {
    let month = makeDate(year: 2026, month: 2, day: 1).startOfMonth
    let recorder = CallCounter()

    var state = makeState(
      user: makeCurrentUser(groups: [makeGroupInfo(id: "group-1")]),
      key: "fetch-skip",
      selectedDate: month
    )
    state.loadedMonths.insert(month)

    let store = makeStore(state: state) {
      $0.promiseClient.getPromisesByDateRange = { _, _, _ in
        await recorder.increment()
        return []
      }
    }

    await store.send(.internal(.fetchPromisesForMonth(month)))
    #expect(await recorder.value() == 0)
    #expect(store.state.isLoadingPromises == false)
  }

  // MARK: - 캘린더 권한 테스트

  @Test("checkCalendarPermission fullAccess면 이벤트 로드")
  func checkCalendarPermission_fullAccess_fetchesEvents() async {
    let selectedDate = makeDate(year: 2026, month: 4, day: 10)
    let events = [
      makeCalendarEvent(
        id: "event-1",
        startDate: makeDate(year: 2026, month: 4, day: 12),
        endDate: makeDate(year: 2026, month: 4, day: 12, hour: 1)
      )
    ]

    let store = makeStore(state: makeState(key: "check-permission", selectedDate: selectedDate)) {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.fetchEvents = { _, _ in events }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.checkCalendarPermission)) {
      $0.calendarPermissionStatus = .fullAccess
    }
    await store.receive(\.internal.fetchCalendarEvents)
    await store.receive(\.internal.calendarEventsResponse)

    #expect(store.state.calendarEvents == events)
    #expect(store.state.isLoadingCalendarEvents == false)
  }

  @Test("requestCalendarPermission 허용 시 상태 업데이트 후 이벤트 로드")
  func requestCalendarPermission_granted_updatesStatusAndLoadsEvents() async {
    let events = [
      makeCalendarEvent(
        id: "event-2",
        startDate: makeDate(year: 2026, month: 5, day: 2),
        endDate: makeDate(year: 2026, month: 5, day: 2, hour: 1)
      )
    ]

    let store = makeStore(state: makeState(key: "request-permission")) {
      $0.eventKitClient.requestAccess = { true }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.fetchEvents = { _, _ in events }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.requestCalendarPermission))
    await store.receive(\.internal.calendarPermissionResponse)
    await store.receive(\.internal.fetchCalendarEvents)
    await store.receive(\.internal.calendarEventsResponse)

    #expect(store.state.calendarPermissionStatus == .fullAccess)
    #expect(store.state.calendarEvents == events)
  }

  @Test("requestCalendarPermission 거부 시 denied 상태")
  func requestCalendarPermission_denied_setsDeniedStatus() async {
    let store = makeStore(state: makeState(key: "request-permission-denied")) {
      $0.eventKitClient.requestAccess = { false }
      $0.eventKitClient.authorizationStatus = { .denied }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.requestCalendarPermission))
    await store.receive(\.internal.calendarPermissionResponse)

    #expect(store.state.calendarPermissionStatus == .denied)
    #expect(store.state.calendarEvents.isEmpty)
  }

  // MARK: - 배너 / 네비게이션 테스트

  @Test("dismissCalendarBanner 시 숨김 상태 추가")
  func dismissCalendarBanner_addsToHiddenSet() async {
    let store = makeStore(state: makeState(key: "dismiss-banner"))

    await store.send(.view(.dismissCalendarBanner(.denied))) {
      $0.hiddenCalendarBannerTypes.insert(.denied)
    }
  }

  @Test("promiseTapped 시 PromiseDetail 경로 추가")
  func promiseTapped_pushesPromiseDetailPath() async {
    let promise = makePromise(
      id: "promise-1",
      groupId: "group-1",
      startAt: makeDate(year: 2026, month: 6, day: 15)
    )

    let store = makeStore(state: makeState(key: "promise-tapped"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.promiseTapped(promise)))

    #expect(store.state.path.count == 1)
  }

  // MARK: - Internal 액션 테스트

  @Test("transitionCompleted 시 isTransitioning 해제")
  func transitionCompleted_clearsTransitionFlag() async {
    var state = makeState(key: "transition-completed")
    state.isTransitioning = true

    let store = makeStore(state: state)

    await store.send(.internal(.transitionCompleted)) {
      $0.isTransitioning = false
    }
  }

  @Test("calendarEventsResponse 실패 시 기존 이벤트 유지")
  func calendarEventsResponse_failure_preservesExistingEvents() async {
    enum TestError: Error { case failed }

    let existingEvent = makeCalendarEvent(
      id: "old-event",
      startDate: makeDate(year: 2026, month: 1, day: 1),
      endDate: makeDate(year: 2026, month: 1, day: 1, hour: 1)
    )

    var state = makeState(key: "events-failure")
    state.isLoadingCalendarEvents = true
    state.calendarEvents = [existingEvent]

    let store = makeStore(state: state)

    // 실패 시 기존 calendarEvents 유지 (빈 배열로 덮어쓰지 않음)
    await store.send(.internal(.calendarEventsResponse(.failure(TestError.failed)))) {
      $0.isLoadingCalendarEvents = false
      // calendarEvents는 변경 없음
    }

    #expect(store.state.calendarEvents == [existingEvent])
  }
}

// MARK: - Helpers

private extension CalendarFeatureTests {

  actor CallCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
  }

  actor PromiseRangeRecorder {
    struct Request: Equatable {
      var groupIds: [String]
      var startDate: Date
      var endDate: Date
    }

    private var requests: [Request] = []

    func record(groupIds: [String], startDate: Date, endDate: Date) {
      requests.append(Request(groupIds: groupIds, startDate: startDate, endDate: endDate))
    }

    func values() -> [Request] { requests }
  }

  func makeStore(
    state: CalendarFeature.Feature.State,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<CalendarFeature.Feature> {
    TestStore(initialState: state) {
      CalendarFeature.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
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

  func makeGroupInfo(
    id: String,
    name: String = "테스트 그룹"
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name)
  }

  func makeState(
    user: UserPrivateModel? = nil,
    key: String,
    selectedDate: Date = makeDate(year: 2026, month: 1, day: 15)
  ) -> CalendarFeature.Feature.State {
    let resolvedUser = user ?? makeCurrentUser()
    @Shared(.inMemory("calendar-feature-\(key)")) var currentUser = resolvedUser
    return CalendarFeature.Feature.State(currentUser: $currentUser, selectedDate: selectedDate)
  }

  func makePromise(
    id: String,
    groupId: String,
    startAt: Date
  ) -> PromiseModel {
    PromiseModel.mock(
      id: id,
      title: "테스트 약속",
      hostId: "host-1",
      groupId: groupId,
      startAt: startAt
    )
  }

  func makeCalendarEvent(
    id: String,
    startDate: Date,
    endDate: Date
  ) -> CalendarEvent {
    CalendarEvent(
      id: id,
      title: "회의",
      startDate: startDate,
      endDate: endDate,
      location: nil,
      isAllDay: false,
      calendarName: "테스트",
      calendarColorHex: "#007AFF"
    )
  }

  nonisolated static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    let components = DateComponents(
      calendar: Calendar(identifier: .gregorian),
      timeZone: TimeZone(secondsFromGMT: 0),
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute
    )
    return components.date ?? Date(timeIntervalSince1970: 0)
  }

  func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    Self.makeDate(year: year, month: month, day: day, hour: hour, minute: minute)
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.eventKitClient.authorizationStatus = { .notDetermined }
    deps.eventKitClient.requestAccess = { false }
    deps.eventKitClient.fetchEvents = { _, _ in [] }
    deps.promiseClient.getPromisesByDateRange = { _, _, _ in [] }
    deps.personalEventClient.getActiveEvents = { _ in [] }
    deps.userSettingsClient.fetchSettings = { _ in
      UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent, plan: .free)
    }
    deps.userDefaultsClient.setString = { _, _ in }
    deps.userDefaultsClient.stringForKey = { _ in nil }
  }
}
