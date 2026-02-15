// MARK: - CalendarRootView.swift
// 캘린더 Feature - RootView

import SwiftUI
import ComposableArchitecture
import Clients
import ResourceKit
import SharedFeature

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
            onToggleMode: { store.send(.view(.toggleDisplayMode), animation: .spring(response: 0.45, dampingFraction: 0.8)) },
            onMoveToToday: { store.send(.view(.moveToToday), animation: .spring(response: 0.35, dampingFraction: 0.85)) },
            onMovePrevious: { store.send(.view(.moveToPreviousPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85)) },
            onMoveNext: { store.send(.view(.moveToNextPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85)) }
          )

          Divider()

          // 공통 요일 헤더
          WeekdayHeader()

          // 캘린더 그리드 (주간/월간)
          calendarGridSection
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.displayMode)

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
        case .personalEventDetail(let personalEventDetailStore):
          PersonalEventDetail.RootView(store: personalEventDetailStore)
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
          personalEventsByDate: store.personalEventsByDate,
          currentUserId: store.currentUserId,
          namespace: calendarAnimation,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
          }
        )
        .padding(.vertical, 14)
        .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: -8)))
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
          personalEventsByDate: store.personalEventsByDate,
          currentUserId: store.currentUserId,
          namespace: calendarAnimation,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
          },
          onCollapseToWeek: { date in
            store.send(.view(.collapseToWeek(date)), animation: .spring(response: 0.45, dampingFraction: 0.8))
          }
        )
        .padding(.vertical, 12)
        .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)))
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
        if !store.calendarPermissionStatus.canReadEvents
            && !store.hiddenCalendarBannerTypes.contains(store.calendarPermissionStatus) {
          CalendarPermissionBanner(
            permissionStatus: store.calendarPermissionStatus,
            onRequestPermission: { store.send(.view(.requestCalendarPermission)) },
            onOpenSettings: { store.send(.view(.openSettings)) },
            onDismiss: { store.send(.view(.dismissCalendarBanner(store.calendarPermissionStatus))) }
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
        let dayPersonalEvents = store.personalEventsByDate[dateKey] ?? []

        if dayPromises.isEmpty && dayEvents.isEmpty && dayPersonalEvents.isEmpty {
          EmptyDayPlaceholder(date: date)
        } else {
          // 약속, 개인 일정, 캘린더 이벤트를 시간순으로 통합 정렬
          let sortedItems = mergeAndSortItems(promises: dayPromises, events: dayEvents, personalEvents: dayPersonalEvents)

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
                onTap: {}
              )
              .padding(.horizontal, 16)
              .padding(.vertical, 4)

            case .personalEvent(let event):
              PersonalEventCardView(
                event: event,
                onTap: { store.send(.view(.personalEventTapped(event))) }
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

    /// 약속, 개인 일정, 캘린더 이벤트를 시간순으로 통합 정렬
    private func mergeAndSortItems(
      promises: [PromiseModel],
      events: [CalendarEvent],
      personalEvents: [PersonalEventModel] = []
    ) -> [CalendarListItem] {
      var items: [CalendarListItem] = []

      items.append(contentsOf: promises.map { CalendarListItem.promise($0) })
      items.append(contentsOf: personalEvents.map { CalendarListItem.personalEvent($0) })
      items.append(contentsOf: events.map { CalendarListItem.calendarEvent($0) })

      return items.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Month Mode Header

    private var monthModeHeader: some View {
      HStack {
        Text(LocalizedStrings.Calendar.monthSchedule)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)

        Spacer()

        Text(LocalizedStrings.Calendar.dayCount(store.sectionDates.count))
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
      let dayPersonalEvents = store.personalEventsByDate[dateKey] ?? []
      let isSelected = calendar.isDate(date, inSameDayAs: store.selectedDate)

      if !dayPromises.isEmpty || !dayEvents.isEmpty || !dayPersonalEvents.isEmpty {
        CompactDayRow(
          date: date,
          promises: dayPromises,
          calendarEvents: dayEvents,
          personalEvents: dayPersonalEvents,
          isSelected: isSelected,
          currentUserId: store.currentUserId,
          onTap: {
            store.send(.view(.collapseToWeek(date)), animation: .spring(response: 0.45, dampingFraction: 0.8))
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

        Text(LocalizedStrings.Calendar.loadingPromises)
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

        Text(LocalizedStrings.Calendar.noPromises)
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.primary)

        Text(LocalizedStrings.Calendar.createNewPromise)
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

// MARK: - Preview

#Preview("Calendar Feature - Week Mode") {
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .week)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}

#Preview("Calendar Feature - Month Mode") {
  let store = Store(initialState: CalendarFeature.Feature.State(currentUser: Shared(value: .exampleUser), displayMode: .month)) {
    CalendarFeature.Feature()
  }

  CalendarFeature.RootView(store: store)
}
