import Testing
@testable import CalendarFeature

@Suite("CalendarFeature.Feature 테스트")
@MainActor
struct CalendarFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = makeState(key: "initial")

    #expect(state.displayMode == .month)
    #expect(state.isLoadingSchedules == false)
    #expect(state.isTransitioning == false)
    #expect(state.calendarPermissionStatus == .notDetermined)
    #expect(state.cachedCalendarEventsByMonth.isEmpty)
    #expect(state.loadedCalendarEventMonths.isEmpty)
    #expect(state.cachedSchedulesByMonth.isEmpty)
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
    await store.receive(\.internal.fetchRecurringEvents)
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

  @Test("toggleDisplayMode 시 월간→월간확장→주간→월간 순환 전환")
  func toggleDisplayMode_cyclesThroughAllModes() async {
    var state = makeState(key: "toggle-mode")
    state.loadedMonths.insert(state.selectedDate.startOfMonth)
    state.loadedPersonalEventMonths.insert(state.selectedDate.startOfMonth)

    let store = makeStore(state: state)

    // month → monthExpanded
    await store.send(.view(.toggleDisplayMode)) {
      $0.isTransitioning = true
      $0.displayMode = .monthExpanded
    }
    await store.receive(\.internal.transitionCompleted, timeout: 5_000_000_000) {
      $0.isTransitioning = false
    }

    // monthExpanded → week
    await store.send(.view(.toggleDisplayMode)) {
      $0.isTransitioning = true
      $0.displayMode = .week
      $0.currentWeekStart = $0.selectedDate.startOfWeek
    }
    await store.receive(\.internal.transitionCompleted) {
      $0.isTransitioning = false
    }

    // week → month
    await store.send(.view(.toggleDisplayMode)) {
      $0.isTransitioning = true
      $0.displayMode = .month
    }
    await store.receive(\.internal.transitionCompleted) {
      $0.isTransitioning = false
    }
  }

  @Test("setDisplayMode 시 직접 모드 지정")
  func setDisplayMode_directlyChangesMode() async {
    var state = makeState(key: "set-mode")
    state.loadedMonths.insert(state.selectedDate.startOfMonth)
    state.loadedPersonalEventMonths.insert(state.selectedDate.startOfMonth)

    let store = makeStore(state: state)

    // week → monthExpanded 직접 지정
    await store.send(.view(.setDisplayMode(.monthExpanded))) {
      $0.isTransitioning = true
      $0.displayMode = .monthExpanded
    }
    await store.receive(\.internal.transitionCompleted) {
      $0.isTransitioning = false
    }
  }

  // MARK: - 날짜 선택 / 이동 테스트

  @Test("selectDate 시 월이 바뀌면 fetchSchedulesForMonth 및 fetchPersonalEventsForMonth 트리거")
  func selectDate_whenMonthChanges_sendsFetchSchedulesForMonth() async {
    let january = makeDate(year: 2026, month: 1, day: 15)
    let february = makeDate(year: 2026, month: 2, day: 3)

    let state = makeState(key: "select-date-month-change", selectedDate: january)
    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.selectDate(february))) {
      $0.selectedDate = february
      // month 모드에서는 currentWeekStart/currentMonth 직접 업데이트 안 함 (monthPageChanged가 담당)
    }
    await store.receive(\.internal.fetchSchedulesForMonth)
    await store.receive(\.internal.fetchPersonalEventsForMonth)
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

  @Test("weekRowIndex는 월요일 시작 설정을 반영한다")
  func weekRowIndex_respectsMondayStartSetting() {
    let currentMonth = makeDate(year: 2026, month: 3, day: 1)
    let selectedDate = makeDate(year: 2026, month: 3, day: 7)

    #expect(CalendarFeature.weekRowIndex(
      currentMonth: currentMonth,
      selectedDate: selectedDate,
      startOnMonday: true
    ) == 1)
    #expect(CalendarFeature.weekRowIndex(
      currentMonth: currentMonth,
      selectedDate: selectedDate,
      startOnMonday: false
    ) == 0)
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

  @Test("월간 리스트는 타입과 무관하게 날짜 기준으로 통합 정렬")
  func compactDayRowItems_sortsAcrossScheduleTypes() {
    let date = makeDate(year: 2026, month: 3, day: 6)
    let overnightTrip = makePersonalEvent(
      id: "personal-trip",
      title: "출장",
      startAt: makeDate(year: 2026, month: 3, day: 3, hour: 10, minute: 25),
      endAt: makeDate(year: 2026, month: 3, day: 7, hour: 11, minute: 25)
    )
    let earlySchedule = makeSchedule(
      id: "schedule-early",
      groupId: "group-1",
      startAt: makeDate(year: 2026, month: 3, day: 6, hour: 4, minute: 43)
    )
    let lateSchedule = makeSchedule(
      id: "schedule-late",
      groupId: "group-1",
      startAt: makeDate(year: 2026, month: 3, day: 6, hour: 6, minute: 50)
    )

    let items = CompactDayRowItem.sortedItems(
      for: date,
      schedules: [lateSchedule, earlySchedule],
      calendarEvents: [],
      personalEvents: [overnightTrip]
    )

    #expect(items == [
      .personalEvent(overnightTrip),
      .schedule(earlySchedule),
      .schedule(lateSchedule)
    ])
  }

  // MARK: - 일정 데이터 로드 테스트

  @Test("loadInitialData 시 현재 월만 선택적 무효화 후 일정 로드")
  func loadInitialData_withGroups_selectivelyInvalidatesAndLoadsCurrentMonth() async {
    let selectedDate = makeDate(year: 2026, month: 1, day: 20)
    let monthStart = selectedDate.startOfMonth
    let staleMonth = makeDate(year: 2025, month: 12, day: 1).startOfMonth
    let staleSchedule = makeSchedule(id: "stale", groupId: "group-1", startAt: staleMonth)
    let recorder = ScheduleRangeRecorder()

    var state = makeState(
      user: makeCurrentUser(groups: [makeGroupInfo(id: "group-1")]),
      key: "load-initial-data",
      selectedDate: selectedDate
    )
    state.cachedSchedulesByMonth[staleMonth] = [staleSchedule]
    state.loadedMonths.insert(staleMonth)
    state.loadedPersonalEventMonths.insert(staleMonth)

    let loadedSchedule = makeSchedule(id: "loaded-1", groupId: "group-1", startAt: selectedDate)
    let store = makeStore(state: state) {
      $0.scheduleClient.getSchedulesByDateRange = { groupIds, startDate, endDate in
        await recorder.record(groupIds: groupIds, startDate: startDate, endDate: endDate)
        return [loadedSchedule]
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 현재 월(2026-01)의 loadedMonths 항목만 제거, staleMonth(2025-12) 캐시는 유지됨
    await store.send(.internal(.loadInitialData)) {
      // loadedMonths에서 현재 월만 제거 (staleMonth는 그대로)
      $0.loadedMonths = [staleMonth]
    }
    // 동기 액션: 현재 월 fetch → 프리페치 → 인접 월 fetch
    await store.receive(\.internal.fetchPersonalEventsForMonth)
    await store.receive(\.internal.fetchSchedulesForMonth)
    await store.receive(\.internal.prefetchAdjacentMonths)
    await store.receive(\.internal.fetchSchedulesForMonth)
    await store.receive(\.internal.fetchPersonalEventsForMonth)
    // 비동기 응답 순서는 비결정적이므로 응답을 모두 흘려보낸 뒤 최종 상태만 검증
    await store.skipReceivedActions()

    let requests = await recorder.values()
    // 현재 월(2026-01) + 프리페치 다음 월(2026-02), staleMonth(2025-12)는 이미 로드됨
    #expect(requests.count == 2)
    #expect(requests.first?.groupIds == ["group-1"])
    #expect(requests.first?.startDate == monthStart)
    #expect(store.state.loadedMonths.contains(monthStart))
    // staleMonth 캐시는 삭제되지 않음
    #expect(store.state.cachedSchedulesByMonth[staleMonth]?.count == 1)
    #expect(store.state.cachedSchedulesByMonth[monthStart]?.count == 1)
    #expect(store.state.isLoadingSchedules == false)
  }

  @Test("fetchSchedulesForMonth 이미 로드된 월이면 API 호출 스킵")
  func fetchSchedulesForMonth_whenAlreadyLoaded_skipsRequest() async {
    let month = makeDate(year: 2026, month: 2, day: 1).startOfMonth
    let recorder = CallCounter()

    var state = makeState(
      user: makeCurrentUser(groups: [makeGroupInfo(id: "group-1")]),
      key: "fetch-skip",
      selectedDate: month
    )
    state.loadedMonths.insert(month)

    let store = makeStore(state: state) {
      $0.scheduleClient.getSchedulesByDateRange = { _, _, _ in
        await recorder.increment()
        return []
      }
    }

    await store.send(.internal(.fetchSchedulesForMonth(month)))
    #expect(await recorder.value() == 0)
    #expect(store.state.isLoadingSchedules == false)
  }

  // MARK: - 캘린더 권한 테스트

  @Test("checkCalendarPermission fullAccess면 이벤트 로드")
  func checkCalendarPermission_fullAccess_fetchesEvents() async {
    let selectedDate = makeDate(year: 2026, month: 4, day: 10)
    let monthStart = selectedDate.startOfMonth
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
    await store.receive(\.internal.fetchCalendarEventsForMonth)
    await store.receive(\.internal.calendarEventsResponseForMonth)

    #expect(store.state.cachedCalendarEventsByMonth[monthStart] == events)
    #expect(store.state.loadedCalendarEventMonths.contains(monthStart))
  }

  @Test("requestCalendarPermission 허용 시 상태 업데이트 후 이벤트 로드")
  func requestCalendarPermission_granted_updatesStatusAndLoadsEvents() async {
    let selectedDate = makeDate(year: 2026, month: 1, day: 15)
    let monthStart = selectedDate.startOfMonth
    let events = [
      makeCalendarEvent(
        id: "event-2",
        startDate: makeDate(year: 2026, month: 5, day: 2),
        endDate: makeDate(year: 2026, month: 5, day: 2, hour: 1)
      )
    ]

    let store = makeStore(state: makeState(key: "request-permission", selectedDate: selectedDate)) {
      $0.eventKitClient.requestAccess = { true }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.fetchEvents = { _, _ in events }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.requestCalendarPermission))
    await store.receive(\.internal.calendarPermissionResponse)
    await store.receive(\.internal.fetchCalendarEventsForMonth)
    await store.receive(\.internal.calendarEventsResponseForMonth)

    #expect(store.state.calendarPermissionStatus == .fullAccess)
    #expect(store.state.cachedCalendarEventsByMonth[monthStart] == events)
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
    #expect(store.state.cachedCalendarEventsByMonth.isEmpty)
  }

  // MARK: - 배너 / 네비게이션 테스트

  @Test("dismissCalendarBanner 시 숨김 상태 추가")
  func dismissCalendarBanner_addsToHiddenSet() async {
    let store = makeStore(state: makeState(key: "dismiss-banner"))

    await store.send(.view(.dismissCalendarBanner(.denied))) {
      $0.hiddenCalendarBannerTypes.insert(.denied)
    }
  }

  @Test("scheduleTapped 시 ScheduleDetail 경로 추가")
  func scheduleTapped_pushesScheduleDetailPath() async {
    let schedule = makeSchedule(
      id: "schedule-1",
      groupId: "group-1",
      startAt: makeDate(year: 2026, month: 6, day: 15)
    )

    let store = makeStore(state: makeState(key: "schedule-tapped"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.scheduleTapped(schedule)))

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

  @Test("calendarEventsResponseForMonth 실패 시 기존 이벤트 유지")
  func calendarEventsResponseForMonth_failure_preservesExistingEvents() async {
    enum TestError: Error { case failed }

    let month = makeDate(year: 2026, month: 1, day: 1).startOfMonth
    let existingEvent = makeCalendarEvent(
      id: "old-event",
      startDate: makeDate(year: 2026, month: 1, day: 1),
      endDate: makeDate(year: 2026, month: 1, day: 1, hour: 1)
    )

    var state = makeState(key: "events-failure")
    state.cachedCalendarEventsByMonth[month] = [existingEvent]
    state.loadedCalendarEventMonths.insert(month)

    let store = makeStore(state: state)

    // 실패 시 캐시 그대로 유지 (loadedCalendarEventMonths에 추가 안 됨 → 재시도 가능)
    let otherMonth = makeDate(year: 2026, month: 2, day: 1).startOfMonth
    await store.send(.internal(.calendarEventsResponseForMonth(month: otherMonth, .failure(TestError.failed))))

    // 기존 캐시 유지
    #expect(store.state.cachedCalendarEventsByMonth[month] == [existingEvent])
    // 실패한 월은 loadedCalendarEventMonths에 없음 (재시도 가능)
    #expect(!store.state.loadedCalendarEventMonths.contains(otherMonth))
  }

  // MARK: - 과거 시간 일정 생성 차단 테스트

  @Test("pastTimeBlocked 액션 시 경고 토스트 메시지 설정")
  func pastTimeBlocked_setsWarningToastMessage() async {
    let store = makeStore(state: makeState(key: "past-time-blocked"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.pastTimeBlocked))

    #expect(store.state.toastMessage?.type == .warning)
    #expect(store.state.toastMessage?.title == LocalizedStrings.Calendar.cannotCreatePastSchedule)
  }

  @Test("dayLongPressCreatePersonalEvent 과거 날짜 시 pastTimeBlocked 트리거")
  func dayLongPressCreatePersonalEvent_pastDate_triggersPastTimeBlocked() async {
    let pastDate = makeDate(year: 2024, month: 1, day: 1)
    let store = makeStore(state: makeState(key: "past-personal"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.dayLongPressCreatePersonalEvent(pastDate)))
    await store.receive(\.view.pastTimeBlocked)

    // 개인 일정 생성 화면이 열리지 않음
    #expect(store.state.editPersonalEvent == nil)
    #expect(store.state.toastMessage?.type == .warning)
  }

  @Test("dayLongPressCreateSchedule 과거 날짜 시 pastTimeBlocked 트리거")
  func dayLongPressCreateSchedule_pastDate_triggersPastTimeBlocked() async {
    let pastDate = makeDate(year: 2024, month: 1, day: 1)
    let store = makeStore(state: makeState(key: "past-schedule"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.dayLongPressCreateSchedule(pastDate)))
    await store.receive(\.view.pastTimeBlocked)

    // 일정 생성 화면이 열리지 않음
    #expect(store.state.createSchedule == nil)
    #expect(store.state.toastMessage?.type == .warning)
  }

  @Test("dayLongPressCreatePersonalEvent 미래 날짜 시 createPersonalEventFromTimeline 전달")
  func dayLongPressCreatePersonalEvent_futureDate_createsPersonalEvent() async {
    let futureDate = makeDate(year: 2028, month: 6, day: 15)
    let store = makeStore(state: makeState(key: "future-personal"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.dayLongPressCreatePersonalEvent(futureDate)))
    await store.receive(\.view.createPersonalEventFromTimeline)

    // 개인 일정 생성 화면이 열림
    #expect(store.state.editPersonalEvent != nil)
  }

  @Test("dayLongPressCreateSchedule 미래 날짜 시 createScheduleFromTimeline 전달")
  func dayLongPressCreateSchedule_futureDate_createsSchedule() async {
    let futureDate = makeDate(year: 2028, month: 6, day: 15)
    let store = makeStore(state: makeState(key: "future-schedule"))
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.dayLongPressCreateSchedule(futureDate)))
    await store.receive(\.view.createScheduleFromTimeline)

    // 일정 생성 화면이 열림
    #expect(store.state.createSchedule != nil)
  }
}

// MARK: - Helpers

private extension CalendarFeatureTests {

  actor CallCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
  }

  actor ScheduleRangeRecorder {
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

  func makeSchedule(
    id: String,
    groupId: String,
    startAt: Date
  ) -> ScheduleModel {
    ScheduleModel.mock(
      id: id,
      title: "테스트 일정",
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

  func makePersonalEvent(
    id: String,
    title: String = "개인 일정",
    startAt: Date,
    endAt: Date? = nil
  ) -> PersonalEventModel {
    PersonalEventModel.mock(
      id: id,
      title: title,
      startAt: startAt,
      endAt: endAt
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
    deps.scheduleClient.getSchedulesByDateRange = { _, _, _ in [] }
    deps.personalEventClient.getActiveEvents = { _ in [] }
    deps.personalEventClient.getEventsByDateRange = { _, _ in [] }
    deps.recurringPersonalEventClient.getAllEvents = { [] }
    deps.userSettingsClient.fetchSettings = { _ in
      UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
    }
    deps.userDefaultsClient.setString = { _, _ in }
    deps.userDefaultsClient.stringForKey = { _ in nil }
  }
}
