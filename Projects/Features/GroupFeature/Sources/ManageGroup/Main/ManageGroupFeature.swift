import Clients
import ComposableArchitecture
import PromisoShared

public enum ManageGroup {}

extension ManageGroup {
  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.userProfileClient) var userProfileClient

    @ObservableState
    public struct State: Equatable {
      public let group: GroupModel
      public let summary: GroupSummary?
      public let currentUserId: String

      // Members
      var membersState: LoadingState<[UserPublic]> = .idle
      var members: [UserPublic] = []

      // Leave/Delete
      var isLeavingGroup: Bool = false
      var isDeletingGroup: Bool = false
      var leaveError: String?
      var deleteError: String?

      public init(
        group: GroupModel,
        summary: GroupSummary?,
        currentUserId: String,
        preloadedMembers: [UserPublic]? = nil
      ) {
        self.group = group
        self.summary = summary
        self.currentUserId = currentUserId

        // preloadedMembers가 있으면 바로 사용
        if let preloadedMembers = preloadedMembers {
          self.membersState = .loaded(preloadedMembers)
          self.members = preloadedMembers
        }
      }

      var isHost: Bool {
        group.createdBy == currentUserId
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case onAppear
        case leaveGroupTapped
        case deleteGroupTapped
        case confirmLeave
        case confirmDelete
        case cancelLeave
        case cancelDelete
        case dismissError
      }

      public enum Internal: Sendable {
        case fetchMembers
        case membersResponse(Result<[UserPublic], Error>)
        case leaveGroupResponse(Result<Void, Error>)
        case deleteGroupResponse(Result<Void, Error>)
      }

      public enum Delegate: Sendable {
        case groupLeft
        case groupDeleted
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 이미 멤버가 로드되어 있으면 조회하지 않음
            guard case .idle = state.membersState else { return .none }
            return .send(.internal(.fetchMembers))

          case .leaveGroupTapped:
            // 리브 확인 alert는 View에서 처리
            return .none

          case .deleteGroupTapped:
            // 삭제 확인 alert는 View에서 처리
            return .none

          case .confirmLeave:
            state.isLeavingGroup = true
            state.leaveError = nil
            return .run { [groupId = state.group.id] send in
              do {
                try await groupClient.leaveGroup(groupId)
                await send(.internal(.leaveGroupResponse(.success(()))))
              } catch {
                await send(.internal(.leaveGroupResponse(.failure(error))))
              }
            }

          case .confirmDelete:
            state.isDeletingGroup = true
            state.deleteError = nil
            return .run { [groupId = state.group.id] send in
              do {
                try await groupClient.deleteGroup(groupId)
                await send(.internal(.deleteGroupResponse(.success(()))))
              } catch {
                await send(.internal(.deleteGroupResponse(.failure(error))))
              }
            }

          case .cancelLeave, .cancelDelete:
            return .none

          case .dismissError:
            state.leaveError = nil
            state.deleteError = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchMembers:
            state.membersState = .loading
            return .run { [groupId = state.group.id] send in
              do {
                let members = try await groupClient.fetchGroupMembers(groupId)
                await send(.internal(.membersResponse(.success(members))))
              } catch {
                await send(.internal(.membersResponse(.failure(error))))
              }
            }

          case .membersResponse(.success(let members)):
            state.membersState = .loaded(members)
            state.members = members
            return .none

          case .membersResponse(.failure(let error)):
            state.membersState = .failed(error)
            return .none

          case .leaveGroupResponse(.success):
            state.isLeavingGroup = false
            return .send(.delegate(.groupLeft))

          case .leaveGroupResponse(.failure(let error)):
            state.isLeavingGroup = false
            state.leaveError = error.localizedDescription
            return .none

          case .deleteGroupResponse(.success):
            state.isDeletingGroup = false
            return .send(.delegate(.groupDeleted))

          case .deleteGroupResponse(.failure(let error)):
            state.isDeletingGroup = false
            state.deleteError = error.localizedDescription
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
