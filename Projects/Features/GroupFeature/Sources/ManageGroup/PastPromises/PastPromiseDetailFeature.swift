import ComposableArchitecture
import Clients

public enum PastPromiseDetail {}

extension PastPromiseDetail {
  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      let promise: PromiseModel
      let currentUserId: String
      var groupMembers: [UserPublicModel]?

      @Presents var memberSheet: MemberSheetState?

      public init(
        promise: PromiseModel,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.promise = promise
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }
    }

    public struct MemberSheetState: Equatable, Identifiable {
      public var id: String { title }
      let title: String
      let members: [UserPublicModel]
      let colorType: ParticipantColorType
    }

    public enum ParticipantColorType: Sendable, Equatable {
      case accepted, declined, pending
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case participantGroupTapped(title: String, userIds: [String], colorType: ParticipantColorType)
        case memberSheetDismissed
      }

      public enum Delegate: Sendable {
        case dismiss
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case let .view(.participantGroupTapped(title, userIds, colorType)):
          guard let members = state.groupMembers else { return .none }
          let resolvedMembers = userIds.compactMap { userId in
            members.first { $0.userId == userId }
          }
          state.memberSheet = MemberSheetState(
            title: title,
            members: resolvedMembers,
            colorType: colorType
          )
          return .none

        case .view(.memberSheetDismissed):
          state.memberSheet = nil
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}
