// MARK: - CalendarFeature.swift
// 캘린더 Feature - TCA Reducer 및 메인 뷰
// 주간/월간 토글, 목업 데이터 기반 UI

import SwiftUI
import ComposableArchitecture

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

      /// 표시할 섹션 날짜들
      var sectionDates: [Date] {
        if displayMode == .week {
          return weekDates.sorted()
        } else {
          // 월간: 약속이 있는 날짜만
          let calendar = Calendar.current
          let monthStart = currentMonth.startOfMonth
          guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
          }

          return promisesByDate.keys
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
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
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
      }

      public enum Internal: Sendable {
        case transitionCompleted
      }

      public enum Delegate: Sendable {
        case navigateToPromiseDetail(MockPromise)
        case navigateToPromiseRespond(MockPromise)
      }
    }

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
      _ action: Action.View
    ) -> Effect<Action> {
      let calendar = Calendar.current

      switch action {
      case .onAppear:
        return .none

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

        return .run { send in
          try await Task.sleep(nanoseconds: 300_000_000)
          await send(.internal(.transitionCompleted))
        }

      case .weekPageChanged(let newWeekStart):
        // TabView 페이징으로 주가 변경됨
        state.currentWeekStart = newWeekStart
        return .none

      case .monthPageChanged(let newMonth):
        // TabView 페이징으로 월이 변경됨
        state.currentMonth = newMonth.startOfMonth
        return .none
      }
    }

    // MARK: - Internal Action Handler

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.Internal
    ) -> Effect<Action> {
      switch action {
      case .transitionCompleted:
        state.isTransitioning = false
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

        Divider()

        // 약속 리스트
        promiseListSection
      }
      .background(Color(.systemBackground))
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
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if store.sectionDates.isEmpty {
              emptyStateView
            } else {
              ForEach(store.sectionDates, id: \.self) { date in
                Section {
                  let calendar = Calendar.current
                  let dateKey = calendar.startOfDay(for: date)
                  let dayPromises = store.promisesByDate[dateKey] ?? []

                  if dayPromises.isEmpty {
                    EmptyDayPlaceholder(date: date)
                  } else {
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
                  }
                } header: {
                  PromiseListSectionHeader(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: store.selectedDate)
                  )
                  .id(date)
                }
              }
            }

            Spacer()
              .frame(height: 100)
          }
          .padding(.top, 8)
        }
        .onChange(of: store.selectedDate) { _, newDate in
          // 선택된 날짜로 스크롤
          let calendar = Calendar.current
          if let targetDate = store.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: newDate) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(targetDate, anchor: .top)
            }
          }
        }
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
