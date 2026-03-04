import Clients
import ComposableArchitecture
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
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        homeContent
          .auroraBackground()
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
          .sheet(isPresented: Binding(
            get: { store.showQuickPromiseSheet },
            set: { newValue in
              if !newValue {
                store.send(.view(.quickPromiseSheetDismissed))
              }
            }
          )) {
            QuickPromise.CardView(
              store: store.scope(state: \.quickPromise, action: \.quickPromise)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
          }
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
              onCreatePersonalEvent: { date in
                store.send(.view(.overlayCreatePersonalEventTapped(date)))
              },
              onCreatePromise: {
                store.send(.view(.overlayCreatePromiseTapped))
              },
              onDeleteScheduleItem: nil,
              onShareScheduleItem: nil
            )
            .frame(width: 0, height: 0)
          )
      } destination: { store in
        switch store.case {
        case .promiseDetail(let detailStore):
          PromiseDetail.RootView(store: detailStore)
        case .personalEventDetail(let personalEventDetailStore):
          PersonalEventDetail.RootView(store: personalEventDetailStore)
        case .notificationCenter(let notificationStore):
          NotificationCenterFeature.NotificationCenter.RootView(store: notificationStore)
        }
      }
      .sheet(
        item: $store.scope(state: \.createPersonalEvent, action: \.createPersonalEvent)
      ) { createEventStore in
        NavigationStack {
          CreatePersonalEvent.RootView(store: createEventStore)
        }
      }
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
          } else if let error = store.promisesState.error {
            errorView(error: error)
          } else {
            // 빠른 약속 만들기 버튼
            quickPromiseButton
              .padding(.horizontal, 16)

            // 오늘의 일정 카드
            TodayScheduleCard(
              items: snapshot.todayScheduleItems,
              weatherCache: store.weatherCache,
              onItemTap: { item in
                switch item {
                case .promise(let p):
                  store.send(.view(.todayPromiseTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
                }
              }
            )
            .padding(.horizontal, 16)

            // 응답 필요 섹션 (있을 때만 표시)
            if !snapshot.pendingPromises.isEmpty {
              PendingSection(
                promises: snapshot.pendingPromises,
                groupMembersCache: store.groupMembersCache,
                onPromiseTap: { promise in
                  store.send(.view(.pendingPromiseTapped(promise)))
                }
              )
              .padding(.horizontal, 16)
            }

            // 다가오는 일정 섹션
            UpcomingSection(
              items: snapshot.upcomingScheduleItems,
              weatherCache: store.weatherCache,
              onItemTap: { item in
                switch item {
                case .promise(let p):
                  store.send(.view(.upcomingPromiseTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
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

    // MARK: - Quick Promise Button

    @ViewBuilder
    private var quickPromiseButton: some View {
      Button {
        store.send(.view(.quickPromiseButtonTapped))
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)

          Text(LocalizedStrings.QuickPromise.title)
            .font(.system(size: 14, weight: .semibold))

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background {
          if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 14)
              .fill(.clear)
              .glassEffect(.regular, in: .rect(cornerRadius: 14))
          } else {
            RoundedRectangle(cornerRadius: 14)
              .fill(.ultraThinMaterial)
          }
        }
      }
      .buttonStyle(.plain)
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

        // 응답 필요 스켈레톤
        VStack(alignment: .leading, spacing: 12) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(width: 100, height: 24)

          HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .frame(width: 160, height: 140)
            }
          }
        }

        // 다가오는 약속 스켈레톤
        VStack(alignment: .leading, spacing: 12) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(width: 120, height: 24)

          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 14)
              .fill(Color(.systemGray6))
              .frame(height: 80)
          }
        }
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
