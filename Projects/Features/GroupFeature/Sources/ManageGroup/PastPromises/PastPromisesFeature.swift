import Clients
import ComposableArchitecture
import PromisoShared

public enum PastPromises {}

extension PastPromises {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    @ObservableState
    public struct State: Equatable {
      public let groupId: String
      public let currentUserId: String
      public let groupMembers: [UserPublicModel]?

      var promisesState: LoadingState<[PromiseModel]> = .idle

      public init(
        groupId: String,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case onAppear
        case refreshTriggered
        case promiseTapped(PromiseModel)
      }

      public enum Internal: Sendable {
        case fetchPastPromises
        case pastPromisesResponse(Result<[PromiseModel], Error>)
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
            return .send(.internal(.fetchPastPromises))

          case .promiseTapped(let promise):
            return .send(.delegate(.promiseSelected(promise)))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPastPromises:
            state.promisesState = .loading
            return .run { [groupId = state.groupId, promiseClient] send in
              do {
                let promises = try await promiseClient.getPastPromises(groupId, 50)
                await send(.internal(.pastPromisesResponse(.success(promises))))
              } catch {
                await send(.internal(.pastPromisesResponse(.failure(error))))
              }
            }

          case .pastPromisesResponse(.success(let promises)):
            state.promisesState = .loaded(promises)
            return .none

          case .pastPromisesResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
