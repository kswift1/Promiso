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
