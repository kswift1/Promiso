import Clients
import PhotosUI
import _PhotosUI_SwiftUI
import ComposableArchitecture
import PromisoShared

public enum GroupSettings {}

extension GroupSettings {
  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    @ObservableState
    public struct State: Equatable {
      public var group: GroupModel
      public let summary: UserGroupInfo?
      public let currentUserId: String
      public let userPlan: UserPlan

      // Members
      var membersState: LoadingState<[UserPublicModel]> = .idle
      var members: [UserPublicModel] = []

      // Sheets
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
      var editGroup: EditGroupState?

      // Notifications
      var notificationsEnabled: Bool
      var notificationPreferences: [String: Bool]
      var notificationError: String?

      public init(
        group: GroupModel,
        summary: UserGroupInfo?,
        currentUserId: String,
        userPlan: UserPlan,
        preloadedMembers: [UserPublicModel]? = nil
      ) {
        self.group = group
        self.summary = summary
        self.currentUserId = currentUserId
        self.userPlan = userPlan
        self.notificationsEnabled = summary?.notifications ?? true
        self.notificationPreferences = summary?.notificationPreferences
          ?? GroupNotificationPreferences.allEnabled

        if let preloadedMembers = preloadedMembers {
          self.membersState = .loaded(preloadedMembers)
          self.members = preloadedMembers
        }
      }

      var isHost: Bool {
        group.createdBy == currentUserId
      }

      var isProPlan: Bool {
        userPlan == .pro
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

      var minMaxMembers: Int {
        max(2, group.memberIds.count)
      }

      var maxMembersUpperLimit: Int {
        10
      }
    }

    public struct EditGroupState: Equatable {
      var description: String
      var maxMembers: Int
      var selectedPhoto: PhotosPickerItem?
      var photoData: Data?
      var isSaving: Bool = false
      var error: String?

      var canSave: Bool {
        !isSaving
      }

      public static func == (lhs: EditGroupState, rhs: EditGroupState) -> Bool {
        lhs.description == rhs.description &&
        lhs.maxMembers == rhs.maxMembers &&
        lhs.photoData == rhs.photoData &&
        lhs.isSaving == rhs.isSaving &&
        lhs.error == rhs.error
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case editGroupTapped
        case editGroupDismissed
        case editGroupDescriptionChanged(String)
        case editGroupMaxMembersChanged(Int)
        case editGroupPhotoSelected(PhotosPickerItem?)
        case editGroupSaveTapped
        case editGroupErrorDismissed
        case groupNotificationsChanged(Bool)
        case notificationPreferenceChanged(GroupNotificationPreferenceKey, Bool)
        case notificationSettingsTapped
        case membersTapped
        case inviteTapped
        case pastPromisesTapped
        case leaveGroupTapped
        case deleteGroupTapped
        case confirmLeave
        case confirmDelete
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
        case editGroupPhotoLoaded(Data?)
        case editGroupSaveResponse(Result<GroupModel, Error>)
        case groupNotificationsUpdateFailed(previousValue: Bool, message: String)
        case notificationPreferenceUpdateFailed(
          key: GroupNotificationPreferenceKey,
          previousValue: Bool,
          message: String
        )
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
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .editGroupTapped:
            state.editGroup = EditGroupState(
              description: state.group.description ?? "",
              maxMembers: state.group.maxMembers,
              selectedPhoto: nil,
              photoData: nil,
              isSaving: false,
              error: nil
            )
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .editGroupDismissed:
            state.editGroup = nil
            return .none

          case .editGroupDescriptionChanged(let text):
            state.editGroup?.description = String(text.prefix(50))
            return .none

          case .editGroupMaxMembersChanged(let value):
            guard var editGroup = state.editGroup else { return .none }
            let clamped = min(
              max(state.minMaxMembers, value),
              state.maxMembersUpperLimit
            )
            editGroup.maxMembers = clamped
            state.editGroup = editGroup
            return .none

          case .editGroupPhotoSelected(let item):
            guard var editGroup = state.editGroup else { return .none }
            editGroup.selectedPhoto = item
            state.editGroup = editGroup
            guard let item else {
              state.editGroup?.photoData = nil
              return .none
            }
            return .run { send in
              let data = try? await item.loadTransferable(type: Data.self)
              await send(.internal(.editGroupPhotoLoaded(data)))
            }

          case .editGroupSaveTapped:
            guard var editGroup = state.editGroup else { return .none }
            guard editGroup.canSave else { return .none }
            editGroup.isSaving = true
            editGroup.error = nil
            state.editGroup = editGroup

            let description = editGroup.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let photoData = editGroup.photoData
            let maxMembers = editGroup.maxMembers
            let groupId = state.group.id
            return .run { [groupClient] send in
              do {
                let updated = try await groupClient.updateGroup(
                  groupId,
                  description,
                  maxMembers,
                  photoData
                )
                await send(.internal(.editGroupSaveResponse(.success(updated))))
              } catch {
                await send(.internal(.editGroupSaveResponse(.failure(error))))
              }
            }

          case .editGroupErrorDismissed:
            state.editGroup?.error = nil
            return .none

          case .groupNotificationsChanged(let enabled):
            let previousValue = state.notificationsEnabled
            state.notificationsEnabled = enabled
            state.notificationError = nil
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupNotifications(groupId, enabled)
              } catch {
                await send(.internal(.groupNotificationsUpdateFailed(
                  previousValue: previousValue,
                  message: error.localizedDescription
                )))
              }
            }

