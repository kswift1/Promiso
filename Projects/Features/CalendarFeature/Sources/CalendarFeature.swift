// MARK: - CalendarFeature.swift
// 캘린더 Feature - TCA Reducer 및 메인 뷰
// 주간/월간 토글, 실제 데이터 연동

import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients
import ResourceKit
import SharedFeature
import os.log

// MARK: - Debug Logger

private let calendarLogger = Logger(subsystem: "com.promiso", category: "CalendarFeature")

/// 디버그 모드 플래그 (Release에서는 false)
#if DEBUG
private let isDebugLoggingEnabled = true
#else
private let isDebugLoggingEnabled = false
#endif

private func debugLog(_ message: String, type: OSLogType = .debug) {
  guard isDebugLoggingEnabled else { return }
  calendarLogger.log(level: type, "📅 \(message)")
}

// MARK: - Debug Formatting Helpers

private let debugDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "ko_KR")
  formatter.dateFormat = "yyyy-MM-dd"
  return formatter
}()

private let debugMonthFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "ko_KR")
  formatter.dateFormat = "yyyy년 M월"
  return formatter
}()

private func formatDate(_ date: Date) -> String {
  debugDateFormatter.string(from: date)
}

private func formatMonth(_ date: Date) -> String {
  debugMonthFormatter.string(from: date)
}

// MARK: - Calendar List Item (통합 정렬용)

/// 약속과 캘린더 이벤트를 통합하여 시간순 정렬하기 위한 타입
enum CalendarListItem: Identifiable {
  case promise(PromiseModel)
  case calendarEvent(CalendarEvent)

  var id: String {
    switch self {
    case .promise(let promise):
      return "promise_\(promise.id)"
    case .calendarEvent(let event):
      return "event_\(event.id)"
    }
  }

