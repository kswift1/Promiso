// MARK: - CalendarRootView.swift
// 캘린더 Feature - RootView

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import ResourceKit
import SharedFeature
import CreatePromiseFeature

// MARK: - Root View

extension CalendarFeature {

  static func weekRowIndex(
    currentMonth: Date,
    selectedDate: Date,
    startOnMonday: Bool = AppConstants.isCalendarStartOnMonday
  ) -> Int {
    let calendar = Calendar.current
    let startOfMonth = currentMonth.startOfMonth
    let firstWeekday = currentMonth.firstWeekdayOfMonth
    let firstDayOfWeek = startOnMonday ? 2 : 1
    let daysToSubtract = (firstWeekday - firstDayOfWeek + 7) % 7
    guard let calendarStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth) else {
      return 0
    }
    let daysBetween = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: calendarStart),
      to: calendar.startOfDay(for: selectedDate)
    ).day ?? 0
    return max(0, min(5, daysBetween / 7))
  }

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Namespace private var calendarAnimation
    @State private var timelineZoomState = TimelineZoomState()
    @State private var sheetDragOffset: CGFloat = 0
    @State private var sheetDragBaseOffset: CGFloat = 0

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        calendarContentView
      } destination: { store in
        switch store.case {
        case .promiseDetail(let promiseDetailStore):
          PromiseDetail.RootView(store: promiseDetailStore)
        case .personalEventDetail(let personalEventDetailStore):
          PersonalEventDetail.RootView(store: personalEventDetailStore)
        case .recurringPersonalEventDetail(let detailStore):
          RecurringPersonalEventDetail.RootView(store: detailStore)
        case .calendarEventDetail(let calendarEventDetailStore):
          CalendarEventDetailView(event: calendarEventDetailStore.event)
        }
      }
    }

    // MARK: - Calendar Content View

    private var calendarContentView: some View {
      calendarWithEditCovers
        .sheet(item: Binding(
          get: { store.sharePromise },
          set: { _ in store.send(.view(.dismissPromiseShareSheet)) }
        )) { promise in
          PromiseShareSheet(
            promise: promise,
            isKakaoSharing: store.isKakaoPromiseSharing,
            onKakaoShareTapped: {
              store.send(.view(.kakaoPromiseShareTapped))
            },
            onSystemShareTapped: {
              store.send(.view(.systemPromiseShareTapped))
            }
          )
        }
        .sheet(item: Binding(
          get: { store.systemShareText.map { ShareTextItem(text: $0) } },
          set: { _ in store.send(.view(.systemShareSheetDismissed)) }
        )) { item in
          ShareSheet(items: [item.text])
        }
        .sheet(isPresented: Binding(
          get: { store.isFilterSheetPresented },
          set: { newValue in
            if !newValue {
              store.send(.view(.filterSheetDismissed))
            }
          }
        )) {
          CalendarFilterSheetView(
            groups: store.sortedGroups,
            groupColorMap: store.groupColorMap,
            selectedGroupIds: store.selectedGroupIds,
            showPersonalEvents: store.showPersonalEvents,
            selectedStatusFilters: store.selectedStatusFilters,
            showCalendarEvents: store.showCalendarEvents,
            canReadCalendarEvents: store.calendarPermissionStatus.canReadEvents,
            isFilterActive: store.isFilterActive,
            onGroupToggled: { groupId in
              store.send(.view(.filterGroupToggled(groupId)))
            },
            onPersonalEventsToggled: {
              store.send(.view(.filterPersonalEventsToggled))
            },
            onStatusFilterChanged: { filter in
              store.send(.view(.filterStatusChanged(filter)))
            },
            onCalendarEventsToggled: {
              store.send(.view(.filterCalendarEventsToggled))
            },
            onReset: {
              store.send(.view(.filterReset))
            }
          )
          .presentationDragIndicator(.visible)
        }
        .toast(Binding(
          get: { store.toastMessage },
          set: { _ in store.send(.view(.toastDismissed)) }
        ))
        .onAppear {
          store.send(.view(.onAppear))
        }
    }

    private var calendarWithEditCovers: some View {
      calendarBaseView
        .sheet(store: store.scope(state: \.$editPromise, action: \.editPromise)) { editStore in
          EditPromise.RootView(store: editStore)
        }
        .sheet(store: store.scope(state: \.$editPersonalEvent, action: \.editPersonalEvent)) { editStore in
          CreatePersonalEvent.RootView(
            store: editStore,
            dismissButtonVisibility: .hiddenForCreateMode
          )
          .presentationDragIndicator(.visible)
        }
        .sheet(store: store.scope(state: \.$editRecurringPersonalEvent, action: \.editRecurringPersonalEvent)) { editStore in
          CreateRecurringPersonalEvent.RootView(store: editStore)
            .presentationDragIndicator(.visible)
        }
        .sheet(store: store.scope(state: \.$createPromise, action: \.createPromise)) { createStore in
          CreatePromise.RootView(store: createStore)
        }
    }

    private var calendarBaseView: some View {
      VStack(spacing: 0) {
        // 헤더
        CalendarHeader(
          title: store.headerTitle,
          displayMode: store.displayMode,
          isSelectedDateToday: store.isSelectedDateToday,
          isFilterActive: store.isFilterActive,
          onFilterTapped: { store.send(.view(.filterIconTapped)) },
          onToggleMode: { store.send(.view(.toggleDisplayMode), animation: .smooth(duration: 0.35)) },
          onSetMode: { mode in store.send(.view(.setDisplayMode(mode)), animation: .smooth(duration: 0.35)) },
          onMoveToToday: { store.send(.view(.moveToToday), animation: .spring(response: 0.35, dampingFraction: 0.85)) },
          onMovePrevious: { store.send(.view(.moveToPreviousPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85)) },
          onMoveNext: { store.send(.view(.moveToNextPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85)) }
        )

        Divider()

        // 공통 요일 헤더
        WeekdayHeader()

        // 캘린더 그리드 (주간/월간)
        calendarGridSection
          .layoutPriority(1)
          .animation(.smooth(duration: 0.35), value: store.displayMode)
          .onChange(of: store.displayMode) { _, _ in
            withAnimation(.smooth(duration: 0.35)) {
              sheetDragOffset = 0
            }
            sheetDragBaseOffset = 0
          }

        // 약속 리스트 (시트 스타일) — monthExpanded일 때 숨김
        if store.displayMode == .week || store.displayMode == .month {
          promiseListSection
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .auroraBackground()
      .alert(store: store.scope(state: \.$deleteAlert, action: \.deleteAlert))
    }

    // MARK: - Calendar Grid Section

    @ViewBuilder
    private var calendarGridSection: some View {
      let isExpanded = store.displayMode == .monthExpanded
      let isWeek = store.displayMode == .week

      PagingMonthGridView(
        currentMonth: Binding(
          get: { store.currentMonth },
          set: { store.send(.view(.monthPageChanged($0))) }
        ),
        selectedDate: store.selectedDate,
        scheduleIndicatorsByDate: store.scheduleIndicatorsByDate,
        holidaysByDate: store.holidaysByDate,
        namespace: calendarAnimation,
        isCompactMode: !isExpanded,
        showAllIndicators: isExpanded,
        selectedWeekRow: isWeek ? selectedWeekRowIndex : nil,
        onDateSelected: { date in
          store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
        },
        onCollapseToWeek: { date in
          store.send(.view(.collapseToWeek(date)), animation: .smooth(duration: 0.35))
        },
        onIndicatorTapped: { indicator in
          store.send(.view(.indicatorTapped(indicator)))
        },
        onDayCreatePersonalEvent: { date in
          store.send(.view(.dayLongPressCreatePersonalEvent(date)))
        },
        onDayCreatePromise: { date in
          store.send(.view(.dayLongPressCreatePromise(date)))
        },
        previewIndicatorsProvider: { [store] date in
          store.withState { $0.unfilteredIndicators(for: date) }
        },
        onWeekPageChanged: isWeek ? { direction in
          if direction < 0 {
            store.send(.view(.moveToPreviousPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85))
          } else {
            store.send(.view(.moveToNextPeriod), animation: .spring(response: 0.35, dampingFraction: 0.85))
          }
        } : nil
      )
      // week: 1행 고정(46pt), month: 드래그 가능, expanded: 자유
      .frame(height: isExpanded ? nil : (isWeek ? 46 : compactGridHeight))
      .frame(maxHeight: isExpanded ? .infinity : nil)
      .padding(.top, 12)
      .padding(.bottom, isExpanded ? 0 : 12)
    }

    // MARK: - Selected Week Row Index

    private var selectedWeekRowIndex: Int {
      CalendarFeature.weekRowIndex(
        currentMonth: store.currentMonth,
        selectedDate: store.selectedDate
      )
    }

    // MARK: - Promise List Section

    private var promiseListSection: some View {
      VStack(spacing: 0) {
        if store.displayMode == .week {
          weekTimelineView
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
          monthScrollView
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.smooth(duration: 0.35), value: store.displayMode)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color(.secondarySystemGroupedBackground))
      .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
      .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
      .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Week Timeline View

    @ViewBuilder
    private var weekTimelineView: some View {
      VStack(spacing: 0) {
        // 캘린더 권한 배너 (기존 유지)
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
        } else {
          CalendarDayTimelinePager(
            selectedDate: store.selectedDate,
            prevDayScheduleItems: store.prevDayScheduleItems,
            currentDayScheduleItems: store.selectedDateScheduleItems,
            nextDayScheduleItems: store.nextDayScheduleItems,
            onScheduleItemTapped: { item in
              store.send(.view(.scheduleItemTapped(item)))
            },
            onEditScheduleItem: { item in
              store.send(.view(.editScheduleItem(item)))
            },
            onPreviousDay: {
              if let prev = Calendar.current.date(byAdding: .day, value: -1, to: store.selectedDate) {
                store.send(.view(.selectDate(prev)), animation: .spring(response: 0.35, dampingFraction: 0.7))
              }
            },
            onNextDay: {
              if let next = Calendar.current.date(byAdding: .day, value: 1, to: store.selectedDate) {
                store.send(.view(.selectDate(next)), animation: .spring(response: 0.35, dampingFraction: 0.7))
              }
            },
            onCreatePersonalEvent: { startDate, endDate in
              store.send(.view(.createPersonalEventFromTimeline(startDate: startDate, endDate: endDate)))
            },
            onCreatePromise: { startDate, endDate in
              store.send(.view(.createPromiseFromTimeline(startDate: startDate, endDate: endDate)))
            },
            onDeleteScheduleItem: { item in
              store.send(.view(.deleteScheduleItem(item)))
            },
            onShareScheduleItem: { item in
              store.send(.view(.shareScheduleItem(item)))
            },
            onPastTimeBlocked: {
              store.send(.view(.pastTimeBlocked))
            },
            currentUserId: store.currentUserId,
            weatherCache: store.weatherCache,
            groupColorMap: store.groupColorMap,
            zoomState: timelineZoomState
          )
        }
      }
    }

    // MARK: - Month Scroll View

    private var monthScrollView: some View {
      VStack(spacing: 0) {
        // 드래그 핸들 — 탭하면 expanded로 전환
        sheetDragHandle

        ScrollViewReader { proxy in
          ScrollView {
            monthPromiseListContent
          }
          .onChange(of: store.isInitialLoading) { wasLoading, isLoading in
            guard wasLoading, !isLoading else { return }
            let calendar = Calendar.current
            if let targetDate = store.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: store.selectedDate) }) {
              proxy.scrollTo(targetDate, anchor: .center)
            }
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
    }

    // MARK: - Sheet Drag Handle

    // MARK: - Sheet Drag Constants

    private static let defaultGridHeight: CGFloat = 306
    private static let minGridHeight: CGFloat = 150
    private static let maxDrag: CGFloat = defaultGridHeight - minGridHeight // 106

    private var compactGridHeight: CGFloat {
      Self.defaultGridHeight - sheetDragOffset
    }

    private func clampedSheetOffset(_ offset: CGFloat) -> CGFloat {
      max(0, min(Self.maxDrag, offset))
    }

    private var snapOffsets: [CGFloat] {
      [0, Self.maxDrag]
    }

    private func nearestSnapOffset(for offset: CGFloat) -> CGFloat {
      let clamped = clampedSheetOffset(offset)
      return snapOffsets.min(by: {
        abs($0 - clamped) < abs($1 - clamped)
      }) ?? 0
    }

    private var sheetDragGesture: some Gesture {
      DragGesture(minimumDistance: 5, coordinateSpace: .global)
        .onChanged { value in
          let proposedOffset = sheetDragBaseOffset - value.translation.height
          sheetDragOffset = clampedSheetOffset(proposedOffset)
        }
        .onEnded { value in
          let projectedOffset = sheetDragBaseOffset - value.predictedEndTranslation.height
          let targetOffset = nearestSnapOffset(for: projectedOffset)
          withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            sheetDragOffset = targetOffset
          }
          sheetDragBaseOffset = targetOffset
        }
    }

    private var sheetDragHandle: some View {
      VStack(spacing: 0) {
        Capsule()
          .fill(Color(.systemGray4))
          .frame(width: 36, height: 5)
          .padding(.top, 10)
          .padding(.bottom, 6)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .gesture(sheetDragGesture)
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

    // MARK: - Month Mode Header

    private var monthModeHeader: some View {
      HStack {
        Text("\(Calendar.current.component(.month, from: store.currentMonth))월 일정")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)

        Spacer()
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
      let holidayName = store.holidaysByDate[dateKey]
      let isSelected = calendar.isDate(date, inSameDayAs: store.selectedDate)

      CompactDayRow(
        date: date,
        promises: dayPromises,
        calendarEvents: dayEvents,
        personalEvents: dayPersonalEvents,
        isSelected: isSelected,
        currentUserId: store.currentUserId,
        holidayName: holidayName,
        groupColorMap: store.groupColorMap,
        onDateTap: {
          store.send(.view(.collapseToWeek(date)), animation: .smooth(duration: 0.35))
        },
        onPromiseTap: { promise in
          store.send(.view(.scheduleItemTapped(.promise(promise))))
        },
        onPersonalEventTap: { event in
          store.send(.view(.scheduleItemTapped(.personalEvent(event))))
        },
        onCalendarEventTap: { event in
          store.send(.view(.scheduleItemTapped(.calendarEvent(event))))
        },
        onCreatePersonalEvent: {
          store.send(.view(.dayLongPressCreatePersonalEvent(date)))
        },
        onCreatePromise: {
          store.send(.view(.dayLongPressCreatePromise(date)))
        }
      )
      .id(date)
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

#Preview("Calendar Feature - Month Expanded") {
  let store = Store(initialState: CalendarFeature.Feature.State(
    currentUser: Shared(value: .exampleUser),
    displayMode: .month
  )) {
    CalendarFeature.Feature()
  }
  // Note: displayMode 기본 .week
  CalendarFeature.RootView(store: store)
}
