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
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.analyticsClient) var analyticsClient

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
      var notificationSettings: GroupNotificationSettings
      var notificationError: String?
      var systemAuthStatus: NotificationAuthorizationStatus = .notDetermined

      // Transfer Host
      var isShowingTransferSheet: Bool = false
      var selectedNewHost: UserPublicModel?
      var isTransferringHost: Bool = false
      var transferError: String?

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
        self.notificationSettings = summary?.notifications ?? GroupNotificationSettings()

        if let preloadedMembers = preloadedMembers {
          self.membersState = .loaded(preloadedMembers)
          self.members = preloadedMembers
        }
      }

      var isHost: Bool {
        group.createdBy == currentUserId
      }

      /// 호스트 양도 가능 여부 (호스트이고 다른 멤버가 있을 때)
      var canTransferHost: Bool {
        isHost && members.count > 1
      }

      /// 호스트 양도 대상 목록 (본인 제외)
      var transferCandidates: [UserPublicModel] {
        members.filter { $0.userId != currentUserId }
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
        case requestNotificationPermission
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
        case openSystemSettingsTapped
        // Transfer Host
        case transferHostTapped
        case selectNewHost(UserPublicModel)
        case confirmTransferHost
        case dismissTransferSheet
        case dismissTransferError
      }

      public enum Internal: Sendable {
        case fetchMembers
        case membersResponse(Result<[UserPublicModel], Error>)
        case leaveGroupResponse(Result<Void, Error>)
        case deleteGroupResponse(Result<Void, Error>)
        case editGroupPhotoLoaded(Data?)
        case editGroupSaveResponse(Result<GroupModel, Error>)
        case systemAuthStatusFetched(NotificationAuthorizationStatus)
        case notificationPermissionResponse(Bool)
        case groupNotificationsUpdateFailed(previousValue: Bool, message: String)
        case notificationPreferenceUpdateFailed(
          key: GroupNotificationPreferenceKey,
          previousValue: Bool,
          message: String
        )
        case transferHostResponse(Result<Void, Error>)
      }

      public enum Delegate: Sendable {
        case groupLeft
        case groupDeleted
        case pastPromisesTapped
        case hostTransferred
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            let shouldFetchMembers = state.membersState == .idle
            return .run { [notificationClient] send in
              // 시스템 알림 권한 상태 로드
              let systemStatus = await notificationClient.getAuthorizationStatus()
              await send(.internal(.systemAuthStatusFetched(systemStatus)))

              // 멤버 로드
              if shouldFetchMembers {
                await send(.internal(.fetchMembers))
              }
            }

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

          case .requestNotificationPermission:
            return .run { [notificationClient, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                let granted = try await notificationClient.requestAuthorization()
                await send(.internal(.notificationPermissionResponse(granted)))
              } catch {
                await send(.internal(.notificationPermissionResponse(false)))
              }
            }

          case .groupNotificationsChanged(let enabled):
            let previousValue = state.notificationSettings.enabled
            state.notificationSettings.enabled = enabled
            state.notificationError = nil
            let updatedSettings = state.notificationSettings

            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                // 그룹 알림 설정 업데이트
                try await groupClient.updateGroupNotificationSettings(
                  groupId,
                  updatedSettings
                )
              } catch {
                await send(.internal(.groupNotificationsUpdateFailed(
                  previousValue: previousValue,
                  message: error.localizedDescription
                )))
              }
            }

          case .notificationPreferenceChanged(let key, let enabled):
            let previousValue = state.notificationSettings.value(for: key)
            state.notificationSettings.setValue(enabled, for: key)
            state.notificationError = nil
            let updatedSettings = state.notificationSettings
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupNotificationSettings(
                  groupId,
                  updatedSettings
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
            analyticsClient.logEvent(
              AnalyticsClient.EventName.groupInviteShared,
              [
                AnalyticsClient.ParameterKey.groupID: state.group.id,
                AnalyticsClient.ParameterKey.groupName: state.group.name
              ]
            )
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

          case .openSystemSettingsTapped:
            return .run { _ in
              await notificationClient.openNotificationSettings()
            }

          case .transferHostTapped:
            state.isShowingTransferSheet = true
            state.selectedNewHost = nil
            return .run { [hapticFeedback] _ in
              await hapticFeedback.warning()
            }

          case .selectNewHost(let member):
            state.selectedNewHost = member
            return .none

          case .confirmTransferHost:
            guard let newHost = state.selectedNewHost else { return .none }
            state.isTransferringHost = true
            state.transferError = nil
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.destructive()
              do {
                try await groupClient.transferHost(groupId, newHost.userId)
                await send(.internal(.transferHostResponse(.success(()))))
              } catch {
                await send(.internal(.transferHostResponse(.failure(error))))
              }
            }

          case .dismissTransferSheet:
            state.isShowingTransferSheet = false
            state.selectedNewHost = nil
            return .none

          case .dismissTransferError:
            state.transferError = nil
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

          case .systemAuthStatusFetched(let status):
            state.systemAuthStatus = status
            return .none

          case .notificationPermissionResponse(let granted):
            state.systemAuthStatus = granted ? .authorized : .denied
            return .run { [hapticFeedback] _ in
              if granted {
                await hapticFeedback.success()
              } else {
                await hapticFeedback.error()
              }
            }

          case .groupNotificationsUpdateFailed(let previousValue, let message):
            state.notificationSettings.enabled = previousValue
            state.notificationError = message
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .notificationPreferenceUpdateFailed(let key, let previousValue, let message):
            state.notificationSettings.setValue(previousValue, for: key)
            state.notificationError = message
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .transferHostResponse(.success):
            state.isTransferringHost = false
            state.isShowingTransferSheet = false
            state.selectedNewHost = nil
            return .merge(
              .send(.delegate(.hostTransferred)),
              .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            )

          case .transferHostResponse(.failure(let error)):
            state.isTransferringHost = false
            state.transferError = error.localizedDescription
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
