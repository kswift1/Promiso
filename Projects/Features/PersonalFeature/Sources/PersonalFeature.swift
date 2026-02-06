import ComposableArchitecture
import SwiftUI

// MARK: - Namespace
public enum PersonalMode {}

// MARK: - Event Filter
extension PersonalMode {
  /// 개인 일정 필터
  public enum EventFilter: String, CaseIterable, Sendable, CategoryFilterItem {
    case upcoming = "다가오는"
    case today = "오늘"
    case all = "전체"
    case past = "지난"

    public var title: String { rawValue }

    public var icon: String {
      switch self {
      case .upcoming: return "clock.fill"
      case .today: return "sun.max.fill"
      case .all: return "calendar"
      case .past: return "clock.arrow.circlepath"
      }
    }

    public var selectedColor: Color {
      switch self {
      case .upcoming: return .blue
      case .today: return .orange
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

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var eventsState: LoadingState<[PersonalEventModel]> = .idle
      var selectedFilter: EventFilter = .upcoming
      @Shared var currentUser: UserPrivateModel

      @Presents var createEvent: CreatePersonalEvent.Feature.State?

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
      }

      // MARK: - Computed Properties

      /// 필터링된 일정 목록
      var filteredEvents: [PersonalEventModel] {
        guard let events = eventsState.value else { return [] }

        switch selectedFilter {
        case .upcoming:
          return events.filter { $0.isUpcoming }.sorted { $0.startAt < $1.startAt }
        case .today:
          let calendar = Calendar.current
          return events.filter { calendar.isDateInToday($0.startAt) }.sorted { $0.startAt < $1.startAt }
        case .all:
          return events.filter { !$0.isPast }.sorted { $0.startAt < $1.startAt }
        case .past:
          return events.filter { $0.isPast }.sorted { $0.startAt > $1.startAt }
        }
      }

      /// 날짜별로 그룹화된 일정
      var groupedEvents: [(date: String, events: [PersonalEventModel])] {
        let grouped = Dictionary(grouping: filteredEvents, by: { $0.dateText })

        return grouped.sorted { lhs, rhs in
          let priorityOrder = ["오늘": 0, "내일": 1]
          let lhsPriority = priorityOrder[lhs.key] ?? 2
          let rhsPriority = priorityOrder[rhs.key] ?? 2

          if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
          }
          return lhs.key < rhs.key
        }.map { (date: $0.key, events: $0.value) }
      }

      /// 필터별 일정 개수
      var filterCounts: [EventFilter: Int] {
        guard let events = eventsState.value else {
          return [:]
        }

        let calendar = Calendar.current
        return [
          .upcoming: events.filter { $0.isUpcoming }.count,
          .today: events.filter { calendar.isDateInToday($0.startAt) }.count,
          .all: events.filter { !$0.isPast }.count
          // .past는 제외 (별도 fetch)
        ]
      }
    }

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case createEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)

      public enum View: Sendable {
        case onAppear
        case refreshEvents
        case filterChanged(EventFilter)
        case createNewEventTapped
        case eventTapped(PersonalEventModel)
        case deleteEvent(PersonalEventModel)
      }

      public enum Internal: Sendable {
        case subscribeToEvents
        case eventsUpdated([PersonalEventModel])
        case eventsFailed(String)
        case eventDeleted(String)
        case eventDeleteFailed(String)
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
            return .send(.internal(.subscribeToEvents))

          case .refreshEvents:
            state.eventsState = .loading
            return .send(.internal(.subscribeToEvents))

          case .filterChanged(let filter):
            state.selectedFilter = filter
            return .none

          case .createNewEventTapped:
            state.createEvent = CreatePersonalEvent.Feature.State()
            return .none

          case .eventTapped:
            // TODO: 일정 상세 화면 열기
            return .none

          case .deleteEvent(let event):
            return .run { send in
              do {
                try await personalEventClient.deleteEvent(event.id)
                await send(.internal(.eventDeleted(event.id)))
              } catch {
                await send(.internal(.eventDeleteFailed(error.localizedDescription)))
              }
            }
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

          case .eventsUpdated(let events):
            state.eventsState = .loaded(events)
            return .none

          case .eventsFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            return .none

          case .eventDeleted:
            return .none

          case .eventDeleteFailed(let message):
            state.eventsState = .failed(AppError(message: message))
            return .none
          }

        // MARK: - CreateEvent Delegate

        case .createEvent(.presented(.delegate(.eventCreated))):
          state.createEvent = nil
          return .none

        case .createEvent(.presented(.delegate(.dismiss))):
          state.createEvent = nil
          return .none

        case .createEvent:
          return .none
        }
      }
      .ifLet(\.$createEvent, action: \.createEvent) {
        CreatePersonalEvent.Feature()
      }
    }
  }
}
