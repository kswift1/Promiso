import Clients
import ComposableArchitecture
import Foundation
import CreateScheduleFeature
import NotificationCenterFeature
import PromisoShared
import SharedFeature
import SwiftUI

// MARK: - Root View

extension Home {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      navigationStack
        .sheet(
          item: $store.scope(state: \.createPersonalEvent, action: \.createPersonalEvent)
        ) { createEventStore in
          NavigationStack {
            CreatePersonalEvent.RootView(store: createEventStore)
          }
        }
        .sheet(isPresented: Binding(
          get: { store.departureAlertItem != nil },
          set: { if !$0 { store.send(.view(.departureAlertSheetDismissed)) } }
        )) {
          DepartureAlertSheet(
            scheduleEmoji: store.departureAlertItem?.displayEmoji ?? "",
            scheduleTitle: store.departureAlertItem?.title ?? "",
            scheduleStartAt: store.departureAlertItem?.startAt ?? Date(),
            scheduleLocation: store.departureAlertItem?.location?.name,
            departureLocation: store.departureLocationName,
            transportData: store.departureTransportData.value,
            loadError: store.departureTransportData.error.map { error in
              error is LocationClientError
                ? HomeModels.DepartureLoadError.locationPermission
                : .general("경로를 불러오지 못했어요")
            },
            onSelect: { selection, bufferMinutes in
              store.send(.view(.departureAlertConfirmed(selection, bufferMinutes)))
            },
            onDetailTapped: {
              store.send(.view(.departureAlertDetailTapped))
            },
            onRetry: {
              store.send(.view(.departureAlertRetryTapped))
            },
            onOpenSettings: {
              store.send(.view(.departureAlertOpenSettingsTapped))
            },
            previousScheduleLocation: store.previousScheduleLocation,
            onDepartureOriginChanged: { origin in
              store.send(.view(.departureOriginChanged(origin)))
            },
            onDismiss: {
              store.send(.view(.departureAlertSheetDismissed))
            }
          )
        }
    }

    // MARK: - Navigation Stack

    private var navigationStack: some View {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        homeContent
          .auroraBackground()
          .toolbarBackground(.hidden, for: .navigationBar)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              NotificationButton(
                badgeCount: store.unreadNotificationCount,
                action: {
                  store.send(.view(.notificationButtonTapped))
                }
              )
              .id(store.unreadNotificationCount)
            }
          }
          .toast(Binding(
            get: { store.toastMessage },
            set: { _ in store.send(.view(.toastDismissed)) }
          ))
          .onAppear {
            store.send(.view(.onAppear))
          }
          .onChange(of: scenePhase) { oldPhase, newPhase in
            // inactive/background → active 시 다시 로드
            if newPhase == .active && oldPhase != .active {
              store.send(.view(.onAppear))
            }
          }
          .background(
            CalendarOverlayPresenter(
              isPresented: store.showCalendarOverlay,
              currentMonth: store.overlayCalendarMonth,
              selectedDate: store.overlaySelectedDate,
              prevMonthDays: store.overlayPrevMonthDays,
              days: store.overlayCalendarDays,
              nextMonthDays: store.overlayNextMonthDays,
              weatherState: store.overlayWeatherState,
              weatherLocationText: store.overlayWeatherLocationText,
              weatherInfo: store.overlayWeatherInfo,
              calendarMode: store.overlayCalendarMode,
              scheduleItems: store.overlaySelectedDateScheduleItems,
              prevDayScheduleItems: store.overlayPrevDayScheduleItems,
              nextDayScheduleItems: store.overlayNextDayScheduleItems,
              weekDays: store.overlaySelectedWeekDays,
              currentUserId: store.currentUser.userId,
              weatherCache: store.weatherCache,
              groupColorMap: store.overlayGroupColorMap,
              holidayDates: store.overlayHolidayDateSet,
              onClose: {
                store.send(.view(.calendarOverlayClosed))
              },
              onDateSelected: { date in
                store.send(.view(.overlayDateSelected(date)))
              },
              onPreviousMonth: {
                store.send(.view(.overlayPreviousMonth))
              },
              onNextMonth: {
                store.send(.view(.overlayNextMonth))
              },
              onWeatherCardTapped: {
                store.send(.view(.overlayWeatherCardTapped))
              },
              onBackToMonth: {
                store.send(.view(.overlayBackToMonth), animation: .easeInOut(duration: 0.3))
              },
              onScheduleItemTapped: { item in
                store.send(.view(.overlayScheduleItemTapped(item)))
              },
              onEditScheduleItem: nil,
              onCreatePersonalEvent: { date in
                store.send(.view(.overlayCreatePersonalEventTapped(date)))
              },
              onCreateSchedule: {
                store.send(.view(.overlayCreateScheduleTapped))
              },
              onDeleteScheduleItem: nil,
              onShareScheduleItem: nil,
              overlayFeatureContent: overlayFeatureContent,
              onFeatureBack: {
                switch store.overlayCalendarMode {
                case .scheduleDetail:
                  store.send(.view(.overlayScheduleDetailBackTapped), animation: .easeInOut(duration: 0.3))
                case .scheduleCreate:
                  store.send(.view(.overlayCreateScheduleBackTapped), animation: .easeInOut(duration: 0.3))
                default:
                  break
                }
              }
            )
            .frame(width: 0, height: 0)
          )
      } destination: { store in
        switch store.case {
        case .scheduleDetail(let detailStore):
          ScheduleDetail.RootView(store: detailStore)
        case .personalEventDetail(let personalEventDetailStore):
          PersonalEventDetail.RootView(store: personalEventDetailStore)
        case .recurringPersonalEventDetail(let detailStore):
          RecurringPersonalEventDetail.RootView(store: detailStore)
        case .notificationCenter(let notificationStore):
          NotificationCenterFeature.NotificationCenter.RootView(store: notificationStore)
        case .transportDetail(let detailStore):
          TransportDetail.RootView(store: detailStore)
        }
      }
    }

    // MARK: - Overlay Feature Content

    private var overlayFeatureContent: AnyView? {
      if let detailStore = store.scope(state: \.overlayScheduleDetail, action: \.overlayScheduleDetail) {
        return AnyView(
          OverlayScheduleDetail.RootView(store: detailStore)
        )
      } else if let createStore = store.scope(state: \.overlayCreateSchedule, action: \.overlayCreateSchedule) {
        return AnyView(
          CreateSchedule.RootView(store: createStore)
        )
      }
      return nil
    }

    // MARK: - Home Header

    private var homeHeader: some View {
      HStack {
        Button {
          store.send(.view(.calendarOverlayOpened))
        } label: {
          HStack(spacing: 6) {
            Text(Date(), format: .dateTime.month().day().weekday(.wide))
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(.primary)

            Image(systemName: "chevron.down")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)

        Spacer()
      }
    }

    // MARK: - Home Content

    private var homeContent: some View {
      let snapshot = store.homeContentSnapshot

      return ScrollView {
        LazyVStack(spacing: 20) {
          // 홈 헤더
          homeHeader
            .padding(.horizontal, 16)

          if store.isLoading && !store.hasLoadedOnce {
            loadingView
          } else if let error = store.schedulesState.error {
            errorView(error: error)
          } else {
            // 오늘의 브리핑
            DailyBriefingCard(
              summary: store.briefingState.value?.summary,
              detail: store.briefingState.value?.detail,
              isLoading: store.briefingState.isLoading,
              isExpanded: store.isBriefingExpanded,
              isUpdated: store.isBriefingUpdated,
              isPro: store.isPro,
              isNotificationDenied: store.isNotificationDenied,
              isLocationDenied: store.isLocationDenied,
              onTap: {
                store.send(.view(.briefingCardTapped), animation: .spring(response: 0.35, dampingFraction: 0.8))
              },
              onOpenNotificationSettings: {
                store.send(.view(.openNotificationSettingsTapped))
              },
              onOpenLocationSettings: {
                store.send(.view(.openLocationSettingsTapped))
              },
              onReportError: {
                store.send(.view(.reportBriefingErrorTapped))
              },
              onProUpgradeTapped: {
                store.send(.view(.briefingProUpgradeTapped))
              }
            )
            .padding(.horizontal, 16)

            // 오늘의 일정 카드
            TodayScheduleCard(
              items: snapshot.todayScheduleItems,
              weatherCache: store.weatherCache,
              departureAlerts: store.departureAlerts,
              groupColorMap: store.overlayGroupColorMap,
              isPro: store.isPro,
              onItemTap: { item in
                switch item {
                case .schedule(let p):
                  store.send(.view(.todayScheduleTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
                case .recurringPersonalEvent(let instance):
                  store.send(.view(.recurringPersonalEventTapped(instance)))
                }
              },
              onDepartureAlertTap: { item in
                store.send(.view(.departureAlertTapped(item)))
              },
              onDepartureAlertCancel: { scheduleItemId in
                store.send(.view(.departureAlertCancelTapped(scheduleItemId)))
              }
            )
            .padding(.horizontal, 16)

            // 응답 필요 섹션 (있을 때만 표시)
            if !snapshot.pendingSchedules.isEmpty {
              PendingSection(
                schedules: snapshot.pendingSchedules,
                groupMembersCache: store.groupMembersCache,
                onScheduleTap: { schedule in
                  store.send(.view(.pendingScheduleTapped(schedule)))
                }
              )
              .padding(.horizontal, 16)
            }

            // 다가오는 일정 섹션
            UpcomingSection(
              items: snapshot.upcomingScheduleItems,
              weatherCache: store.weatherCache,
              recurringSummaries: snapshot.upcomingRecurringSummaries,
              onItemTap: { item in
                switch item {
                case .schedule(let p):
                  store.send(.view(.upcomingScheduleTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
                case .recurringPersonalEvent(let instance):
                  store.send(.view(.recurringPersonalEventTapped(instance)))
                }
              },
              onSeeAllTap: {
                store.send(.view(.seeAllUpcomingTapped))
              }
            )
            .padding(.horizontal, 16)
          }

          // 하단 여백 (FAB 및 탭바 공간)
          Color.clear
            .frame(height: 100)
        }
        .padding(.top, 8)
      }
      .refreshable {
        store.send(.view(.refreshTriggered))
      }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      VStack(spacing: 16) {
        // 오늘의 일정 스켈레톤
        RoundedRectangle(cornerRadius: 20)
          .fill(Color(.systemGray6))
          .frame(height: 200)
          .shimmer()

      }
      .padding(.horizontal, 16)
      .shimmer()
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.Error.unknownError)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button(LocalizedStrings.Common.retry) {
          store.send(.view(.refreshTriggered))
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }
  }
}
