import Clients
import ComposableArchitecture
import PromisoShared

public enum PastPromises {}

extension PastPromises {
  private static let pageSize = 10

  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    @ObservableState
    public struct State: Equatable {
      public let groupId: String
      public let currentUserId: String
      public let groupMembers: [UserPublicModel]?

      var promisesState: LoadingState<[PromiseModel]> = .idle
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

      /// 마지막 약속의 startAt (페이징 커서)
      var lastStartAt: Date? {
        promisesState.value?.last?.startAt
      }

      var filteredPromises: [PromiseModel] {
        let promises = promisesState.value ?? []
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let statusFiltered = promises.filter { promise in
          switch statusFilter {
          case .all:
            return true
          case .confirmed:
            return promise.isConfirmed
          case .failed:
            return !promise.isConfirmed
          }
        }

        let searchFiltered = statusFiltered.filter { promise in
          guard !query.isEmpty else { return true }
          let title = promise.title.lowercased()
          let description = promise.description?.lowercased() ?? ""
          let location = promise.locationText.lowercased()
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
        case .all: return LocalizedStrings.PastPromises.filterAll
        case .confirmed: return LocalizedStrings.PastPromises.filterConfirmed
        case .failed: return LocalizedStrings.PastPromises.filterFailed
        }
      }
    }

    public enum SortOption: String, CaseIterable, Sendable, Equatable {
      case newest
      case oldest
      case participants

      public var displayTitle: String {
        switch self {
        case .newest: return LocalizedStrings.PastPromises.sortNewest
        case .oldest: return LocalizedStrings.PastPromises.sortOldest
        case .participants: return LocalizedStrings.PastPromises.sortParticipants
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
        case promiseTapped(PromiseModel)
        case searchQueryChanged(String)
        case statusFilterChanged(StatusFilter)
        case sortOptionChanged(SortOption)
      }

      public enum Internal: Sendable {
        case fetchPastPromises
        case fetchMorePastPromises
        case pastPromisesResponse(Result<[PromiseModel], Error>)
        case morePastPromisesResponse(Result<[PromiseModel], Error>)
      }

      public enum Delegate: Sendable {
        case promiseSelected(PromiseModel)
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard case .idle = state.promisesState else { return .none }
            return .send(.internal(.fetchPastPromises))

          case .refreshTriggered:
            state.hasMore = true
            return .send(.internal(.fetchPastPromises))

          case .loadMoreTriggered:
            guard !state.isLoadingMore, state.hasMore else { return .none }
            return .send(.internal(.fetchMorePastPromises))

          case .promiseTapped(let promise):
            return .send(.delegate(.promiseSelected(promise)))

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
          case .fetchPastPromises:
            state.promisesState = .loading
            return .run { [groupId = state.groupId, promiseClient] send in
              do {
                let promises = try await promiseClient.getPastPromises(groupId, pageSize, nil)
                await send(.internal(.pastPromisesResponse(.success(promises))))
              } catch {
                await send(.internal(.pastPromisesResponse(.failure(error))))
              }
            }

          case .fetchMorePastPromises:
            state.isLoadingMore = true
            return .run { [groupId = state.groupId, lastStartAt = state.lastStartAt, promiseClient] send in
              do {
                let promises = try await promiseClient.getPastPromises(groupId, pageSize, lastStartAt)
                await send(.internal(.morePastPromisesResponse(.success(promises))))
              } catch {
                await send(.internal(.morePastPromisesResponse(.failure(error))))
              }
            }

          case .pastPromisesResponse(.success(let promises)):
            state.promisesState = .loaded(promises)
            state.hasMore = promises.count >= pageSize
            return .none

          case .pastPromisesResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none

          case .morePastPromisesResponse(.success(let newPromises)):
            state.isLoadingMore = false
            state.hasMore = newPromises.count >= pageSize
            if var existing = state.promisesState.value {
              existing.append(contentsOf: newPromises)
              state.promisesState = .loaded(existing)
            }
            return .none

          case .morePastPromisesResponse(.failure):
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
