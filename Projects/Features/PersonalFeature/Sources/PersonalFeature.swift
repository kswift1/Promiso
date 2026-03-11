import Clients
import ComposableArchitecture
import CreateScheduleFeature
import PromisoShared
import SharedFeature
import SwiftUI

// MARK: - Namespace
public enum PersonalMode {}

// MARK: - Event Filter
extension PersonalMode {
  /// 개인 일정 필터
  public enum EventFilter: String, CaseIterable, Sendable, CategoryFilterItem {
    case all = "전체"
    case today = "오늘"
    case future = "미래"
    case recurring = "반복"
    case past = "과거"

    public var title: String {
      switch self {
      case .today: return LocalizedStrings.Personal.filterToday
      case .future: return LocalizedStrings.Personal.filterFuture
      case .all: return LocalizedStrings.Personal.filterAll
      case .past: return LocalizedStrings.Personal.filterPast
      case .recurring: return "반복"
      }
    }

    public var icon: String {
      switch self {
      case .today: return "sun.max.fill"
      case .future: return "clock.fill"
      case .all: return "calendar"
      case .past: return "clock.arrow.circlepath"
      case .recurring: return "repeat"
      }
    }

    public var selectedColor: Color {
      switch self {
      case .today: return .orange
      case .future: return .blue
      case .all: return .pmindigo.n500
      case .past: return Color(UIColor.systemGray)
      case .recurring: return .teal
      }
    }

    public var hasSeparatorBefore: Bool {
      self == .past || self == .recurring
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
    @Dependency(\.scheduleConflictClient) var scheduleConflictClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.weatherClient) var weatherClient
    @Dependency(\.recurringPersonalEventClient) var recurringPersonalEventClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var eventsState: LoadingState<[PersonalEventModel]> = .idle
      var pastEventsState: LoadingState<[PersonalEventModel]> = .idle
      var recurringEventsState: LoadingState<[RecurringPersonalEventModel]> = .idle
      var ongoingEvents: [PersonalEventModel] = []
      var selectedFilter: EventFilter = .all
      @Shared var currentUser: UserPrivateModel
      /// 날씨 결과 (eventId → WeatherInfo)
      var weatherByEventId: [String: WeatherInfo] = [:]
      var toastMessage: ToastMessage?
      var conflictsByEventId: [String: [ScheduleConflict]] = [:]
      var conflictCheckingIds: Set<String> = []
      var conflictDetectionThreshold: Int = 0
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      @Presents var createEvent: CreatePersonalEvent.Feature.State?
      @Presents var createRecurringEvent: CreateRecurringPersonalEvent.Feature.State?
      @Presents var eventDetail: PersonalEventDetail.Feature.State?
      @Presents var recurringEventDetail: RecurringPersonalEventDetail.Feature.State?

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
      }

      // MARK: - Computed Properties

      /// 활성 + 진행 중 일정 병합
      var activeEvents: [PersonalEventModel] {
        guard let events = eventsState.value else { return ongoingEvents }
        var seen = Set<String>()
        var merged: [PersonalEventModel] = []
        for event in events where seen.insert(event.id).inserted {
          merged.append(event)
        }
        for event in ongoingEvents where seen.insert(event.id).inserted {
          merged.append(event)
        }
        return merged
      }

      /// 필터링된 일정 목록
      var filteredEvents: [PersonalEventModel] {
        switch selectedFilter {
        case .today:
          let calendar = Calendar.current
          return activeEvents.filter { calendar.isDateInToday($0.startAt) || $0.isOngoing }
            .sorted { $0.startAt < $1.startAt }
        case .future:
          let calendar = Calendar.current
          return activeEvents.filter { !calendar.isDateInToday($0.startAt) && !$0.isOngoing }
            .sorted { $0.startAt < $1.startAt }
        case .all:
          return activeEvents.sorted { $0.startAt < $1.startAt }
        case .past:
          guard let events = pastEventsState.value else { return [] }
          return events.sorted { $0.startAt > $1.startAt }
        case .recurring:
          // 반복 일정은 별도 뷰에서 처리
          return []
        }
      }

      /// 날짜별로 그룹화된 일정
      var groupedEvents: [(day: Date, title: String, events: [PersonalEventModel])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
          calendar.startOfDay(for: event.startAt)
        }

