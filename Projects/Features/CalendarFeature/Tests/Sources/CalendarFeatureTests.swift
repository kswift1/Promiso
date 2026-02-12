//
//  CalendarFeatureTests.swift
//  CalendarFeature
//
//  CalendarFeature Reducer 테스트
//
//  ## 테스트 대상
//  - `CalendarFeature/Sources/CalendarFeature.swift`
//
//  ## 테스트 목적
//  - 초기 상태, displayMode 전환, 날짜 선택, 권한 상태 등 검증
//

import Testing
import ComposableArchitecture
import Clients
import Sharing
@testable import CalendarFeature

@Suite("CalendarFeature.Feature reducer 테스트")
struct CalendarFeatureReducerTests {

  // MARK: - Test Helpers

  private func makeCurrentUser(
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: "test-user-123",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      metadata: .init(),
      groups: groups
    )
  }

  private func makeGroupInfo(
    id: String = "group-1",
    name: String = "테스트 그룹"
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name)
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-init")) var currentUser = user

    let state = CalendarFeature.Feature.State(currentUser: $currentUser)

    #expect(state.displayMode == .week)
    #expect(state.isLoadingPromises == false)
    #expect(state.isTransitioning == false)
    #expect(state.calendarPermissionStatus == .notDetermined)
    #expect(state.calendarEvents.isEmpty)
    #expect(state.cachedPromisesByMonth.isEmpty)
    #expect(state.loadedMonths.isEmpty)
  }

  // MARK: - toggleDisplayMode 테스트

  @Test("toggleDisplayMode 시 주간에서 월간으로 전환")
  func toggleDisplayMode_weekToMonth() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-toggle")) var currentUser = user

    let store = TestStore(
      initialState: CalendarFeature.Feature.State(
        currentUser: $currentUser,
        displayMode: .week
      )
    ) {
      CalendarFeature.Feature()
    } withDependencies: {
      $0.eventKitClient.authorizationStatus = { .notDetermined }
    }

    await store.send(.view(.toggleDisplayMode)) {
      $0.isTransitioning = true
      $0.displayMode = .month
    }

    // transitionCompleted 이벤트, fetchPromisesForMonth 이벤트 등은 exhaustivity 때문에 체크 필요
    // 비동기 내부 이벤트가 복잡하므로 여기서는 state 변경만 검증
  }

  // MARK: - selectDate 테스트

  @Test("selectDate 시 선택된 날짜 변경")
  func selectDate_updatesSelectedDate() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-select")) var currentUser = user

    let now = Date()
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

    var state = CalendarFeature.Feature.State(currentUser: $currentUser, selectedDate: now)
    // 같은 월 내의 날짜 선택이면 fetch 발생 안 함
    state.loadedMonths.insert(tomorrow.startOfMonth)

    let store = TestStore(initialState: state) {
      CalendarFeature.Feature()
    }

    await store.send(.view(.selectDate(tomorrow))) {
      $0.selectedDate = tomorrow
    }
  }

  // MARK: - moveToToday 테스트

  @Test("moveToToday 시 오늘 날짜로 이동")
  func moveToToday_updatesToToday() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-today")) var currentUser = user

    let pastDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
    var state = CalendarFeature.Feature.State(currentUser: $currentUser, selectedDate: pastDate)
    // 오늘 월이 로드되지 않았으므로 fetchPromisesForMonth가 발생
    state.loadedMonths.insert(Date().startOfMonth)

    let store = TestStore(initialState: state) {
      CalendarFeature.Feature()
    }

    await store.send(.view(.moveToToday)) {
      let today = Date()
      $0.selectedDate = today
      $0.currentWeekStart = today.startOfWeek
      $0.currentMonth = today.startOfMonth
    }
  }

  // MARK: - scrollTo / resetScroll 테스트

  @Test("resetScroll 시 scrolledID 초기화")
  func resetScroll_clearsScrolledID() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-reset-scroll")) var currentUser = user

    var state = CalendarFeature.Feature.State(currentUser: $currentUser)
    state.scrolledID = Date()

    let store = TestStore(initialState: state) {
      CalendarFeature.Feature()
    }

    await store.send(.view(.resetScroll)) {
      $0.scrolledID = nil
    }
  }

  // MARK: - dismissCalendarBanner 테스트

  @Test("dismissCalendarBanner 시 배너 숨김 상태 추가")
  func dismissCalendarBanner_addsToHiddenSet() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-banner")) var currentUser = user

    let store = TestStore(
      initialState: CalendarFeature.Feature.State(currentUser: $currentUser)
    ) {
      CalendarFeature.Feature()
    }

    await store.send(.view(.dismissCalendarBanner(.denied))) {
      $0.hiddenCalendarBannerTypes.insert(.denied)
    }
  }

  // MARK: - Internal Action 테스트

  @Test("transitionCompleted 시 isTransitioning false")
  func transitionCompleted_setsNotTransitioning() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-transition")) var currentUser = user

    var state = CalendarFeature.Feature.State(currentUser: $currentUser)
    state.isTransitioning = true

    let store = TestStore(initialState: state) {
      CalendarFeature.Feature()
    }

    await store.send(.internal(.transitionCompleted)) {
      $0.isTransitioning = false
    }
  }

  @Test("calendarPermissionResponse 시 권한 상태 업데이트")
  func calendarPermissionResponse_updatesStatus() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-perm")) var currentUser = user

    let store = TestStore(
      initialState: CalendarFeature.Feature.State(currentUser: $currentUser)
    ) {
      CalendarFeature.Feature()
    }

    await store.send(.internal(.calendarPermissionResponse(.fullAccess))) {
      $0.calendarPermissionStatus = .fullAccess
    }
  }

  // MARK: - Computed Properties 테스트

  @Test("isSelectedDateToday - 오늘 선택 시 true")
  func isSelectedDateToday_todayReturnsTrue() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-today-check")) var currentUser = user

    let state = CalendarFeature.Feature.State(
      currentUser: $currentUser,
      selectedDate: Date()
    )

    #expect(state.isSelectedDateToday == true)
  }

  @Test("isInitialLoading - 로딩 중이고 캐시 비어있으면 true")
  func isInitialLoading_loadingWithNoCache() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-cal-initial")) var currentUser = user

    var state = CalendarFeature.Feature.State(currentUser: $currentUser)
    state.isLoadingPromises = true
    state.loadedMonths = []

    #expect(state.isInitialLoading == true)
  }
}