  var startTime: Date {
    switch self {
    case .promise(let promise):
      return promise.startAt
    case .calendarEvent(let event):
      return event.startDate
    }
  }
}

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
    public struct State {
      /// 현재 사용자 정보
      var currentUser: UserPrivateModel

      /// 표시 모드 (주간/월간)
      var displayMode: CalendarDisplayMode = .week

      /// 현재 주의 시작일
      var currentWeekStart: Date

      /// 현재 월
      var currentMonth: Date

      /// 선택된 날짜
      var selectedDate: Date

      /// 약속 데이터 (실제 서버 데이터) - 현재 표시 범위용
      var promises: [PromiseModel] = []

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

      // MARK: - Group 관련

      /// 사용자 그룹 정보 조회용 (키: groupId)
      var userGroupsMap: [String: UserGroupInfo] {
        Dictionary(uniqueKeysWithValues: currentUser.groups.map { ($0.id, $0) })
      }

      // MARK: - Navigation

      /// 네비게이션 경로 (약속 상세 등)
      var path = StackState<Path.State>()

      // MARK: - Computed Properties

      /// 현재 사용자 ID
      var currentUserId: String { currentUser.userId }

      /// 현재 사용자가 속한 그룹 ID 목록
      var userGroupIds: [String] { currentUser.groups.map { $0.id } }

      public init(
        currentUser: UserPrivateModel,
        displayMode: CalendarDisplayMode = .week,
        selectedDate: Date = Date()
      ) {
        self.currentUser = currentUser
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

          return allDates
            .filter { $0 >= monthStart && $0 < monthEnd }
            .sorted()
        }
      }

      /// 헤더 타이틀
      var headerTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if displayMode == .week {
          formatter.dateFormat = "M월 W주차"
          return formatter.string(from: currentWeekStart)
        } else {
          formatter.dateFormat = "yyyy년 M월"
          return formatter.string(from: currentMonth)
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
      }

      public enum InternalAction: Sendable {
        case transitionCompleted
        // 약속 데이터 관련 (월 단위 캐싱)
        case fetchPromisesForMonth(Date)  // 특정 월 데이터 로드
        case prefetchAdjacentMonths       // 인접 월 프리페치
        case promisesResponseForMonth(month: Date, Result<[PromiseModel], Error>)
        // EventKit 관련
        case checkCalendarPermission
        case calendarPermissionResponse(CalendarAuthorizationStatus)
        case fetchCalendarEvents
        case calendarEventsResponse(Result<[CalendarEvent], Error>)
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
        debugLog("🚀 onAppear - 약속 로드 시작 (그룹: \(state.userGroupIds.count)개)")
        let monthsToLoad = getMonthsToLoad(state: state)

        var effects: [Effect<Action>] = [
          .send(.internal(.checkCalendarPermission))
        ]

        // 그룹이 있으면 약속 데이터 로드
        if !state.userGroupIds.isEmpty {
          effects.append(contentsOf: monthsToLoad.map { month in
            Effect<Action>.send(.internal(.fetchPromisesForMonth(month)))
          })
        }

        return .merge(effects)

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
        debugLog("🔄 모드 전환 - 로드 필요 월: \(monthsToLoad.map { formatMonth($0) })")

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
          debugLog("🔄 날짜 선택으로 월 변경 - 로드 필요: \(formatMonth(newMonth))")
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
          debugLog("🔄 오늘로 이동 - 로드 필요: \(formatMonth(newMonth))")
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
        // 약속 상세 화면으로 이동
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId
        )))
        return .none

      case .promiseRespondTapped(let promise):
        // 약속 상세 화면으로 이동 (응답 가능)
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId
        )))
        return .none

      case .collapseToWeek(let date):
        guard state.displayMode == .month else { return .none }
        state.selectedDate = date
        state.currentWeekStart = date.startOfWeek
        state.displayMode = .week
        state.isTransitioning = true

        // 전환 전에 미리 스크롤 위치 설정 (애니메이션 없이 바로 해당 위치에 표시)
        let calendar = Calendar.current
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
        let calendar = Calendar.current
        let selectedWeekStart = state.selectedDate.startOfWeek
        if !calendar.isDate(selectedWeekStart, inSameDayAs: newWeekStart) {
          state.selectedDate = newWeekStart
        }
        debugLog("📆 weekPageChanged - 주 시작: \(formatDate(newWeekStart)), 선택된 날짜: \(formatDate(state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        let monthStart = newWeekStart.startOfMonth
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          debugLog("🔄 캐시 MISS - 로드 필요: \(formatMonth(monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          debugLog("✅ 캐시 HIT - 이미 로드됨: \(formatMonth(monthStart))")
        }

        // 캘린더 이벤트 로드
        if state.calendarPermissionStatus.canReadEvents {
          effects.append(.send(.internal(.fetchCalendarEvents)))
        }

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
        debugLog("📆 monthPageChanged - 월: \(formatMonth(newMonth)), 선택된 날짜: \(formatDate(state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          debugLog("🔄 캐시 MISS - 로드 필요: \(formatMonth(monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          debugLog("✅ 캐시 HIT - 이미 로드됨: \(formatMonth(monthStart))")
        }

        // 캘린더 이벤트 로드
        if state.calendarPermissionStatus.canReadEvents {
          effects.append(.send(.internal(.fetchCalendarEvents)))
        }

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return effects.isEmpty ? .none : .merge(effects)

      case .scrollTo(let date):
        // 특정 날짜로 스크롤
        guard let date = date else {
          state.scrolledID = nil
          return .none
        }
        let calendar = Calendar.current
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

      case .fetchPromisesForMonth(let month):
        let monthStart = month.startOfMonth

        // 이미 로드된 월이면 스킵
        guard !state.loadedMonths.contains(monthStart) else {
          debugLog("⏭️ fetchPromisesForMonth 스킵 - 이미 로드됨: \(formatMonth(monthStart))")
          return .none
        }

        // 그룹이 없으면 스킵
        guard !state.userGroupIds.isEmpty else {
          debugLog("⏭️ fetchPromisesForMonth 스킵 - 그룹 없음")
          return .none
        }

        state.isLoadingPromises = true
        debugLog("🌐 API 요청 시작 - \(formatMonth(monthStart))")

        // 월의 시작과 끝 계산
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let groupIds = state.userGroupIds

        return .run { [promiseClient] send in
          let startTime = Date()
          do {
            let promises = try await promiseClient.getPromisesByDateRange(groupIds, monthStart, endDate)
            let elapsed = Date().timeIntervalSince(startTime)
            debugLog("✅ API 응답 성공 - \(formatMonth(monthStart)): \(promises.count)개 약속, \(String(format: "%.2f", elapsed))초")
            await send(.internal(.promisesResponseForMonth(month: monthStart, .success(promises))))
          } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            debugLog("❌ API 응답 실패 - \(formatMonth(monthStart)): \(error.localizedDescription), \(String(format: "%.2f", elapsed))초", type: .error)
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
          debugLog("⏭️ 프리페치 스킵 - 인접 월 모두 캐시됨")
          return .none
        }

        debugLog("🔮 프리페치 시작 - \(monthsToFetch.map { formatMonth($0) })")

        // 프리페치는 백그라운드에서 조용히 실행 (로딩 표시 없음)
        return .merge(monthsToFetch.map { month in
          .send(.internal(.fetchPromisesForMonth(month)))
        })

      case .promisesResponseForMonth(let month, let result):
        state.isLoadingPromises = false

        switch result {
        case .success(let promises):
          state.cachedPromisesByMonth[month] = promises
          state.loadedMonths.insert(month)
          debugLog("💾 캐시 저장 완료 - \(formatMonth(month)): \(promises.count)개 약속")

        case .failure(let error):
          // 실패해도 재시도 가능하도록 loadedMonths에 추가하지 않음
          debugLog("⚠️ 캐시 저장 실패 - \(formatMonth(month)): \(error.localizedDescription)", type: .error)
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

// MARK: - Root View

extension CalendarFeature {

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Namespace private var calendarAnimation

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        VStack(spacing: 0) {
          // 헤더
          CalendarHeader(
            title: store.headerTitle,
            displayMode: store.displayMode,
            isSelectedDateToday: store.isSelectedDateToday,
            onToggleMode: { store.send(.view(.toggleDisplayMode), animation: .easeInOut(duration: 0.3)) },
            onMoveToToday: { store.send(.view(.moveToToday), animation: .easeInOut(duration: 0.25)) },
            onMovePrevious: { store.send(.view(.moveToPreviousPeriod), animation: .easeInOut(duration: 0.25)) },
            onMoveNext: { store.send(.view(.moveToNextPeriod), animation: .easeInOut(duration: 0.25)) }
          )

          Divider()

          // 공통 요일 헤더
          WeekdayHeader()

          // 캘린더 그리드 (주간/월간)
          calendarGridSection
            .animation(.easeInOut(duration: 0.3), value: store.displayMode)

          // 약속 리스트 (시트 스타일)
          promiseListSection
        }
        .auroraBackground()
        .onAppear {
          store.send(.view(.onAppear))
        }
      } destination: { store in
        switch store.case {
        case .promiseDetail(let promiseDetailStore):
          PromiseDetail.RootView(store: promiseDetailStore)
        }
      }
    }

    // MARK: - Calendar Grid Section

    @ViewBuilder
    private var calendarGridSection: some View {
      if store.displayMode == .week {
        // TabView 기반 주간 뷰 (네이티브 페이징)
        PagingWeekStripView(
          currentWeekStart: Binding(
            get: { store.currentWeekStart },
            set: { store.send(.view(.weekPageChanged($0))) }
          ),
          selectedDate: store.selectedDate,
          promisesByDate: store.promisesByDate,
          calendarEventsByDate: store.calendarEventsByDate,
          currentUserId: store.currentUserId,
          namespace: calendarAnimation,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .easeInOut(duration: 0.2))
          }
        )
        .padding(.vertical, 14)
        .transition(.asymmetric(
          insertion: .scale(scale: 0.95).combined(with: .opacity),
          removal: .scale(scale: 1.05).combined(with: .opacity)
        ))
      } else {
        // TabView 기반 월간 뷰 (네이티브 페이징)
        PagingMonthGridView(
          currentMonth: Binding(
            get: { store.currentMonth },
            set: { store.send(.view(.monthPageChanged($0))) }
          ),
          selectedDate: store.selectedDate,
          promisesByDate: store.promisesByDate,
          calendarEventsByDate: store.calendarEventsByDate,
          currentUserId: store.currentUserId,
          namespace: calendarAnimation,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .easeInOut(duration: 0.2))
          },
          onCollapseToWeek: { date in
            store.send(.view(.collapseToWeek(date)), animation: .easeInOut(duration: 0.3))
          }
        )
        .padding(.vertical, 12)
        .transition(.asymmetric(
          insertion: .scale(scale: 1.05).combined(with: .opacity),
          removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
      }
    }

    // MARK: - Promise List Section

    private var promiseListSection: some View {
      VStack(spacing: 0) {
        if store.displayMode == .week {
          weekScrollView
        } else {
          monthScrollView
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground))
      .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
      .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -4)
      .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Week Scroll View

    private var weekScrollView: some View {
      ScrollViewReader { proxy in
        ScrollView {
          weekPromiseListContent
        }
        .onAppear {
          // 전환 시 scrolledID가 설정되어 있으면 즉시 해당 위치로 이동 (애니메이션 없음)
          if let targetDate = store.scrolledID {
            proxy.scrollTo(targetDate, anchor: .top)
          }
        }
        .onChange(of: store.selectedDate) { _, newDate in
          guard !store.isTransitioning else { return }
          let calendar = Calendar.current
          if let targetDate = store.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: newDate) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(targetDate, anchor: .top)
            }
          }
        }
      }
    }

    // MARK: - Month Scroll View

    private var monthScrollView: some View {
      ScrollViewReader { proxy in
        ScrollView {
          monthPromiseListContent
        }
        .onChange(of: store.selectedDate) { _, newDate in
          guard !store.isTransitioning else { return }
          let calendar = Calendar.current
          if let targetDate = store.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: newDate) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(targetDate, anchor: .center)
            }
          }
        }
      }
    }

    // MARK: - Week Promise List Content

    private var weekPromiseListContent: some View {
      LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
        // 캘린더 권한 배너
        if !store.calendarPermissionStatus.canReadEvents {
          CalendarPermissionBanner(
            permissionStatus: store.calendarPermissionStatus,
            onRequestPermission: { store.send(.view(.requestCalendarPermission)) },
            onOpenSettings: { store.send(.view(.openSettings)) }
          )
          .padding(.vertical, 8)
        }

        if store.isInitialLoading {
          loadingView
        } else if store.sectionDates.isEmpty {
          emptyStateView
        } else {
          ForEach(store.sectionDates, id: \.self) { date in
            weekModeSection(for: date)
          }
        }
      }
      .padding(.bottom, 500)
    }

    // MARK: - Month Promise List Content

    private var monthPromiseListContent: some View {
      LazyVStack(spacing: 0) {
        if store.isInitialLoading {
          loadingView
        } else if store.sectionDates.isEmpty {
          emptyStateView
        } else {
          monthModeHeader
          ForEach(store.sectionDates, id: \.self) { date in
            monthModeRow(for: date)
          }
        }
      }
      .padding(.bottom, 200)
    }

    // MARK: - Week Mode Section (상세 카드)

    @ViewBuilder
    private func weekModeSection(for date: Date) -> some View {
      Section {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        let dayPromises = store.promisesByDate[dateKey] ?? []
        let dayEvents = store.calendarEventsByDate[dateKey] ?? []

        if dayPromises.isEmpty && dayEvents.isEmpty {
          EmptyDayPlaceholder(date: date)
        } else {
          // 약속과 캘린더 이벤트를 시간순으로 통합 정렬
          let sortedItems = mergeAndSortItems(promises: dayPromises, events: dayEvents)

          ForEach(sortedItems) { item in
            switch item {
            case .promise(let promise):
              PromiseCardView(
                promise: promise,
                currentUserId: store.currentUserId,
                onTap: { store.send(.view(.promiseTapped(promise))) },
                onRespond: promise.responseStatus(currentUserId: store.currentUserId) == .needResponse
                  ? { store.send(.view(.promiseRespondTapped(promise))) }
                  : nil
              )
              .padding(.horizontal, 16)
              .padding(.vertical, 6)

            case .calendarEvent(let event):
              CalendarEventCardView(
                event: event,
                onTap: {
                  // 시스템 캘린더 앱으로 이동 (선택적)
                }
              )
              .padding(.horizontal, 16)
              .padding(.vertical, 4)
            }
          }
        }
      } header: {
        DiaryStyleSectionHeader(date: date)
        .id(date)
      }
    }

    /// 약속과 캘린더 이벤트를 시간순으로 통합 정렬
    private func mergeAndSortItems(
      promises: [PromiseModel],
      events: [CalendarEvent]
    ) -> [CalendarListItem] {
      var items: [CalendarListItem] = []

      items.append(contentsOf: promises.map { CalendarListItem.promise($0) })
      items.append(contentsOf: events.map { CalendarListItem.calendarEvent($0) })

      return items.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Month Mode Header

    private var monthModeHeader: some View {
      HStack {
        Text("이번 달 일정")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(store.sectionDates.count)일")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)
    }

    // MARK: - Month Mode Row (간소화된 행)

    @ViewBuilder
    private func monthModeRow(for date: Date) -> some View {
      let calendar = Calendar.current
      let dateKey = calendar.startOfDay(for: date)
      let dayPromises = store.promisesByDate[dateKey] ?? []
      let dayEvents = store.calendarEventsByDate[dateKey] ?? []
      let isSelected = calendar.isDate(date, inSameDayAs: store.selectedDate)

      if !dayPromises.isEmpty || !dayEvents.isEmpty {
        CompactDayRow(
          date: date,
          promises: dayPromises,
          calendarEvents: dayEvents,
          isSelected: isSelected,
          currentUserId: store.currentUserId,
          onTap: {
            // 탭하면 주간 뷰로 전환
            store.send(.view(.collapseToWeek(date)), animation: .easeInOut(duration: 0.3))
          }
        )
        .id(date)
      }
    }

    // MARK: - Loading View

    private var loadingView: some View {
      VStack(spacing: 16) {
        Spacer()
          .frame(height: 60)

        ProgressView()
          .scaleEffect(1.2)
          .tint(Color.pmindigo.n500)

        Text("약속을 불러오는 중...")
          .font(.system(size: 15))
          .foregroundColor(.secondary)

        Spacer()
          .frame(height: 60)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
      VStack(spacing: 16) {
        Spacer()
          .frame(height: 60)

        Image(systemName: "calendar.badge.checkmark")
          .font(.system(size: 52, weight: .light))
          .foregroundColor(.secondary.opacity(0.6))

        Text("약속이 없습니다")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.primary)

        Text("새로운 약속을 만들어보세요")
          .font(.system(size: 15))
          .foregroundColor(.secondary)

        Spacer()
          .frame(height: 60)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 20)
    }
  }
}

