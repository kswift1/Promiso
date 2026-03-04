// MARK: - CalendarRootView.swift
// 캘린더 Feature - RootView

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import ResourceKit
import SharedFeature

// MARK: - Root View

extension CalendarFeature {

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Namespace private var calendarAnimation
    @State private var timelineZoomState = TimelineZoomState()

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
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.monthExpansionState)

          // 약속 리스트 (시트 스타일) — expanded 월간일 때 숨김
          if store.displayMode == .week ||
             (store.displayMode == .month && store.monthExpansionState == .collapsed) {
            promiseListSection
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .auroraBackground()
        .alert(store: store.scope(state: \.$deleteAlert, action: \.deleteAlert))
        .sheet(store: store.scope(state: \.$editPromise, action: \.editPromise)) { editStore in
          EditPromise.RootView(store: editStore)
        }
        .sheet(store: store.scope(state: \.$editPersonalEvent, action: \.editPersonalEvent)) { editStore in
          NavigationStack {
            CreatePersonalEvent.RootView(store: editStore)
          }
        }
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
          .presentationDetents([.height(340)])
          .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
          get: { store.systemShareText.map { ShareTextItem(text: $0) } },
          set: { _ in store.send(.view(.systemShareSheetDismissed)) }
        )) { item in
          ShareSheet(items: [item.text])
        }
        .toast(Binding(
          get: { store.toastMessage },
          set: { _ in store.send(.view(.toastDismissed)) }
        ))
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
          scheduleIndicatorsByDate: store.scheduleIndicatorsByDate,
          namespace: calendarAnimation,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
          }
        )
        .padding(.vertical, 14)
        .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: -8)))
      } else if store.monthExpansionState == .collapsed {
        // Collapsed: UIKit 페이저 (compact dot cells)
        PagingMonthGridView(
          currentMonth: Binding(
            get: { store.currentMonth },
            set: { store.send(.view(.monthPageChanged($0))) }
          ),
          selectedDate: store.selectedDate,
          scheduleIndicatorsByDate: store.scheduleIndicatorsByDate,
          namespace: calendarAnimation,
          isCompactMode: true,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
          },
          onCollapseToWeek: { date in
            store.send(.view(.collapseToWeek(date)), animation: .spring(response: 0.45, dampingFraction: 0.8))
          }
        )
        .padding(.vertical, 12)
        .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)))
      } else {
        // Expanded: 고정 높이 3페이지 페이저 (각 페이지 내부 세로 스크롤)
        PagingMonthGridView(
          currentMonth: Binding(
            get: { store.currentMonth },
            set: { store.send(.view(.monthPageChanged($0))) }
          ),
          selectedDate: store.selectedDate,
          scheduleIndicatorsByDate: store.scheduleIndicatorsByDate,
          namespace: calendarAnimation,
          isCompactMode: false,
          showAllIndicators: true,
          onDateSelected: { date in
            store.send(.view(.selectDate(date)), animation: .spring(response: 0.35, dampingFraction: 0.7))
          },
          onCollapseToWeek: { date in
            store.send(.view(.collapseToWeek(date)), animation: .spring(response: 0.45, dampingFraction: 0.8))
          },
          onIndicatorTapped: { indicator in
            store.send(.view(.indicatorTapped(indicator)))
          },
          onDayCreatePersonalEvent: { date in
            store.send(.view(.dayLongPressCreatePersonalEvent(date)))
          },
          onDayCreatePromise: { date in
            store.send(.view(.dayLongPressCreatePromise(date)))
          }
        )
        .padding(.top, 12)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
          collapseToListButton
            .padding(.bottom, 16)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)))
      }
    }

    // MARK: - Promise List Section

    private var promiseListSection: some View {
      VStack(spacing: 0) {
        if store.displayMode == .week {
          weekTimelineView
        } else {
          monthScrollView
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color(.systemBackground))
      .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
      .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -4)
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
            onCreatePersonalEvent: { date in
              store.send(.view(.createPersonalEventFromTimeline(date)))
            },
            onCreatePromise: { date in
              store.send(.view(.createPromiseFromTimeline(date)))
            },
            onDeleteScheduleItem: { item in
              store.send(.view(.deleteScheduleItem(item)))
            },
            onShareScheduleItem: { item in
              store.send(.view(.shareScheduleItem(item)))
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
      .onTapGesture {
        store.send(.view(.toggleMonthExpansion), animation: .spring(response: 0.45, dampingFraction: 0.8))
      }
    }

    // MARK: - Collapse To List Button

    private var collapseToListButton: some View {
      Button {
        store.send(.view(.toggleMonthExpansion), animation: .spring(response: 0.45, dampingFraction: 0.8))
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "list.bullet")
            .font(.system(size: 14, weight: .medium))
          Text(LocalizedStrings.Calendar.monthSchedule)
            .font(.system(size: 14, weight: .semibold))
          Image(systemName: "chevron.up")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color.pmindigo.n500)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.pmindigo.n500.opacity(0.1))
        .cornerRadius(20)
      }
      .padding(.top, 8)
      .padding(.bottom, 20)
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

#Preview("Calendar Feature - Month Expanded") {
  let store = Store(initialState: CalendarFeature.Feature.State(
    currentUser: Shared(value: .exampleUser),
    displayMode: .month
  )) {
    CalendarFeature.Feature()
  }
  // Note: monthExpansionState는 기본 .collapsed
  CalendarFeature.RootView(store: store)
}
