import Clients
import ComposableArchitecture
import PromisoShared

public enum GroupSettings {}

extension GroupSettings {
  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient

    @ObservableState
    public struct State: Equatable {
      public let group: GroupModel
      public let summary: UserGroupInfo?
      public let currentUserId: String

      // Members
      var membersState: LoadingState<[UserPublicModel]> = .idle
      var members: [UserPublicModel] = []

      // Sheets
      var showMemberSheet: Bool = false
      var showInviteSheet: Bool = false

      // Leave/Delete
      var isLeavingGroup: Bool = false
      var isDeletingGroup: Bool = false
      var showLeaveAlert: Bool = false
      var showDeleteAlert: Bool = false
      var leaveError: String?
      var deleteError: String?

      // Image Detail
      var selectedMemberForImage: UserPublicModel?

      public init(
        group: GroupModel,
        summary: UserGroupInfo?,
        currentUserId: String,
        preloadedMembers: [UserPublicModel]? = nil
      ) {
        self.group = group
        self.summary = summary
        self.currentUserId = currentUserId

        if let preloadedMembers = preloadedMembers {
          self.membersState = .loaded(preloadedMembers)
          self.members = preloadedMembers
        }
      }

      var isHost: Bool {
        group.createdBy == currentUserId
      }

      var memberCount: Int {
        members.count
      }

      var inviteCode: String {
        group.inviteCode
      }

      var inviteLink: String {
        "https://promiso.app/invite/\(group.inviteCode)"
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case membersTapped
        case inviteTapped
        case pastPromisesTapped
        case leaveGroupTapped
        case deleteGroupTapped
        case confirmLeave
        case confirmDelete
        case dismissMemberSheet
        case dismissInviteSheet
        case dismissLeaveAlert
        case dismissDeleteAlert
        case dismissError
        case memberImageTapped(UserPublicModel)
        case imageDetailDismissed
      }

      public enum Internal: Sendable {
        case fetchMembers
        case membersResponse(Result<[UserPublicModel], Error>)
        case leaveGroupResponse(Result<Void, Error>)
        case deleteGroupResponse(Result<Void, Error>)
      }

      public enum Delegate: Sendable {
        case groupLeft
        case groupDeleted
        case pastPromisesTapped
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard case .idle = state.membersState else { return .none }
            return .send(.internal(.fetchMembers))

          case .membersTapped:
            state.showMemberSheet = true
            return .none

          case .inviteTapped:
            state.showInviteSheet = true
            return .none

          case .pastPromisesTapped:
            return .send(.delegate(.pastPromisesTapped))

          case .leaveGroupTapped:
            state.showLeaveAlert = true
            return .none

          case .deleteGroupTapped:
            state.showDeleteAlert = true
            return .none

          case .confirmLeave:
            state.showLeaveAlert = false
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
            state.showDeleteAlert = false
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

          case .dismissMemberSheet:
            state.showMemberSheet = false
            return .none

          case .dismissInviteSheet:
            state.showInviteSheet = false
            return .none

          case .dismissLeaveAlert:
            state.showLeaveAlert = false
            return .none

          case .dismissDeleteAlert:
            state.showDeleteAlert = false
            return .none

          case .dismissError:
            state.leaveError = nil
            state.deleteError = nil
            return .none

          case .memberImageTapped(let member):
            state.selectedMemberForImage = member
            return .none

          case .imageDetailDismissed:
            state.selectedMemberForImage = nil
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

// MARK: - Sendable

extension GroupSettings.Feature.State: Sendable {}
