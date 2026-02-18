import ComposableArchitecture
import PromisoShared
import SharedFeature
import SwiftUI

// MARK: - Namespace
public enum PersonalMode {}

// MARK: - Event Filter
extension PersonalMode {
  /// 개인 일정 필터
  public enum EventFilter: String, CaseIterable, Sendable, CategoryFilterItem {
    case today = "오늘"
    case future = "미래"
    case all = "전체"
    case past = "과거"

    public var title: String { rawValue }

    public var icon: String {
      switch self {
      case .today: return "sun.max.fill"
      case .future: return "clock.fill"
      case .all: return "calendar"
      case .past: return "clock.arrow.circlepath"
      }
    }

    public var selectedColor: Color {
      switch self {
      case .today: return .orange
      case .future: return .blue
      case .all: return .pmindigo.n500
      case .past: return Color(UIColor.systemGray)
      }
    }

    public var hasSeparatorBefore: Bool {
      self == .past
    }
  }
}

// MARK: - Reducer
extension PersonalMode {
  @Reducer
  public struct Feature {
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var eventsState: LoadingState<[PersonalEventModel]> = .idle
      var pastEventsState: LoadingState<[PersonalEventModel]> = .idle
      var selectedFilter: EventFilter = .today
      @Shared var currentUser: UserPrivateModel
      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]
      var toastMessage: ToastMessage?

