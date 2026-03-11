import Clients
import ComposableArchitecture
import PromisoShared

public enum PastSchedules {}

extension PastSchedules {
  private static let pageSize = 10

  @Reducer
  public struct Feature {
    @Dependency(\.scheduleClient) var scheduleClient

    @ObservableState
    public struct State: Equatable {
      public let groupId: String
      public let currentUserId: String
      public let groupMembers: [UserPublicModel]?

      var schedulesState: LoadingState<[ScheduleModel]> = .idle
      var isLoadingMore: Bool = false
      var hasMore: Bool = true
      var searchQuery: String = ""
      var statusFilter: StatusFilter = .all
      var sortOption: SortOption = .newest

      public init(
        groupId: String,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }

      /// 마지막 일정의 startAt (페이징 커서)
      var lastStartAt: Date? {
        schedulesState.value?.last?.startAt
      }

      var filteredSchedules: [ScheduleModel] {
        let schedules = schedulesState.value ?? []
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let statusFiltered = schedules.filter { schedule in
          switch statusFilter {
          case .all:
            return true
          case .confirmed:
            return schedule.isConfirmed
          case .failed:
            return !schedule.isConfirmed
          }
        }

        let searchFiltered = statusFiltered.filter { schedule in
          guard !query.isEmpty else { return true }
          let title = schedule.title.lowercased()
          let description = schedule.description?.lowercased() ?? ""
          let location = schedule.locationText.lowercased()
          return title.contains(query) || description.contains(query) || location.contains(query)
        }

        switch sortOption {
        case .newest:
          return searchFiltered.sorted { $0.startAt > $1.startAt }
        case .oldest:
          return searchFiltered.sorted { $0.startAt < $1.startAt }
        case .participants:
          return searchFiltered.sorted { lhs, rhs in
            lhs.votes.acceptedCount > rhs.votes.acceptedCount
          }
        }
      }
    }

    public enum StatusFilter: String, CaseIterable, Sendable, Equatable {
      case all
      case confirmed
      case failed

      public var displayTitle: String {
        switch self {
        case .all: return LocalizedStrings.PastSchedules.filterAll
        case .confirmed: return LocalizedStrings.PastSchedules.filterConfirmed
        case .failed: return LocalizedStrings.PastSchedules.filterFailed
        }
      }
    }

    public enum SortOption: String, CaseIterable, Sendable, Equatable {
      case newest
      case oldest
      case participants

      public var displayTitle: String {
        switch self {
        case .newest: return LocalizedStrings.PastSchedules.sortNewest
        case .oldest: return LocalizedStrings.PastSchedules.sortOldest
        case .participants: return LocalizedStrings.PastSchedules.sortParticipants
        }
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case onAppear
        case refreshTriggered
        case loadMoreTriggered
        case scheduleTapped(ScheduleModel)
        case searchQueryChanged(String)
        case statusFilterChanged(StatusFilter)
        case sortOptionChanged(SortOption)
      }

      public enum Internal: Sendable {
        case fetchPastSchedules
        case fetchMorePastSchedules
        case pastSchedulesResponse(Result<[ScheduleModel], Error>)
        case morePastSchedulesResponse(Result<[ScheduleModel], Error>)
      }

      public enum Delegate: Sendable {
        case scheduleSelected(ScheduleModel)
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard case .idle = state.schedulesState else { return .none }
            return .send(.internal(.fetchPastSchedules))

          case .refreshTriggered:
            state.hasMore = true
            return .send(.internal(.fetchPastSchedules))

          case .loadMoreTriggered:
            guard !state.isLoadingMore, state.hasMore else { return .none }
            return .send(.internal(.fetchMorePastSchedules))

          case .scheduleTapped(let schedule):
            return .send(.delegate(.scheduleSelected(schedule)))

          case .searchQueryChanged(let query):
            state.searchQuery = query
            return .none

          case .statusFilterChanged(let filter):
            state.statusFilter = filter
            return .none

          case .sortOptionChanged(let option):
            state.sortOption = option
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPastSchedules:
            state.schedulesState = .loading
            return .run { [groupId = state.groupId, scheduleClient] send in
              do {
                let schedules = try await scheduleClient.getPastSchedules(groupId, pageSize, nil)
                await send(.internal(.pastSchedulesResponse(.success(schedules))))
              } catch {
                await send(.internal(.pastSchedulesResponse(.failure(error))))
              }
            }

          case .fetchMorePastSchedules:
            state.isLoadingMore = true
            return .run { [groupId = state.groupId, lastStartAt = state.lastStartAt, scheduleClient] send in
              do {
                let schedules = try await scheduleClient.getPastSchedules(groupId, pageSize, lastStartAt)
                await send(.internal(.morePastSchedulesResponse(.success(schedules))))
              } catch {
                await send(.internal(.morePastSchedulesResponse(.failure(error))))
              }
            }

          case .pastSchedulesResponse(.success(let schedules)):
            state.schedulesState = .loaded(schedules)
            state.hasMore = schedules.count >= pageSize
            return .none

          case .pastSchedulesResponse(.failure(let error)):
            state.schedulesState = .failed(error)
            return .none

          case .morePastSchedulesResponse(.success(let newSchedules)):
            state.isLoadingMore = false
            state.hasMore = newSchedules.count >= pageSize
            if var existing = state.schedulesState.value {
              existing.append(contentsOf: newSchedules)
              state.schedulesState = .loaded(existing)
            }
            return .none

          case .morePastSchedulesResponse(.failure):
            state.isLoadingMore = false
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
