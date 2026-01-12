// MARK: - CalendarFeature.swift
// 주간 캘린더 뷰 - matchedGeometryEffect 애니메이션, pinned section headers

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Feature Namespace

public enum CalendarTab {}

// MARK: - Feature Implementation

extension CalendarTab {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 유저 정보
      var currentUser: UserPrivateModel

      /// 선택된 날짜
      var selectedDate: Date

      /// 현재 표시 중인 주의 기준 날짜
      var currentWeekDate: Date

      /// 약속 데이터 로딩 상태
      var promisesState: LoadingState<[PromiseModel]> = .idle

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
        let today = Date()
        self.selectedDate = today
        self.currentWeekDate = today
      }

      // MARK: - Computed Properties

      /// 현재 주의 날짜들 (일~토)
      var weekDates: [Date] {
        Self.calculateWeekDates(for: currentWeekDate)
      }

      /// 약속 목록
      var promises: [PromiseModel] {
        promisesState.value ?? []
      }

      /// 현재 주의 약속만 필터링
      var weekPromises: [PromiseModel] {
        let calendar = Foundation.Calendar.current
        guard let weekStart = weekDates.first,
              let weekEnd = weekDates.last else { return [] }

        let startOfWeek = calendar.startOfDay(for: weekStart)
        let endOfWeek = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: weekEnd)) ?? weekEnd

        return promises.filter { promise in
          promise.startAt >= startOfWeek && promise.startAt < endOfWeek
        }
      }

      /// 날짜별로 그룹화된 약속
      var promisesByDate: [Date: [PromiseModel]] {
        let calendar = Foundation.Calendar.current
        var grouped: [Date: [PromiseModel]] = [:]

        for promise in weekPromises {
          let dateKey = calendar.startOfDay(for: promise.startAt)
          if grouped[dateKey] != nil {
            grouped[dateKey]?.append(promise)
          } else {
            grouped[dateKey] = [promise]
          }
        }

        // 시간순 정렬
        for (date, promiseList) in grouped {
          grouped[date] = promiseList.sorted { $0.startAt < $1.startAt }
        }

        return grouped
      }

      /// 표시할 섹션 날짜들 (모든 요일)
      var sectionDates: [Date] {
        weekDates.sorted()
      }

      /// 선택된 날짜에 약속이 있는지
      var hasPromisesOnSelectedDate: Bool {
        let calendar = Foundation.Calendar.current
        let dateKey = calendar.startOfDay(for: selectedDate)
        return promisesByDate[dateKey] != nil
      }

      // MARK: - Helper Methods

      static func calculateWeekDates(for date: Date) -> [Date] {
        let calendar = Foundation.Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = weekday - 1

        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: date) else {
          return []
        }

        return (0..<7).compactMap { dayOffset in
          calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
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
        case dateSelected(Date)
        case scrolledToDate(Date)
        case promiseTapped(PromiseModel)
        case refreshTriggered
      }

      public enum Internal: Sendable {
        case fetchPromises
        case promisesResponse(Result<[PromiseModel], Error>)
      }

      public enum Delegate: Sendable {
        case navigateToPromise(PromiseModel)
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
      switch action {
      case .onAppear:
        guard !state.hasLoadedOnce else { return .none }
        state.hasLoadedOnce = true
        return .send(.internal(.fetchPromises))

      case .dateSelected(let date):
        state.selectedDate = date
        return .none

      case .scrolledToDate(let date):
        // 스크롤로 인한 날짜 변경 (위크 스트립만 업데이트, 자동 스크롤 트리거 안함)
        state.selectedDate = date
        return .none

      case .promiseTapped(let promise):
        return .send(.delegate(.navigateToPromise(promise)))

      case .refreshTriggered:
        return .send(.internal(.fetchPromises))
      }
    }

    // MARK: - Internal Action Handler

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.Internal
    ) -> Effect<Action> {
      switch action {
      case .fetchPromises:
        state.promisesState = .loading
        let userId = state.currentUser.userId

        return .run { [promiseClient] send in
          do {
            let promises = try await promiseClient.getUpcomingPromises(userId, 100)
            await send(.internal(.promisesResponse(.success(promises))))
          } catch {
            await send(.internal(.promisesResponse(.failure(error))))
          }
        }

      case .promisesResponse(let result):
        switch result {
        case .success(let promises):
          state.promisesState = .loaded(promises)
        case .failure(let error):
          state.promisesState = .failed(error)
        }
        return .none
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Namespace private var weekAnimation

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        // 고정 헤더 영역 (This Week + Week Strip)
        VStack(spacing: 16) {
          // Top Header
          CalendarTopHeader()

          // Week Strip with matchedGeometryEffect
          WeekStripView(
            weekDates: store.weekDates,
            selectedDate: store.selectedDate,
            promisesByDate: store.promisesByDate,
            namespace: weekAnimation,
            onDateSelected: { date in
              store.send(.view(.dateSelected(date)), animation: .easeInOut(duration: 0.25))
            }
          )
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))

        Divider()

        // Task List (스크롤 영역)
        TaskListView(
          store: store,
          selectedDate: store.selectedDate,
          onScrollToDate: { date in
            store.send(.view(.scrolledToDate(date)), animation: .easeInOut(duration: 0.2))
          }
        )
      }
      .auroraBackground()
      .navigationBarHidden(true)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}