// MARK: - Weekday Header (공통)

private struct WeekdayHeader: View {
  private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(weekdaySymbols, id: \.self) { symbol in
        Text(symbol)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(weekdayColor(for: symbol))
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private func weekdayColor(for symbol: String) -> Color {
    switch symbol {
    case "일": return .red.opacity(0.8)
    case "토": return .blue.opacity(0.8)
    default: return .secondary
    }
  }
}

// MARK: - Calendar Header

private struct CalendarHeader: View {
  let title: String
  let displayMode: CalendarDisplayMode
  let isSelectedDateToday: Bool
  let onToggleMode: () -> Void
  let onMoveToToday: () -> Void
  let onMovePrevious: () -> Void
  let onMoveNext: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      // 이전 버튼
      Button(action: onMovePrevious) {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 36, height: 36)
      }

      // 타이틀
      Text(title)
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(.primary)

      // 다음 버튼
      Button(action: onMoveNext) {
        Image(systemName: "chevron.right")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 36, height: 36)
      }

      Spacer()

      // 오늘 버튼
      if !isSelectedDateToday {
        Button(action: onMoveToToday) {
          Text("오늘")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color.pmindigo.n500)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.pmindigo.n500.opacity(0.1))
            .cornerRadius(8)
        }
      }

      // 주간/월간 토글
      Button(action: onToggleMode) {
        Image(systemName: displayMode == .week ? "rectangle.grid.1x2" : "rectangle.grid.3x2")
          .font(.system(size: 18))
          .foregroundColor(.primary)
          .frame(width: 36, height: 36)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

// MARK: - Cached DateFormatters

private enum DateFormatterCache {
  static let sectionHeader: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E)"
    return formatter
  }()

  static let weekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "E"
    return formatter
  }()

  static let monthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter
  }()
}