        return grouped
          .sorted { lhs, rhs in
            if selectedFilter == .past {
              return lhs.key > rhs.key
            }
            return lhs.key < rhs.key
          }
          .map { day, events in
            let title: String
            if calendar.isDateInToday(day) {
              title = LocalizedStrings.DateFormat.today
            } else if calendar.isDateInTomorrow(day) {
              title = LocalizedStrings.DateFormat.tomorrow
            } else if calendar.isDateInYesterday(day) {
              title = LocalizedStrings.DateFormat.yesterday
            } else {
              title = LocalizedDateFormatters.monthDayString(from: day)
            }

            let sortedEvents = events.sorted { lhs, rhs in
              if selectedFilter == .past {
                return lhs.startAt > rhs.startAt
              }
              return lhs.startAt < rhs.startAt
            }

            return (day: day, title: title, events: sortedEvents)
          }
      }

      /// 리스트 애니메이션 키 (DiffableDataSource 스타일)
      var eventListAnimationKey: [String] {
        groupedEvents.flatMap { section in
          [String(Int(section.day.timeIntervalSince1970))] + section.events.map(\.id)
        }
      }

      /// 필터별 일정 개수
      var filterCounts: [EventFilter: Int] {
        let events = activeEvents
        guard eventsState.value != nil else { return [:] }
        let calendar = Calendar.current
        let todayCount = events.filter { calendar.isDateInToday($0.startAt) || $0.isOngoing }.count
        let futureCount = events.filter { !calendar.isDateInToday($0.startAt) && !$0.isOngoing }.count
        var counts: [EventFilter: Int] = [
          .today: todayCount,
          .future: futureCount,
          .all: events.count
        ]
        // 반복 일정 카운트 (로드된 경우에만)
        if let recurringEvents = recurringEventsState.value {
          counts[.recurring] = recurringEvents.count
        }
        return counts
      }
    }

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case createEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case createRecurringEvent(PresentationAction<CreateRecurringPersonalEvent.Feature.Action>)
      case eventDetail(PresentationAction<PersonalEventDetail.Feature.Action>)
      case recurringEventDetail(PresentationAction<RecurringPersonalEventDetail.Feature.Action>)

      public enum View: Sendable {
        case onAppear
        case refreshEvents
        case filterChanged(EventFilter)
        case createNewEventTapped
        case createOneTimeEventTapped
        case createRecurringEventTapped
        case eventTapped(PersonalEventModel)
        case editEvent(PersonalEventModel)
        case deleteEvent(PersonalEventModel)
        case recurringEventTapped(RecurringPersonalEventModel)
        case editRecurringEvent(RecurringPersonalEventModel)
        case deleteRecurringEvent(RecurringPersonalEventModel)
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
        case ongoingEventsLoaded([PersonalEventModel])
        case refreshProFeatures([PersonalEventModel])
        case checkConflicts([PersonalEventModel])
        case conflictsLoaded(eventId: String, [ScheduleConflict])
        case conflictCheckFailed(eventId: String)
        case conflictSettingsLoaded(Int)
        case fetchWeather([PersonalEventModel])
        case weatherBatchResponse([String: WeatherInfo])
        case fetchRecurringEvents
        case recurringEventsLoaded([RecurringPersonalEventModel])
        case recurringEventsFailed(String)
        case recurringEventDeleted(String)
        case recurringEventDeleteFailed(String)
      }
    }

    private enum CancelID {
      case eventSubscription
      case conflictCheck
      case weatherFetch
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case let .view(viewAction):
          switch viewAction {
          case .onAppear:
            guard state.eventsState == .idle else { return .none }
            let userId = state.currentUser.userId
            return .merge(
              .send(.internal(.subscribeToEvents)),
              .send(.internal(.syncPersonalCalendar)),
              .run { [userSettingsClient] send in
                if let settings = try? await userSettingsClient.fetchSettings(userId) {
                  await send(.internal(.conflictSettingsLoaded(settings.conflictDetectionThreshold)))
                }
              }
            )

          case .refreshEvents:
            state.eventsState = .loading
            state.ongoingEvents = []
            if state.selectedFilter == .past {
              state.pastEventsState = .idle
            }
            return .send(.internal(.subscribeToEvents))

          case .filterChanged(let filter):
            state.selectedFilter = filter
            if filter == .past && !state.pastEventsState.isLoaded {
              return .send(.internal(.fetchPastEvents))
            }
            if filter == .recurring && state.recurringEventsState == .idle {
              return .send(.internal(.fetchRecurringEvents))
            }
            return .none

          case .createNewEventTapped:
            state.createEvent = CreatePersonalEvent.Feature.State()
            return .none

          case .createOneTimeEventTapped:
            state.createEvent = CreatePersonalEvent.Feature.State()
            return .none

          case .createRecurringEventTapped:
            state.createRecurringEvent = CreateRecurringPersonalEvent.Feature.State()
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
                await send(.internal(.eventDeleteFailed(LocalizedStrings.Error.unknownError)))
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

          case .recurringEventTapped(let event):
            state.recurringEventDetail = RecurringPersonalEventDetail.Feature.State(
              recurringEvent: event
            )
            return .none

          case .editRecurringEvent(let event):
            state.createRecurringEvent = CreateRecurringPersonalEvent.Feature.State(
              event: event,
              mode: .edit
            )
            return .none

          case .deleteRecurringEvent(let event):
            return .run { [localNotificationClient, recurringPersonalEventClient] send in
              do {
                try await recurringPersonalEventClient.deleteEvent(event.id)
                // 반복 알림 취소
                var notificationIds = [
                  "recurring-\(event.id)-daily",
                  "recurring-\(event.id)-monthly",
                ]
                for weekday in 1...7 {
                  notificationIds.append("recurring-\(event.id)-weekly-\(weekday)")
                }
                await localNotificationClient.cancelAll(notificationIds)
                await send(.internal(.recurringEventDeleted(event.id)))
              } catch {
                await send(.internal(.recurringEventDeleteFailed(LocalizedStrings.Error.unknownError)))
              }
            }
          }

        case let .internal(internalAction):
          switch internalAction {
          case .subscribeToEvents:
            if !state.eventsState.isLoaded {
              state.eventsState = .loading
            }
            return .merge(
              .run { send in
                var hasReceived = false
                let activeEventsStream = await personalEventClient.subscribeToActiveEvents(50)
                for await events in activeEventsStream {
                  hasReceived = true
                  await send(.internal(.eventsUpdated(events)))
                }
                // 스트림이 값 없이 종료된 경우 (Auth 미로그인, Firestore 에러 등)
                if !hasReceived {
                  await send(.internal(.eventsUpdated([])))
                }
              }
              .cancellable(id: CancelID.eventSubscription, cancelInFlight: true),
              .run { send in
                do {
                  let ongoing = try await personalEventClient.getOngoingEvents(20)
                  await send(.internal(.ongoingEventsLoaded(ongoing)))
                } catch {
                  AppLogger.personal.error("📅 [PersonalEvent] 진행 중 일정 조회 실패: \(error.localizedDescription)")
                }
              }
            )

          case .fetchPastEvents:
            state.pastEventsState = .loading
            return .run { send in
              do {
                let pastEvents = try await personalEventClient.getPastEvents(50, nil)
                await send(.internal(.pastEventsLoaded(pastEvents)))
              } catch {
                await send(.internal(.pastEventsFailed(LocalizedStrings.Error.unknownError)))
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
            let notificationEffect: Effect<Action> = .run { [localNotificationClient] _ in
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
            return .merge(
              notificationEffect,
              .send(.internal(.refreshProFeatures(events)))
            )

          case .eventsFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            return .none

          case .eventDeleted:
            return .none

          case .eventDeleteFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.eventDeleteFailed,
              subtitle: message,
              position: .top
            )
            return .none

          case .refreshProFeatures(let events):
            guard state.isPro else { return .none }
            return .merge(
              .send(.internal(.checkConflicts(events))),
              .send(.internal(.fetchWeather(events)))
            )

          case .checkConflicts(let events):
            let userId = state.currentUser.userId
            let threshold = state.conflictDetectionThreshold
            guard threshold >= 0 else {
              AppLogger.personal.debug("[ConflictCheck] threshold=\(threshold), 충돌 체크 스킵")
              return .none
            }
            let futureEvents = events.filter { $0.startAt > Date() }
            AppLogger.personal.debug("[ConflictCheck] 전체 \(events.count)건 중 미래 \(futureEvents.count)건")
            guard !futureEvents.isEmpty else { return .none }
            for event in futureEvents {
              state.conflictCheckingIds.insert(event.id)
            }
            return .merge(futureEvents.map { event in
              .run { [scheduleConflictClient] send in
                do {
                  let conflicts = try await scheduleConflictClient.checkConflicts(
                    userId,
                    event.startAt,
                    event.endAt,
                    Set([event.id]),
                    threshold
                  )
                  await send(.internal(.conflictsLoaded(eventId: event.id, conflicts)))
                } catch {
                  AppLogger.personal.error("[ConflictCheck] CF 실패 eventId=\(event.id): \(error)")
                  await send(.internal(.conflictCheckFailed(eventId: event.id)))
                }
              }
            })
            .cancellable(id: CancelID.conflictCheck, cancelInFlight: true)

          case .conflictsLoaded(let eventId, let conflicts):
            state.conflictCheckingIds.remove(eventId)
            state.conflictsByEventId[eventId] = conflicts
            return .none

          case .conflictCheckFailed(let eventId):
            state.conflictCheckingIds.remove(eventId)
            return .none

          case .conflictSettingsLoaded(let threshold):
            state.conflictDetectionThreshold = threshold
            return .none

          case .fetchWeather(let events):
            let existing = state.weatherByEventId
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)
            let targets = events.filter { event in
              event.location?.latitude != nil &&
              event.location?.longitude != nil &&
              event.startAt > Date() &&
              event.startAt < maxDate &&
              existing[event.id] == nil
            }
            guard !targets.isEmpty else { return .none }
            return .run { [weatherClient] send in
              var updates: [String: WeatherInfo] = [:]
              await withTaskGroup(of: (String, WeatherInfo?).self) { group in
                for event in targets {
                  group.addTask {
                    guard let lat = event.location?.latitude,
                          let lng = event.location?.longitude else { return (event.id, nil) }
                    let info = try? await weatherClient.getWeather(lat, lng, event.startAt)
                    return (event.id, info)
                  }
                }
                for await (id, info) in group {
                  guard let info else { continue }
                  updates[id] = info
                }
              }
              guard !updates.isEmpty else { return }
              await send(.internal(.weatherBatchResponse(updates)))
            }
            .cancellable(id: CancelID.weatherFetch, cancelInFlight: true)

          case .weatherBatchResponse(let updates):
            for (id, info) in updates {
              state.weatherByEventId[id] = info
            }
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

          case .ongoingEventsLoaded(let events):
            state.ongoingEvents = events
            return .none

          case .fetchRecurringEvents:
            state.recurringEventsState = .loading
            return .run { [recurringPersonalEventClient] send in
              do {
                let events = try await recurringPersonalEventClient.getAllEvents()
                await send(.internal(.recurringEventsLoaded(events)))
              } catch {
                await send(.internal(.recurringEventsFailed(LocalizedStrings.Error.unknownError)))
              }
            }

          case .recurringEventsLoaded(let events):
            state.recurringEventsState = .loaded(events)
            return .none

          case .recurringEventsFailed(let message):
            state.recurringEventsState = .failed(AppError(message: message))
            return .none

          case .recurringEventDeleted(let eventId):
            // 목록에서 삭제된 항목 제거
            if var events = state.recurringEventsState.value {
              events.removeAll { $0.id == eventId }
              state.recurringEventsState = .loaded(events)
            }
            return .none

          case .recurringEventDeleteFailed(let message):
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.eventDeleteFailed,
              subtitle: message,
              position: .top
            )
            return .none
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

        // MARK: - CreateRecurringEvent Delegate

        case .createRecurringEvent(.presented(.delegate(.eventCreated))),
             .createRecurringEvent(.presented(.delegate(.eventUpdated))):
          state.createRecurringEvent = nil
          // 반복 일정 목록이 이미 로드된 경우 재조회
          if state.recurringEventsState.isLoaded {
            return .send(.internal(.fetchRecurringEvents))
          }
          return .none

        case .createRecurringEvent(.presented(.delegate(.dismiss))):
          state.createRecurringEvent = nil
          return .none

        case .createRecurringEvent:
          return .none

        // MARK: - EventDetail Delegate

        case .eventDetail(.presented(.delegate(.eventDeleted))):
          state.eventDetail = nil
          return .none

        case .eventDetail(.presented(.delegate(.eventUpdated))):
          return .none

        case .eventDetail:
          return .none

        // MARK: - RecurringEventDetail Delegate

        case .recurringEventDetail(.presented(.delegate(.eventDeleted(let id)))):
          // 목록에서 삭제된 항목 제거
          if var events = state.recurringEventsState.value {
            events.removeAll { $0.id == id }
            state.recurringEventsState = .loaded(events)
          }
          state.recurringEventDetail = nil
          return .none

        case .recurringEventDetail(.presented(.delegate(.eventUpdated(let updated)))):
          // 목록에서 수정된 항목 업데이트
          if var events = state.recurringEventsState.value,
             let index = events.firstIndex(where: { $0.id == updated.id }) {
            events[index] = updated
            state.recurringEventsState = .loaded(events)
          }
          return .none

        case .recurringEventDetail:
          return .none
        }
      }
      .ifLet(\.$createEvent, action: \.createEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.$createRecurringEvent, action: \.createRecurringEvent) {
        CreateRecurringPersonalEvent.Feature()
      }
      .ifLet(\.$eventDetail, action: \.eventDetail) {
        PersonalEventDetail.Feature()
      }
      .ifLet(\.$recurringEventDetail, action: \.recurringEventDetail) {
        RecurringPersonalEventDetail.Feature()
      }
    }
  }
}

// MARK: - EventKitClientError Localization

extension EventKitClientError {
  var localizedMessage: String {
    switch self {
    case .accessDenied: return LocalizedStrings.Error.calendarAccessDenied
    case .accessRestricted: return LocalizedStrings.Error.calendarAccessRestricted
    case .writeNotAllowed: return LocalizedStrings.Error.calendarWriteNotAllowed
    case .saveFailed(_): return LocalizedStrings.Error.calendarSaveFailed
    case .eventStoreError(_): return LocalizedStrings.Error.calendarStoreError
    case .unknown(_): return LocalizedStrings.Error.unknownError
    }
  }
}