// MARK: - Top Header

private struct CalendarTopHeader: View {
  var body: some View {
    HStack {
      Text("This Week")
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(.primary)

      Spacer()

      // 프로필 아이콘 슬롯 (옵션)
      Button(action: {}) {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 28))
          .foregroundColor(.secondary.opacity(0.6))
      }
    }
    .padding(.horizontal, 20)
  }
}

// MARK: - Week Strip View

private struct WeekStripView: View {
  let weekDates: [Date]
  let selectedDate: Date
  let promisesByDate: [Date: [PromiseModel]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void

  private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
        WeekDayCell(
          weekdaySymbol: weekdaySymbols[index],
          date: date,
          isSelected: Foundation.Calendar.current.isDate(date, inSameDayAs: selectedDate),
          isToday: Foundation.Calendar.current.isDateInToday(date),
          hasPromises: hasPromises(on: date),
          namespace: namespace,
          onTap: { onDateSelected(date) }
        )
      }
    }
    .padding(.horizontal, 12)
  }

  private func hasPromises(on date: Date) -> Bool {
    let calendar = Foundation.Calendar.current
    let dateKey = calendar.startOfDay(for: date)
    return promisesByDate[dateKey] != nil
  }
}

// MARK: - Week Day Cell

private struct WeekDayCell: View {
  let weekdaySymbol: String
  let date: Date
  let isSelected: Bool
  let isToday: Bool
  let hasPromises: Bool
  let namespace: Namespace.ID
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 8) {
        // 요일
        Text(weekdaySymbol)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(isSelected ? .blue : .secondary)

        // 날짜 (선택 시 pill 하이라이트)
        ZStack {
          if isSelected {
            Circle()
              .fill(Color.blue)
              .frame(width: 40, height: 40)
              .matchedGeometryEffect(id: "selection", in: namespace)
          }

          Text(dayNumber)
            .font(.system(size: 16, weight: isSelected ? .bold : (isToday ? .semibold : .regular)))
            .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
        }
        .frame(width: 40, height: 40)

        // 약속 있음 표시 (dot)
        Circle()
          .fill(hasPromises ? Color.blue.opacity(isSelected ? 0 : 0.8) : Color.clear)
          .frame(width: 6, height: 6)
      }
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
  }

  private var dayNumber: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
  }
}

// MARK: - Scroll Position Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: [Date: CGFloat] = [:]
  static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
    value.merge(nextValue()) { $1 }
  }
}

// MARK: - Task List View

private struct TaskListView: View {
  let store: StoreOf<CalendarTab.Feature>
  let selectedDate: Date
  let onScrollToDate: (Date) -> Void

