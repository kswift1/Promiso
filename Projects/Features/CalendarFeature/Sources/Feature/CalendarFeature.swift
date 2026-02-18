// MARK: - CalendarFeature.swift
// 캘린더 Feature - TCA Reducer

import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients
import SharedFeature

// MARK: - Feature Namespace

public enum CalendarFeature {}

// MARK: - Feature Implementation

extension CalendarFeature {

  // MARK: - Reducer

  @Reducer
  public struct Feature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 사용자 정보 (RootTab과 참조 공유)
      @Shared var currentUser: UserPrivateModel

      /// 그룹 멤버 캐시 (전역 공유, groupId → members)
      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      var groupMembersCache: [String: [UserPublicModel]] = [:]

      /// 표시 모드 (주간/월간)
      var displayMode: CalendarDisplayMode = .week

      /// 현재 주의 시작일
      var currentWeekStart: Date

      /// 현재 월
      var currentMonth: Date

      /// 선택된 날짜
      var selectedDate: Date

      /// 월별 약속 캐시 (키: 월 시작일)
      var cachedPromisesByMonth: [Date: [PromiseModel]] = [:]

      /// 이미 로드된 월 (중복 요청 방지)
      var loadedMonths: Set<Date> = []

      /// 약속 로딩 중
      var isLoadingPromises: Bool = false

      /// 주간 ↔ 월간 전환 애니메이션 진행 중
      var isTransitioning: Bool = false

      /// 스크롤 위치 (리스트에서 스크롤할 날짜)
      var scrolledID: Date?

      // MARK: - EventKit 관련 상태

      /// 시스템 캘린더 이벤트
      var calendarEvents: [CalendarEvent] = []

      /// 캘린더 권한 상태
      var calendarPermissionStatus: CalendarAuthorizationStatus = .notDetermined

      /// 캘린더 이벤트 로딩 중
      var isLoadingCalendarEvents: Bool = false

      /// 숨김 처리된 캘린더 배너 타입들
      var hiddenCalendarBannerTypes: Set<CalendarAuthorizationStatus> = []

      // MARK: - 날씨 관련

      /// 날씨 캐시 (HomeFeature와 공유)
      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

      // MARK: - 개인 일정 관련

      /// 개인 일정 목록
      var personalEvents: [PersonalEventModel] = []

      // MARK: - Group 관련

      /// 사용자 그룹 정보 조회용 (키: groupId)
      var userGroupsMap: [String: UserGroupInfo] {
        Dictionary(uniqueKeysWithValues: currentUser.groups.map { ($0.id, $0) })
      }

      // MARK: - Navigation

      /// 네비게이션 경로 (약속 상세 등)
      var path = StackState<Path.State>()
      /// 화면 토스트 메시지
      var toastMessage: ToastMessage?

      // MARK: - Computed Properties

      /// 현재 사용자 ID
      var currentUserId: String { currentUser.userId }

      /// 현재 사용자가 속한 그룹 ID 목록
      var userGroupIds: [String] { currentUser.groups.map { $0.id } }

      public init(
        currentUser: Shared<UserPrivateModel>,
        displayMode: CalendarDisplayMode = .week,
        selectedDate: Date = Date()
      ) {
        self._currentUser = currentUser
        self.displayMode = displayMode
        self.selectedDate = selectedDate
        self.currentWeekStart = selectedDate.startOfWeek
        self.currentMonth = selectedDate.startOfMonth
      }

      // MARK: - Computed Properties

