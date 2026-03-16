import ComposableArchitecture
import PromisoShared
import Clients

public enum GroupOverview {}

extension GroupOverview {
  @Reducer
  public struct Feature {

    @ObservableState
    public struct State: Equatable {
      var groups: [UserGroupInfo]
      @Shared var currentUser: UserPrivateModel
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      public init(groups: [UserGroupInfo], currentUser: Shared<UserPrivateModel>) {
        self.groups = groups
        self._currentUser = currentUser
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(DelegateAction)
    }

    @CasePathable
    public enum ViewAction: Sendable {
      case groupTapped(UserGroupInfo)
      case createGroupTapped
      case joinGroupTapped
    }

    @CasePathable
    public enum DelegateAction: Equatable, Sendable {
      case groupSelected(UserGroupInfo)
      case createGroup
      case joinGroup
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.groupTapped(let group)):
          return .send(.delegate(.groupSelected(group)))
        case .view(.createGroupTapped):
          return .send(.delegate(.createGroup))
        case .view(.joinGroupTapped):
          return .send(.delegate(.joinGroup))
        case .delegate:
          return .none
        }
      }
    }
  }
}