private let sharedCalendar = Calendar.current

// MARK: - Diary Style Section Header

private struct DiaryStyleSectionHeader: View {
  let date: Date

  var body: some View {
    HStack {
      Text(formattedDate)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.primary)
        .textCase(nil)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .adaptiveGlassSectionBackground()
  }

  private var formattedDate: String {
    DateFormatterCache.sectionHeader.string(from: date)
  }
}

// MARK: - Adaptive Glass Section Background

private extension View {
  @ViewBuilder
  func adaptiveGlassSectionBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular, in: .rect)
    } else {
      self
        .background(.ultraThinMaterial)
    }
  }
}

// MARK: - Rounded Corner Shape

private struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius)
    )
    return Path(path.cgPath)
  }
}

// MARK: - Visible Date Preference Key

private struct VisibleDatePreferenceKey: PreferenceKey {
  static var defaultValue: Date?
  static func reduce(value: inout Date?, nextValue: () -> Date?) {
    value = nextValue() ?? value
  }
}

// MARK: - Floating Date Header

private struct FloatingDateHeader: View {
  let date: Date

  var body: some View {
    HStack(spacing: 8) {
      Text(DateFormatterCache.weekday.string(from: date))
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.secondary)

      Text(DateFormatterCache.monthDay.string(from: date))
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.primary)

      if sharedCalendar.isDateInToday(date) {
        Text("오늘")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.pmindigo.n500)
          .cornerRadius(6)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
  }
}

// MARK: - Preview

#Preview("Calendar Feature - Week Mode") {
  let previewUser = UserPrivateModel(
    userId: "preview_user",
    name: "Preview User",
    nickname: "프리뷰",
    email: "preview@example.com",
    provider: "google",
    metadata: Metadata()
  )
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: previewUser, displayMode: .week)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}

#Preview("Calendar Feature - Month Mode") {
  let previewUser = UserPrivateModel(
    userId: "preview_user",
    name: "Preview User",
    nickname: "프리뷰",
    email: "preview@example.com",
    provider: "google",
    metadata: Metadata()
  )
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: previewUser, displayMode: .month)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}
