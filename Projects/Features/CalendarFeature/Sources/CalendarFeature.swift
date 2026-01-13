// MARK: - CalendarFeature.swift
// 캘린더 Feature - TCA Reducer 및 메인 뷰
// 주간/월간 토글, 목업 데이터 기반 UI

import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients

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
    public struct State: Equatable, Sendable {
      /// 표시 모드 (주간/월간)
      var displayMode: CalendarDisplayMode = .week

      /// 현재 주의 시작일
      var currentWeekStart: Date

      /// 현재 월
      var currentMonth: Date

      /// 선택된 날짜
      var selectedDate: Date

      /// 목업 약속 데이터
      var mockPromises: [MockPromise]

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

      public init(
        displayMode: CalendarDisplayMode = .week,
        selectedDate: Date = Date()
      ) {
        self.displayMode = displayMode
        self.selectedDate = selectedDate
        self.currentWeekStart = selectedDate.startOfWeek
        self.currentMonth = selectedDate.startOfMonth
        self.mockPromises = MockDataGenerator.generateMockPromises()
      }

      // MARK: - Computed Properties

      /// 현재 주의 날짜들 (일~토)
      var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
          calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)
        }
      }

      /// 날짜별로 그룹화된 약속
      var promisesByDate: [Date: [MockPromise]] {
        let calendar = Calendar.current
        var grouped: [Date: [MockPromise]] = [:]

        for promise in mockPromises {
          let dateKey = calendar.startOfDay(for: promise.date)
          if grouped[dateKey] != nil {
            grouped[dateKey]?.append(promise)
          } else {
            grouped[dateKey] = [promise]
          }
        }

        // 시간순 정렬
        for (date, promises) in grouped {
          grouped[date] = promises.sorted { $0.startTime < $1.startTime }
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
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case toggleDisplayMode
        case selectDate(Date)
        case moveToToday
        case moveToPreviousPeriod
        case moveToNextPeriod
        case promiseTapped(MockPromise)
        case promiseRespondTapped(MockPromise)
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
        // EventKit 관련
        case checkCalendarPermission
        case calendarPermissionResponse(CalendarAuthorizationStatus)
        case fetchCalendarEvents
        case calendarEventsResponse(Result<[CalendarEvent], Error>)
      }

      public enum Delegate: Sendable {
        case navigateToPromiseDetail(MockPromise)
        case navigateToPromiseRespond(MockPromise)
      }
    }

    // MARK: - Dependencies

    @Dependency(\.eventKitClient) var eventKitClient

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .delegate:
          return .none
        }
      }
    }

    // MARK: - View Action Handler

    private func handleViewAction(
      _ state: inout State,
      _ action: Action.ViewAction
    ) -> Effect<Action> {
      let calendar = Calendar.current

      switch action {
      case .onAppear:
        // 캘린더 권한 확인
        return .send(.internal(.checkCalendarPermission))

      case .toggleDisplayMode:
        state.isTransitioning = true
        state.displayMode = state.displayMode == .week ? .month : .week

        // 모드 전환 시 현재 선택된 날짜 기준으로 동기화
        if state.displayMode == .week {
          state.currentWeekStart = state.selectedDate.startOfWeek
        } else {
          state.currentMonth = state.selectedDate.startOfMonth
        }

        return .run { send in
          try await Task.sleep(nanoseconds: 300_000_000)
          await send(.internal(.transitionCompleted))
        }

      case .selectDate(let date):
        state.selectedDate = date
        return .none

      case .moveToToday:
        let today = Date()
        state.selectedDate = today
        state.currentWeekStart = today.startOfWeek
        state.currentMonth = today.startOfMonth
        return .none

      case .moveToPreviousPeriod:
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            // 선택된 날짜도 같이 이동
            if let newSelectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: state.selectedDate) {
              state.selectedDate = newSelectedDate
            }
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: -1, to: state.currentMonth) {
            state.currentMonth = newMonth
          }
        }
        return .none

      case .moveToNextPeriod:
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            if let newSelectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: state.selectedDate) {
              state.selectedDate = newSelectedDate
            }
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: 1, to: state.currentMonth) {
            state.currentMonth = newMonth
          }
        }
        return .none

      case .promiseTapped(let promise):
        return .send(.delegate(.navigateToPromiseDetail(promise)))

      case .promiseRespondTapped(let promise):
        return .send(.delegate(.navigateToPromiseRespond(promise)))

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
        // 새 주의 캘린더 이벤트 가져오기
        if state.calendarPermissionStatus.canReadEvents {
          return .send(.internal(.fetchCalendarEvents))
        }
        return .none

      case .monthPageChanged(let newMonth):
        // TabView 페이징으로 월이 변경됨
        state.currentMonth = newMonth.startOfMonth
        // 새 월의 캘린더 이벤트 가져오기
        if state.calendarPermissionStatus.canReadEvents {
          return .send(.internal(.fetchCalendarEvents))
        }
        return .none

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

        // 현재 표시 범위에 맞춰 이벤트 조회
        let startDate: Date
        let endDate: Date
        let calendar = Calendar.current

        if state.displayMode == .week {
          startDate = state.currentWeekStart
          endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        } else {
          startDate = state.currentMonth.startOfMonth
          endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        }

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

        if store.sectionDates.isEmpty {
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
        if store.sectionDates.isEmpty {
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
          // 약속 카드들
          ForEach(dayPromises) { promise in
            PromiseCardView(
              promise: promise,
              onTap: { store.send(.view(.promiseTapped(promise))) },
              onRespond: promise.needsMyResponse
                ? { store.send(.view(.promiseRespondTapped(promise))) }
                : nil
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
          }

          // 캘린더 이벤트 카드들
          ForEach(dayEvents) { event in
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
      } header: {
        DiaryStyleSectionHeader(
          date: date,
          isFirst: date == store.sectionDates.first
        )
        .id(date)
      }
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
          onTap: {
            // 탭하면 주간 뷰로 전환
            store.send(.view(.collapseToWeek(date)), animation: .easeInOut(duration: 0.3))
          }
        )
        .id(date)
      }
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
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
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
  let isFirst: Bool

  var body: some View {
    HStack {
      Text(formattedDate)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.primary)
        .textCase(nil)

      Rectangle()
        .fill(Color(.systemGray4))
        .frame(height: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, isFirst ? 12 : 24)
    .padding(.bottom, 12)
    .background(Color.clear)
  }

  private var formattedDate: String {
    DateFormatterCache.sectionHeader.string(from: date)
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
          .background(Color.blue)
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
  let store = Store(initialState: CalendarFeature.Feature.State(displayMode: .week)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}

#Preview("Calendar Feature - Month Mode") {
  let store = Store(initialState: CalendarFeature.Feature.State(displayMode: .month)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}