  @State private var isUserScrolling = false
  @State private var scrollTask: Task<Void, Never>?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          if store.promisesState.isLoading {
            LoadingView()
          } else if store.sectionDates.isEmpty {
            EmptyStateView()
          } else {
            ForEach(store.sectionDates, id: \.self) { date in
              Section {
                let calendar = Foundation.Calendar.current
                let dateKey = calendar.startOfDay(for: date)
                let dayPromises = store.promisesByDate[dateKey] ?? []

                if dayPromises.isEmpty {
                  // 약속이 없는 날짜
                  EmptyDayView(date: date)
                } else {
                  ForEach(dayPromises) { promise in
                    TaskCard(promise: promise)
                      .padding(.horizontal, 16)
                      .padding(.vertical, 6)
                      .onTapGesture {
                        store.send(.view(.promiseTapped(promise)))
                      }
                  }
                }
              } header: {
                SectionHeader(date: date, isSelected: Foundation.Calendar.current.isDate(date, inSameDayAs: selectedDate))
                  .id(date)
                  .background(
                    GeometryReader { geo in
                      Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: [date: geo.frame(in: .named("scroll")).minY]
                      )
                    }
                  )
              }
            }
          }

          Spacer()
            .frame(height: 200)
        }
        .padding(.top, 8)
      }
      .coordinateSpace(name: "scroll")
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offsets in
        guard isUserScrolling else { return }

        // 화면 상단에 가장 가까운 섹션 찾기
        let threshold: CGFloat = 60
        let visibleDate = offsets
          .filter { $0.value <= threshold && $0.value > -100 }
          .min(by: { abs($0.value) < abs($1.value) })?
          .key

        if let visibleDate = visibleDate {
          let calendar = Foundation.Calendar.current
          if !calendar.isDate(visibleDate, inSameDayAs: selectedDate) {
            onScrollToDate(visibleDate)
          }
        }
      }
      .refreshable {
        store.send(.view(.refreshTriggered))
      }
      .simultaneousGesture(
        DragGesture()
          .onChanged { _ in
            isUserScrolling = true
            scrollTask?.cancel()
          }
          .onEnded { _ in
            scrollTask = Task {
              try? await Task.sleep(nanoseconds: 300_000_000)
              await MainActor.run {
                isUserScrolling = false
              }
            }
          }
      )
      .onChange(of: selectedDate) { oldDate, newDate in
        // 탭으로 선택한 경우에만 자동 스크롤 (스크롤로 변경된 경우 제외)
        guard !isUserScrolling else { return }

        // sectionDates에서 해당 날짜 찾기
        let calendar = Foundation.Calendar.current
        if let targetDate = store.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: newDate) }) {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(targetDate, anchor: .top)
          }
        }
      }
    }
  }
}

// MARK: - Section Header

private struct SectionHeader: View {
  let date: Date
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      Text(dayOfWeek)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(isSelected ? .blue : .secondary)

      Text(dayNumber)
        .font(.system(size: 22, weight: .bold))
        .foregroundColor(isSelected ? .blue : .primary)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
  }

  private var dayOfWeek: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter.string(from: date).uppercased()
  }

  private var dayNumber: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
  }
}

// MARK: - Task Card

private struct TaskCard: View {
  let promise: PromiseModel

  var body: some View {
    HStack(spacing: 14) {
      // 상태 표시 점
      Circle()
        .fill(statusColor)
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: 6) {
        // 제목
        Text(promise.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .lineLimit(1)

        // 시간
        Text(timeRangeText)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.secondary)
      }

      Spacer()

      // 위치 (옵션)
      if let location = promise.location {
        HStack(spacing: 4) {
          Image(systemName: "location.fill")
            .font(.system(size: 10))
          Text(location.name)
            .font(.system(size: 13))
            .lineLimit(1)
        }
        .foregroundColor(.secondary.opacity(0.8))
        .frame(maxWidth: 100, alignment: .trailing)
      }
    }
    .padding(16)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
    )
  }

  private var statusColor: Color {
    if promise.isConfirmed {
      return .green
    } else if promise.isVotingClosed {
      return .orange
    } else {
      return .blue
    }
  }

  private var timeRangeText: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let start = formatter.string(from: promise.startAt)

    if let endAt = promise.endAt {
      let end = formatter.string(from: endAt)
      return "\(start) – \(end)"
    }
    return start
  }
}

// MARK: - Empty Day View

private struct EmptyDayView: View {
  let date: Date

  var body: some View {
    HStack {
      Text("No events")
        .font(.system(size: 15))
        .foregroundColor(.secondary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 24)
  }
}

// MARK: - Loading View

private struct LoadingView: View {
  var body: some View {
    VStack(spacing: 16) {
      ForEach(0..<3, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 14)
          .fill(Color(.systemGray5))
          .frame(height: 72)
          .padding(.horizontal, 16)
      }
    }
    .padding(.top, 24)
  }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Spacer()
        .frame(height: 60)

      Image(systemName: "calendar.badge.checkmark")
        .font(.system(size: 52, weight: .light))
        .foregroundColor(.secondary.opacity(0.6))

      Text("No events this week")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.primary)

      Text("Your schedule is clear")
        .font(.system(size: 15))
        .foregroundColor(.secondary)

      Spacer()
        .frame(height: 60)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
  }
}