          case .notificationPreferenceChanged(let key, let enabled):
            let previousValue = state.notificationPreferences[key.rawValue] ?? true
            state.notificationPreferences[key.rawValue] = enabled
            state.notificationError = nil
            let updatedPreferences = state.notificationPreferences
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupNotificationPreferences(
                  groupId,
                  updatedPreferences
                )
              } catch {
                await send(.internal(.notificationPreferenceUpdateFailed(
                  key: key,
                  previousValue: previousValue,
                  message: error.localizedDescription
                )))
              }
            }

          case .notificationSettingsTapped:
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .inviteTapped:
            state.showInviteSheet = true
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .pastPromisesTapped:
            return .merge(
              .send(.delegate(.pastPromisesTapped)),
              .run { [hapticFeedback] _ in
                await hapticFeedback.buttonTap()
              }
            )

          case .leaveGroupTapped:
            state.showLeaveAlert = true
            return .run { [hapticFeedback] _ in
              await hapticFeedback.warning()
            }

          case .deleteGroupTapped:
            state.showDeleteAlert = true
            return .run { [hapticFeedback] _ in
              await hapticFeedback.warning()
            }

          case .confirmLeave:
            state.showLeaveAlert = false
            state.isLeavingGroup = true
            state.leaveError = nil
            return .run { [groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.destructive()
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
            return .run { [groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.destructive()
              do {
                try await groupClient.deleteGroup(groupId)
                await send(.internal(.deleteGroupResponse(.success(()))))
              } catch {
                await send(.internal(.deleteGroupResponse(.failure(error))))
              }
            }

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
            state.notificationError = nil
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
            return .merge(
              .send(.delegate(.groupLeft)),
              .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            )

          case .leaveGroupResponse(.failure(let error)):
            state.isLeavingGroup = false
            state.leaveError = error.localizedDescription
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .deleteGroupResponse(.success):
            state.isDeletingGroup = false
            return .merge(
              .send(.delegate(.groupDeleted)),
              .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            )

          case .deleteGroupResponse(.failure(let error)):
            state.isDeletingGroup = false
            state.deleteError = error.localizedDescription
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .editGroupPhotoLoaded(let data):
            state.editGroup?.photoData = data
            return .none

          case .editGroupSaveResponse(.success(let updatedGroup)):
            state.group = updatedGroup
            state.editGroup = nil
            return .run { [hapticFeedback] _ in
              await hapticFeedback.success()
            }

          case .editGroupSaveResponse(.failure(let error)):
            state.editGroup?.isSaving = false
            state.editGroup?.error = error.localizedDescription
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .groupNotificationsUpdateFailed(let previousValue, let message):
            state.notificationsEnabled = previousValue
            state.notificationError = message
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .notificationPreferenceUpdateFailed(let key, let previousValue, let message):
            state.notificationPreferences[key.rawValue] = previousValue
            state.notificationError = message
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }
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