      /// 현재 주의 날짜들 (일~토)
      var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
          calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)
        }
      }

      /// 날짜별로 그룹화된 약속 (현재 월 캐시에서 조회)
      var promisesByDate: [Date: [PromiseModel]] {
        let calendar = Calendar.current
        var grouped: [Date: [PromiseModel]] = [:]

        // 선택된 날짜의 월 기준으로 캐시 조회
        let currentMonthKey = selectedDate.startOfMonth
        let allPromises = cachedPromisesByMonth[currentMonthKey] ?? []

        // 날짜별 그룹화
        for promise in allPromises {
          let dateKey = calendar.startOfDay(for: promise.startAt)
          if grouped[dateKey] != nil {
            grouped[dateKey]?.append(promise)
          } else {
            grouped[dateKey] = [promise]
          }
        }

        // 시간순 정렬
        for (date, promises) in grouped {
          grouped[date] = promises.sorted { $0.startAt < $1.startAt }
        }

        return grouped
      }

      /// 날짜별로 그룹화된 캘린더 이벤트
      var calendarEventsByDate: [Date: [CalendarEvent]] {
        let calendar = Calendar.current
        var grouped: [Date: [CalendarEvent]] = [:]

        for event in calendarEvents {
          let dateKey = calendar.startOfDay(for: event.startDate)
          if grouped[dateKey] != nil {
            grouped[dateKey]?.append(event)
          } else {
            grouped[dateKey] = [event]
          }
        }

        // 시간순 정렬
        for (date, events) in grouped {
          grouped[date] = events.sorted { $0.startDate < $1.startDate }
        }

        return grouped
      }

      /// 날짜별로 그룹화된 개인 일정
      var personalEventsByDate: [Date: [PersonalEventModel]] {
        let calendar = Calendar.current
        var grouped: [Date: [PersonalEventModel]] = [:]

        for event in personalEvents {
          let dateKey = calendar.startOfDay(for: event.startAt)
          if grouped[dateKey] != nil {
            grouped[dateKey]?.append(event)
          } else {
            grouped[dateKey] = [event]
          }
        }

        for (date, events) in grouped {
          grouped[date] = events.sorted { $0.startAt < $1.startAt }
        }

        return grouped
      }

      /// 표시할 섹션 날짜들
      var sectionDates: [Date] {
        if displayMode == .week {
          return weekDates.sorted()
        } else {
          // 월간: 약속 또는 캘린더 이벤트가 있는 날짜
          let calendar = Calendar.current
          let monthStart = currentMonth.startOfMonth
          guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
          }

          var allDates = Set(promisesByDate.keys)
          allDates.formUnion(calendarEventsByDate.keys)
          allDates.formUnion(personalEventsByDate.keys)

          return allDates
            .filter { $0 >= monthStart && $0 < monthEnd }
            .sorted()
        }
      }

      /// 헤더 타이틀
      var headerTitle: String {
        if displayMode == .week {
          return KoreanDateFormatters.monthWeek.string(from: currentWeekStart)
        } else {
          return KoreanDateFormatters.yearMonth.string(from: currentMonth)
        }
      }

      /// 선택된 날짜가 오늘인지
      var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
      }

      /// 초기 로딩 중 (데이터가 없고 로딩 중일 때)
      var isInitialLoading: Bool {
        isLoadingPromises && loadedMonths.isEmpty
      }
    }

    // MARK: - Path (Navigation)

    @Reducer
    public enum Path {
      case promiseDetail(PromiseDetail.Feature)
      case personalEventDetail(PersonalEventDetail.Feature)
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case path(StackActionOf<Path>)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case toggleDisplayMode
        case selectDate(Date)
        case moveToToday
        case moveToPreviousPeriod
        case moveToNextPeriod
        case promiseTapped(PromiseModel)
        case promiseRespondTapped(PromiseModel)
        case collapseToWeek(Date)
        // TabView 페이징으로 변경된 날짜
        case weekPageChanged(Date)
        case monthPageChanged(Date)
        // 스크롤 관련
        case scrollTo(Date?)
        case resetScroll
        // EventKit 관련
        case requestCalendarPermission
        case openSettings
        case dismissCalendarBanner(CalendarAuthorizationStatus)
        // 개인 일정 탭
        case personalEventTapped(PersonalEventModel)
        // 탭 전환 시 데이터 새로고침
        case refresh
        // 토스트 닫힘
        case toastDismissed
      }

      @CasePathable
      public enum InternalAction: Sendable {
        case transitionCompleted
        // 초기화 관련
        case loadInitialData              // 캐시 초기화 + 약속 로드
        // 약속 데이터 관련 (월 단위 캐싱)
        case fetchPromisesForMonth(Date)  // 특정 월 데이터 로드
        case prefetchAdjacentMonths       // 인접 월 프리페치
        case promisesResponseForMonth(month: Date, Result<[PromiseModel], Error>)
        // EventKit 관련
        case checkCalendarPermission
        case calendarPermissionResponse(CalendarAuthorizationStatus)
        case fetchCalendarEvents
        case calendarEventsResponse(Result<[CalendarEvent], Error>)
        // 개인 일정
        case fetchPersonalEvents
        case personalEventsResponse(Result<[PersonalEventModel], Error>)
      }
    }

    // MARK: - Cancellation IDs

    private enum CancelID: Hashable {
      case fetchPromises
      case fetchCalendarEvents
    }

    // MARK: - Dependencies

    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.eventKitClient) var eventKitClient
    @Dependency(\.personalEventClient) var personalEventClient

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none
        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          // 데이터 새로고침
          let currentMonth = state.selectedDate.startOfMonth
          state.loadedMonths.remove(currentMonth)
          state.cachedPromisesByMonth.removeValue(forKey: currentMonth)
          return .send(.internal(.fetchPromisesForMonth(currentMonth)))
        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated(let promise))))):
          // 로컬 캐시 업데이트
          let monthKey = promise.startAt.startOfMonth
          if var monthPromises = state.cachedPromisesByMonth[monthKey] {
            if let index = monthPromises.firstIndex(where: { $0.id == promise.id }) {
              monthPromises[index] = promise
              state.cachedPromisesByMonth[monthKey] = monthPromises
            }
          }
          return .none
        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventDeleted)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchPersonalEvents))
        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventUpdated)))):
          return .send(.internal(.fetchPersonalEvents))
        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
    }

    // MARK: - View Action Handler

    private func handleViewAction(
      _ state: inout State,
      _ action: Action.ViewAction
    ) -> Effect<Action> {
      let calendar = Calendar.current

      switch action {
      case .onAppear:
        AppLogger.calendar.debugLog("🚀 onAppear - 캘린더 탭 진입")
        return .merge(
          .send(.internal(.checkCalendarPermission)),
          .send(.internal(.loadInitialData))
        )

      case .toggleDisplayMode:
        state.isTransitioning = true
        state.displayMode = state.displayMode == .week ? .month : .week

        // 모드 전환 시 현재 선택된 날짜 기준으로 동기화
        if state.displayMode == .week {
          state.currentWeekStart = state.selectedDate.startOfWeek
        } else {
          state.currentMonth = state.selectedDate.startOfMonth
        }

        // 월간 모드로 전환 시 해당 월 데이터 로드
        let monthsToLoad = getMonthsToLoad(state: state).filter { !state.loadedMonths.contains($0) }
        AppLogger.calendar.debugLog("🔄 모드 전환 - 로드 필요 월: \(monthsToLoad.map { KoreanDateFormatters.yearMonth.string(from: $0) })")

        var effects: [Effect<Action>] = monthsToLoad.map { month in
          .send(.internal(.fetchPromisesForMonth(month)))
        }

        effects.append(.run { send in
          try await Task.sleep(nanoseconds: 300_000_000)
          await send(.internal(.transitionCompleted))
        })

        return .merge(effects)

      case .selectDate(let date):
        let previousMonth = state.selectedDate.startOfMonth
        state.selectedDate = date
        let newMonth = date.startOfMonth

        // 월이 바뀌면 데이터 로드
        if previousMonth != newMonth && !state.loadedMonths.contains(newMonth) {
          AppLogger.calendar.debugLog("🔄 날짜 선택으로 월 변경 - 로드 필요: \(KoreanDateFormatters.yearMonth.string(from: newMonth))")
          return .send(.internal(.fetchPromisesForMonth(newMonth)))
        }
        return .none

      case .moveToToday:
        let today = Date()
        let previousMonth = state.selectedDate.startOfMonth
        state.selectedDate = today
        state.currentWeekStart = today.startOfWeek
        state.currentMonth = today.startOfMonth
        let newMonth = today.startOfMonth

        // 월이 바뀌면 데이터 로드
        if previousMonth != newMonth && !state.loadedMonths.contains(newMonth) {
          AppLogger.calendar.debugLog("🔄 오늘로 이동 - 로드 필요: \(KoreanDateFormatters.yearMonth.string(from: newMonth))")
          return .send(.internal(.fetchPromisesForMonth(newMonth)))
        }
        return .none

      case .moveToPreviousPeriod:
        let previousMonth = state.selectedDate.startOfMonth
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            state.selectedDate = newWeekStart
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: -1, to: state.currentMonth) {
            state.currentMonth = newMonth
            state.selectedDate = newMonth
          }
        }
        let newMonth = state.selectedDate.startOfMonth
        if previousMonth != newMonth && !state.loadedMonths.contains(newMonth) {
          return .send(.internal(.fetchPromisesForMonth(newMonth)))
        }
        return .none

      case .moveToNextPeriod:
        let previousMonth = state.selectedDate.startOfMonth
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            state.selectedDate = newWeekStart
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: 1, to: state.currentMonth) {
            state.currentMonth = newMonth
            state.selectedDate = newMonth
          }
        }
        let newMonth = state.selectedDate.startOfMonth
        if previousMonth != newMonth && !state.loadedMonths.contains(newMonth) {
          return .send(.internal(.fetchPromisesForMonth(newMonth)))
        }
        return .none

      case .promiseTapped(let promise):
        // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
        let groupMembers = state.groupMembersCache[promise.groupId]
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId,
          groupMembers: groupMembers
        )))
        return .none

      case .promiseRespondTapped(let promise):
        // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
        let groupMembers = state.groupMembersCache[promise.groupId]
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId,
          groupMembers: groupMembers
        )))
        return .none

      case .collapseToWeek(let date):
        guard state.displayMode == .month else { return .none }
        state.selectedDate = date
        state.currentWeekStart = date.startOfWeek
        state.displayMode = .week
        state.isTransitioning = true

        // 전환 전에 미리 스크롤 위치 설정 (애니메이션 없이 바로 해당 위치에 표시)
        let targetDate = calendar.startOfDay(for: date)
        state.scrolledID = targetDate

        return .run { send in
          try await Task.sleep(nanoseconds: 300_000_000)
          await send(.internal(.transitionCompleted))
        }

      case .weekPageChanged(let newWeekStart):
        // TabView 페이징으로 주가 변경됨
        state.currentWeekStart = newWeekStart

        // selectedDate가 이미 해당 주 내에 있으면 유지, 아니면 주의 첫날로 동기화
        let selectedWeekStart = state.selectedDate.startOfWeek
        if !calendar.isDate(selectedWeekStart, inSameDayAs: newWeekStart) {
          state.selectedDate = newWeekStart
        }
        AppLogger.calendar.debugLog("📆 weekPageChanged - 주 시작: \(KoreanDateFormatters.date.string(from: newWeekStart)), 선택된 날짜: \(KoreanDateFormatters.date.string(from: state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        let monthStart = newWeekStart.startOfMonth
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          AppLogger.calendar.debugLog("🔄 캐시 MISS - 로드 필요: \(KoreanDateFormatters.yearMonth.string(from: monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          AppLogger.calendar.debugLog("✅ 캐시 HIT - 이미 로드됨: \(KoreanDateFormatters.yearMonth.string(from: monthStart))")
        }

        // 캘린더 이벤트 로드
        if state.calendarPermissionStatus.canReadEvents {
          effects.append(.send(.internal(.fetchCalendarEvents)))
        }
        effects.append(.send(.internal(.fetchPersonalEvents)))

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return effects.isEmpty ? .none : .merge(effects)

      case .monthPageChanged(let newMonth):
        // TabView 페이징으로 월이 변경됨
        let monthStart = newMonth.startOfMonth
        state.currentMonth = monthStart

        // selectedDate가 이미 해당 월 내에 있으면 유지, 아니면 월의 첫날로 동기화
        let selectedMonthStart = state.selectedDate.startOfMonth
        if !Calendar.current.isDate(selectedMonthStart, inSameDayAs: monthStart) {
          state.selectedDate = monthStart
        }
        AppLogger.calendar.debugLog("📆 monthPageChanged - 월: \(KoreanDateFormatters.yearMonth.string(from: newMonth)), 선택된 날짜: \(KoreanDateFormatters.date.string(from: state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          AppLogger.calendar.debugLog("🔄 캐시 MISS - 로드 필요: \(KoreanDateFormatters.yearMonth.string(from: monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          AppLogger.calendar.debugLog("✅ 캐시 HIT - 이미 로드됨: \(KoreanDateFormatters.yearMonth.string(from: monthStart))")
        }

        // 캘린더 이벤트 로드
        if state.calendarPermissionStatus.canReadEvents {
          effects.append(.send(.internal(.fetchCalendarEvents)))
        }
        effects.append(.send(.internal(.fetchPersonalEvents)))

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return effects.isEmpty ? .none : .merge(effects)

      case .scrollTo(let date):
        // 특정 날짜로 스크롤
        guard let date = date else {
          state.scrolledID = nil
          return .none
        }
        if let targetDate = state.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: date) }) {
          state.scrolledID = targetDate
        }
        return .none

      case .resetScroll:
        state.scrolledID = nil
        return .none

      case .requestCalendarPermission:
        return .run { [eventKitClient] send in
          do {
            let granted = try await eventKitClient.requestAccess()
            let status = eventKitClient.authorizationStatus()
            await send(.internal(.calendarPermissionResponse(status)))
            if granted {
              await send(.internal(.fetchCalendarEvents))
            }
          } catch {
            // 에러 무시 - 권한 거부로 처리
          }
        }

      case .openSettings:
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        return .none

      case .dismissCalendarBanner(let status):
        state.hiddenCalendarBannerTypes.insert(status)
        return .none

      case .personalEventTapped(let event):
        state.path.append(.personalEventDetail(.init(event: event)))
        return .none

      case .refresh:
        // 탭 전환 시 최신 데이터 로드
        AppLogger.calendar.debugLog("🔄 refresh - 캘린더 탭 진입 (데이터 새로고침)")
        return .merge(
          .send(.internal(.checkCalendarPermission)),
          .send(.internal(.loadInitialData))
        )

      case .toastDismissed:
        state.toastMessage = nil
        return .none
      }
    }

    // MARK: - Internal Action Handler

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.InternalAction
    ) -> Effect<Action> {
      switch action {
      case .transitionCompleted:
        state.isTransitioning = false
        return .none

      case .loadInitialData:
        // 1. 캐시 초기화
        state.loadedMonths.removeAll()
        state.cachedPromisesByMonth.removeAll()
        AppLogger.calendar.debugLog("📦 초기 데이터 로드 (캐시 초기화 완료, 그룹: \(state.userGroupIds.count)개)")

        // 2. 개인 일정은 항상 로드
        var effects: [Effect<Action>] = [
          .send(.internal(.fetchPersonalEvents))
        ]

        // 3. 그룹이 있으면 약속 로드
        if !state.userGroupIds.isEmpty {
          let monthsToLoad = getMonthsToLoad(state: state)
          effects.append(contentsOf: monthsToLoad.map { month in
            Effect<Action>.send(.internal(.fetchPromisesForMonth(month)))
          })
        }

        return .merge(effects)

      case .fetchPromisesForMonth(let month):
        let monthStart = month.startOfMonth

        // 이미 로드된 월이면 스킵
        guard !state.loadedMonths.contains(monthStart) else {
          AppLogger.calendar.debugLog("⏭️ fetchPromisesForMonth 스킵 - 이미 로드됨: \(KoreanDateFormatters.yearMonth.string(from: monthStart))")
          return .none
        }

        // 그룹이 없으면 스킵
        guard !state.userGroupIds.isEmpty else {
          AppLogger.calendar.debugLog("⏭️ fetchPromisesForMonth 스킵 - 그룹 없음")
          return .none
        }

        state.isLoadingPromises = true
        AppLogger.calendar.debugLog("🌐 API 요청 시작 - \(KoreanDateFormatters.yearMonth.string(from: monthStart))")

        // 월의 시작과 끝 계산
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let groupIds = state.userGroupIds

        return .run { [promiseClient] send in
          let startTime = Date()
          do {
            let promises = try await promiseClient.getPromisesByDateRange(groupIds, monthStart, endDate)
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.calendar.debugLog("✅ API 응답 성공 - \(KoreanDateFormatters.yearMonth.string(from: monthStart)): \(promises.count)개 약속, \(String(format: "%.2f", elapsed))초")
            await send(.internal(.promisesResponseForMonth(month: monthStart, .success(promises))))
          } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.calendar.debugLog("❌ API 응답 실패 - \(KoreanDateFormatters.yearMonth.string(from: monthStart)): \(error.localizedDescription), \(String(format: "%.2f", elapsed))초", type: .error)
            await send(.internal(.promisesResponseForMonth(month: monthStart, .failure(error))))
          }
        }
        .cancellable(id: CancelID.fetchPromises, cancelInFlight: true)

      case .prefetchAdjacentMonths:
        // 선택된 날짜 기준 전/후 월 프리페치
        let calendar = Calendar.current
        let currentMonth = state.selectedDate.startOfMonth

        var monthsToFetch: [Date] = []

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)?.startOfMonth,
           !state.loadedMonths.contains(prevMonth) {
          monthsToFetch.append(prevMonth)
        }

        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)?.startOfMonth,
           !state.loadedMonths.contains(nextMonth) {
          monthsToFetch.append(nextMonth)
        }

        if monthsToFetch.isEmpty {
          AppLogger.calendar.debugLog("⏭️ 프리페치 스킵 - 인접 월 모두 캐시됨")
          return .none
        }

        AppLogger.calendar.debugLog("🔮 프리페치 시작 - \(monthsToFetch.map { KoreanDateFormatters.yearMonth.string(from: $0) })")

        // 프리페치는 백그라운드에서 조용히 실행 (로딩 표시 없음)
        return .merge(monthsToFetch.map { month in
          .send(.internal(.fetchPromisesForMonth(month)))
        })

      case .promisesResponseForMonth(let month, let result):
        state.isLoadingPromises = false

        switch result {
        case .success(let promises):
          // 그룹 정보 매핑 (UserGroupInfo + groupMembersCache → GroupModel 변환)
          let groupsDict = Dictionary(
            uniqueKeysWithValues: state.currentUser.groups.map { ($0.id, $0) }
          )
          let membersCache = state.groupMembersCache
          let promisesWithGroup = promises.map { promise in
            var mutablePromise = promise
            if let groupInfo = groupsDict[promise.groupId] {
              let memberIds = membersCache[promise.groupId]?.map(\.id) ?? []
              mutablePromise.group = GroupModel(
                id: groupInfo.id,
                name: groupInfo.name,
                imageUrl: groupInfo.imageUrl,
                memberIds: memberIds,
                maxMembers: memberIds.count,
                inviteCode: "",
                createdBy: ""
              )
            }
            return mutablePromise
          }
          state.cachedPromisesByMonth[month] = promisesWithGroup
          state.loadedMonths.insert(month)
          AppLogger.calendar.debugLog("💾 캐시 저장 완료 - \(KoreanDateFormatters.yearMonth.string(from: month)): \(promises.count)개 약속")

        case .failure(let error):
          // 실패해도 재시도 가능하도록 loadedMonths에 추가하지 않음
          AppLogger.calendar.debugLog("⚠️ 캐시 저장 실패 - \(KoreanDateFormatters.yearMonth.string(from: month)): \(error.localizedDescription)", type: .error)
        }
        return .none

      case .checkCalendarPermission:
        let status = eventKitClient.authorizationStatus()
        state.calendarPermissionStatus = status

        if status.canReadEvents {
          return .send(.internal(.fetchCalendarEvents))
        }
        return .none

      case .calendarPermissionResponse(let status):
        state.calendarPermissionStatus = status
        return .none

      case .fetchCalendarEvents:
        state.isLoadingCalendarEvents = true

        // 선택된 날짜의 월 기준으로 이벤트 조회
        let calendar = Calendar.current
        let startDate = state.selectedDate.startOfMonth
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate

        return .run { [eventKitClient] send in
          do {
            let events = try await eventKitClient.fetchEvents(startDate, endDate)
            await send(.internal(.calendarEventsResponse(.success(events))))
          } catch {
            await send(.internal(.calendarEventsResponse(.failure(error))))
          }
        }

      case .calendarEventsResponse(let result):
        state.isLoadingCalendarEvents = false
        switch result {
        case .success(let events):
          state.calendarEvents = events
        case .failure:
          state.calendarEvents = []
        }
        return .none

      case .fetchPersonalEvents:
        return .run { [personalEventClient] send in
          do {
            let events = try await personalEventClient.getActiveEvents(AppConstants.Sync.personalEventFetchLimit)
            await send(.internal(.personalEventsResponse(.success(events))))
          } catch {
            await send(.internal(.personalEventsResponse(.failure(error))))
          }
        }

      case .personalEventsResponse(let result):
        switch result {
        case .success(let events):
          state.personalEvents = events
        case .failure:
          state.personalEvents = []
        }
        return .none
      }
    }

    // MARK: - Helper Functions

    /// 현재 표시 범위에 필요한 월 목록 반환 (항상 월 단위로 관리)
    private func getMonthsToLoad(state: State) -> [Date] {
      // 선택된 날짜 기준 현재 월
      return [state.selectedDate.startOfMonth]
    }
  }
}

// MARK: - Path Conformances

extension CalendarFeature.Feature.Path.State: Equatable, Sendable {}
extension CalendarFeature.Feature.Path.Action: Sendable {}
