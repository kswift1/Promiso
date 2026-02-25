// MARK: - {Name}Feature Template
// 사용법: {Name}을 실제 Feature 이름으로 교체

import Clients
import ComposableArchitecture
import PromisoShared

// MARK: - Feature Namespace

public enum {Name} {}

// MARK: - Feature Implementation

extension {Name} {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable, Sendable {
      // 도메인 상태
      var items: [Item] = []
      var isLoading = false
      var errorMessage: String?

      // 공유 상태 (필요 시)
      // @Shared public var currentUser: UserPrivateModel

      // 네비게이션 (필요 시)
      // @Presents var destination: Destination.State?
      // var path = StackState<Path.State>()

      public init() {}
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
      // case path(StackActionOf<Path>)  // 네비게이션 있을 시

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case refreshTapped
        case itemTapped(String)
      }

      @CasePathable
      public enum InternalAction: Sendable {
        case dataResponse(Result<[Item], Error>)
      }

      public enum DelegateAction: Sendable {
        case itemSelected(Item)
      }
    }

    @Dependency(\.someClient) var someClient

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        // MARK: - View Actions
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.isLoading = true
            return .send(.internal(.dataResponse(
              .success([])  // placeholder
            )))
            // 실제 구현:
            // return .run { [someClient] send in
            //   await send(.internal(.dataResponse(
            //     Result { try await someClient.fetch() }
            //   )))
            // }

          case .refreshTapped:
            return .send(.view(.onAppear))

          case let .itemTapped(id):
            guard let item = state.items.first(where: { $0.id == id }) else {
              return .none
            }
            return .send(.delegate(.itemSelected(item)))
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case let .dataResponse(.success(items)):
            state.isLoading = false
            state.items = items
            return .none

          case let .dataResponse(.failure(error)):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none
          }

        // MARK: - Delegate Actions
        case .delegate:
          return .none
        }
      }
      // .forEach(\.path, action: \.path)  // 네비게이션 있을 시
    }
  }
}

// MARK: - Computed Properties

extension {Name}.Feature.State {
  var isEmpty: Bool {
    items.isEmpty && !isLoading
  }
}