      @Presents var createEvent: CreatePersonalEvent.Feature.State?
      @Presents var eventDetail: PersonalEventDetail.Feature.State?

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
      }

      // MARK: - Computed Properties

      /// 필터링된 일정 목록
      var filteredEvents: [PersonalEventModel] {
        switch selectedFilter {
        case .today:
          guard let events = eventsState.value else { return [] }
          let calendar = Calendar.current
          return events.filter { calendar.isDateInToday($0.startAt) }
            .sorted { $0.startAt < $1.startAt }
        case .future:
          guard let events = eventsState.value else { return [] }
          let calendar = Calendar.current
          return events.filter { !calendar.isDateInToday($0.startAt) }
            .sorted { $0.startAt < $1.startAt }
        case .all:
          guard let events = eventsState.value else { return [] }
          return events.sorted { $0.startAt < $1.startAt }
        case .past:
          guard let events = pastEventsState.value else { return [] }
          return events.sorted { $0.startAt > $1.startAt }
        }
      }

      /// 날짜별로 그룹화된 일정
      var groupedEvents: [(date: String, events: [PersonalEventModel])] {
        let grouped = Dictionary(grouping: filteredEvents, by: { $0.dateText })

        // 과거: 최신순 (어제 → 이전 날짜)
        if selectedFilter == .past {
          return grouped.sorted { lhs, rhs in
            if lhs.key == "어제" { return true }
            if rhs.key == "어제" { return false }
            return lhs.key > rhs.key
          }.map { (date: $0.key, events: $0.value) }
        }

        // 오늘/미래/전체: 시간순 (오늘 → 내일 → 이후)
        return grouped.sorted { lhs, rhs in
          let priorityOrder = ["오늘": 0, "내일": 1]
          let lhsPriority = priorityOrder[lhs.key] ?? 2
          let rhsPriority = priorityOrder[rhs.key] ?? 2
          if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
          return lhs.key < rhs.key
        }.map { (date: $0.key, events: $0.value) }
      }

      /// 리스트 애니메이션 키 (DiffableDataSource 스타일)
      var eventListAnimationKey: [String] {
        groupedEvents.flatMap { section in
          [section.date] + section.events.map(\.id)
        }
      }

      /// 필터별 일정 개수
      var filterCounts: [EventFilter: Int] {
        guard let events = eventsState.value else { return [:] }
        let calendar = Calendar.current
        let todayCount = events.filter { calendar.isDateInToday($0.startAt) }.count
        return [
          .today: todayCount,
          .future: events.count - todayCount,
          .all: events.count
        ]
      }
    }

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case createEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case eventDetail(PresentationAction<PersonalEventDetail.Feature.Action>)

      public enum View: Sendable {
        case onAppear
        case refreshEvents
        case filterChanged(EventFilter)
        case createNewEventTapped
        case eventTapped(PersonalEventModel)
        case editEvent(PersonalEventModel)
        case deleteEvent(PersonalEventModel)
        case switchToGroupMode
        /// 위젯 딥링크로 개인 일정 상세 열기
        case openEventFromDeeplink(eventId: String)
        /// 토스트 닫힘
        case toastDismissed
      }

      public enum Internal: Sendable {
        case subscribeToEvents
        case eventsUpdated([PersonalEventModel])
        case fetchPastEvents
        case pastEventsLoaded([PersonalEventModel])
        case pastEventsFailed(String)
        case eventsFailed(String)
        case eventDeleted(String)
        case eventDeleteFailed(String)
        case syncPersonalCalendar
      }
    }

    private enum CancelID {
      case eventSubscription
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case let .view(viewAction):
          switch viewAction {
          case .onAppear:
            guard state.eventsState == .idle else { return .none }
            return .merge(
              .send(.internal(.subscribeToEvents)),
              .send(.internal(.syncPersonalCalendar))
            )

          case .refreshEvents:
            state.eventsState = .loading
            if state.selectedFilter == .past {
              state.pastEventsState = .idle
            }
            return .send(.internal(.subscribeToEvents))

          case .filterChanged(let filter):
            state.selectedFilter = filter
            if filter == .past && !state.pastEventsState.isLoaded {
              return .send(.internal(.fetchPastEvents))
            }
            return .none

          case .createNewEventTapped:
            state.createEvent = CreatePersonalEvent.Feature.State()
            return .none

          case .eventTapped(let event):
            state.eventDetail = PersonalEventDetail.Feature.State(event: event)
            return .none

          case .editEvent(let event):
            state.createEvent = CreatePersonalEvent.Feature.State(
              event: event,
              mode: .edit
            )
            return .none

          case .deleteEvent(let event):
            return .run { [localNotificationClient, calendarSyncClient] send in
              do {
                try await personalEventClient.deleteEvent(event.id)
                await localNotificationClient.cancel(event.notificationId)
                try? await calendarSyncClient.removePersonalEvent(event.id)
                await send(.internal(.eventDeleted(event.id)))
              } catch {
                await send(.internal(.eventDeleteFailed(error.localizedDescription)))
              }
            }

          case .switchToGroupMode:
            // RootTabFeature에서 처리
            return .none

          case .openEventFromDeeplink(let eventId):
            return .run { send in
              do {
                if let event = try await personalEventClient.getEvent(eventId) {
                  await send(.view(.eventTapped(event)))
                } else {
                  AppLogger.personal.warning("딥링크 일정을 찾을 수 없음: \(eventId)")
                }
              } catch {
                AppLogger.personal.error("딥링크 일정 조회 실패: \(error.localizedDescription)")
              }
            }

          case .toastDismissed:
            state.toastMessage = nil
            return .none
          }

        case let .internal(internalAction):
          switch internalAction {
          case .subscribeToEvents:
            if !state.eventsState.isLoaded {
              state.eventsState = .loading
            }
            return .run { send in
              var hasReceived = false
              for await events in personalEventClient.subscribeToActiveEvents(50) {
                hasReceived = true
                await send(.internal(.eventsUpdated(events)))
              }
              // 스트림이 값 없이 종료된 경우 (Auth 미로그인, Firestore 에러 등)
              if !hasReceived {
                await send(.internal(.eventsUpdated([])))
              }
            }
            .cancellable(id: CancelID.eventSubscription, cancelInFlight: true)

          case .fetchPastEvents:
            state.pastEventsState = .loading
            return .run { send in
              do {
                let pastEvents = try await personalEventClient.getPastEvents(50, nil)
                await send(.internal(.pastEventsLoaded(pastEvents)))
              } catch {
                await send(.internal(.pastEventsFailed(error.localizedDescription)))
              }
            }

          case .pastEventsLoaded(let events):
            state.pastEventsState = .loaded(events)
            return .none

          case .pastEventsFailed(let message):
            state.pastEventsState = .failed(AppError(message: message))
            return .none

          case .eventsUpdated(let events):
            state.eventsState = .loaded(events)
            return .run { [localNotificationClient] _ in
              let pendingIds = Set(
                (await localNotificationClient.pendingIds())
                  .filter { $0.hasPrefix("personal_reminder_") }
              )
              let desiredEvents = events.filter { $0.canScheduleReminder }
              let desiredIds = Set(desiredEvents.map(\.notificationId))

              // 불필요한 알림 취소
              let toCancel = Array(pendingIds.subtracting(desiredIds))
              await localNotificationClient.cancelAll(toCancel)

              // 누락된 알림 스케줄링
              for event in desiredEvents where !pendingIds.contains(event.notificationId) {
                if let date = event.reminderDate {
                  try? await localNotificationClient.schedule(
                    event.notificationId,
                    event.notificationTitle,
                    event.notificationBody,
                    date,
                    ["type": "personal_event_reminder", "eventId": event.id]
                  )
                }
              }
            }

          case .eventsFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            return .none

          case .eventDeleted:
            return .none

          case .eventDeleteFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            state.toastMessage = ToastMessage(
              type: .error,
              title: "일정 삭제에 실패했어요",
              subtitle: message,
              position: .top
            )
            return .none

          case .syncPersonalCalendar:
            return .run(priority: .background) { [calendarSyncClient] _ in
              let enabled = UserDefaults.standard.bool(
                forKey: AppConstants.UserDefaults.personalCalendarSync
              )
              let result = try? await calendarSyncClient.syncPersonalEvents(enabled)
              if let result {
                AppLogger.calendar.info("📅 [Personal] syncCalendar 완료 - \(result.description)")
              }
            }
          }

        // MARK: - CreateEvent Delegate

        case .createEvent(.presented(.delegate(.eventCreated))),
             .createEvent(.presented(.delegate(.eventUpdated))):
          state.createEvent = nil
          return .none

        case .createEvent(.presented(.delegate(.dismiss))):
          state.createEvent = nil
          return .none

        case .createEvent:
          return .none

        // MARK: - EventDetail Delegate

        case .eventDetail(.presented(.delegate(.eventDeleted))):
          state.eventDetail = nil
          return .none

        case .eventDetail(.presented(.delegate(.eventUpdated))):
          return .none

        case .eventDetail:
          return .none
        }
      }
      .ifLet(\.$createEvent, action: \.createEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.$eventDetail, action: \.eventDetail) {
        PersonalEventDetail.Feature()
      }
    }
  }
}
