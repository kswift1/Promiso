import Clients
import ComposableArchitecture
import Shared

public enum ManageGroup {}

extension ManageGroup {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable {
      public let group: GroupModel
      public let summary: GroupSummary?

      public init(group: GroupModel, summary: GroupSummary?) {
        self.group = group
        self.summary = summary
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)

      public enum ViewAction: Sendable {
        case onAppear
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { _, _ in .none }
    }
  }
}
