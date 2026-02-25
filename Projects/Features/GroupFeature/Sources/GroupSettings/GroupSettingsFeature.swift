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
    @Dependency(\.kakaoShareClient) var kakaoShareClient

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
      var toastMessage: ToastMessage?

      // Image Detail
      var selectedMemberForImage: UserPublicModel?
      var showGroupImageDetail: Bool = false
      var editGroup: EditGroupState?

      // Notifications
      var notificationSettings: GroupNotificationSettings
      var notificationError: String?

      // Group Color
      var groupColor: GroupColor?
      var systemAuthStatus: NotificationAuthorizationStatus = .notDetermined

      // Transfer Host
      var isShowingTransferSheet: Bool = false
      var selectedNewHost: UserPublicModel?
      var isTransferringHost: Bool = false
      var transferError: String?

      // Expel Member
      var isEditingMembers: Bool = false
      var memberToExpel: UserPublicModel?
      var isExpellingMember: Bool = false
      var expelError: String?

      // Kakao Share
      var isKakaoSharing: Bool = false
      var showSystemShareSheet: Bool = false

      // Upcoming Promises (카카오 공유용)
      var upcomingPromises: [PromiseModel] = []

      public init(
        group: GroupModel,
        summary: UserGroupInfo?,
        currentUserId: String,
        userPlan: UserPlan,
        preloadedMembers: [UserPublicModel]? = nil,
        upcomingPromises: [PromiseModel] = []
      ) {
        self.group = group
        self.summary = summary
        self.currentUserId = currentUserId
        self.userPlan = userPlan
        self.notificationSettings = summary?.notifications ?? GroupNotificationSettings()
        self.upcomingPromises = upcomingPromises
        self.groupColor = summary?.groupColor

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

      /// 추방 가능 여부 (호스트이고 다른 멤버가 있을 때)
      var canExpelMembers: Bool {
        isHost && members.count > 1
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
        "https://\(AppConstants.Deeplink.webHost)/invite/\(group.inviteCode)"
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
        case groupImageTapped
        case imageDetailDismissed
        case groupImageDetailDismissed
        case openSystemSettingsTapped
        // Transfer Host
        case transferHostTapped
        case selectNewHost(UserPublicModel)
        case confirmTransferHost
        case dismissTransferSheet
        case dismissTransferError
        // Expel Member
        case editMembersTapped
        case doneEditingMembersTapped
        case expelMemberTapped(UserPublicModel)
        case confirmExpelMember
        case dismissExpelAlert
        case dismissExpelError
        case toastDismissed
        // Kakao Share
        case kakaoShareTapped
        case systemShareSheetDismissed
        // Group Color
        case groupColorChanged(GroupColor?)
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
        case expelMemberResponse(Result<Void, Error>)
        case kakaoShareResult(KakaoShareResult)
        case groupColorUpdateFailed(previousColor: GroupColor?, message: String)
      }

      public enum Delegate: Sendable {
        case groupLeft
        case groupDeleted
        case pastPromisesTapped
        case hostTransferred
        case memberExpelled
        case groupColorChanged(GroupColor?)
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
                  message: (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
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
                  message: (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
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

          case .groupImageTapped:
            state.showGroupImageDetail = true
            return .none

          case .imageDetailDismissed:
            state.selectedMemberForImage = nil
            return .none

          case .groupImageDetailDismissed:
            state.showGroupImageDetail = false
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

          case .editMembersTapped:
            state.isEditingMembers = true
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .doneEditingMembersTapped:
            state.isEditingMembers = false
            return .run { [hapticFeedback] _ in
              await hapticFeedback.buttonTap()
            }

          case .expelMemberTapped(let member):
            state.memberToExpel = member
            return .run { [hapticFeedback] _ in
              await hapticFeedback.warning()
            }

          case .confirmExpelMember:
            guard let member = state.memberToExpel else { return .none }
            state.isExpellingMember = true
            state.expelError = nil
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.destructive()
              do {
                try await groupClient.expelMember(groupId, member.userId)
                await send(.internal(.expelMemberResponse(.success(()))))
              } catch {
                await send(.internal(.expelMemberResponse(.failure(error))))
              }
            }

          case .dismissExpelAlert:
            state.memberToExpel = nil
            return .none

          case .dismissExpelError:
            state.expelError = nil
            return .none

          case .groupColorChanged(let color):
            let previousColor = state.groupColor
            state.groupColor = color
            return .run { [groupClient, groupId = state.group.id, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupColor(groupId, color)
                await send(.delegate(.groupColorChanged(color)))
              } catch {
                await send(.internal(.groupColorUpdateFailed(
                  previousColor: previousColor,
                  message: error.localizedDescription
                )))
              }
            }

          case .toastDismissed:
            state.toastMessage = nil
            return .none

          case .kakaoShareTapped:
            state.isKakaoSharing = true
            let groupName = state.group.name
            let inviteCode = state.group.inviteCode
            let memberCount = state.group.memberIds.count
            let maxMembers = state.group.maxMembers
            let groupImageUrl = state.group.imageUrl
            let inviterName = state.members
              .first { $0.userId == state.currentUserId }?.displayName ?? ""
            let promiseInfos = state.upcomingPromises
              .filter { $0.isUpcoming }
              .sorted { $0.startAt < $1.startAt }
              .prefix(3)
              .map { promise in
                PromiseShareInfo(
                  title: promise.title,
                  emoji: promise.displayEmoji,
                  dateText: promise.dateText,
                  timeText: promise.timeText,
                  locationName: promise.location?.name,
                  imageUrl: promise.imageUrls.first
                )
              }
            return .run { [kakaoShareClient, hapticFeedback, analyticsClient] send in
              await hapticFeedback.buttonTap()
              analyticsClient.logEvent(
                "kakao_group_invite_shared",
                [
                  AnalyticsClient.ParameterKey.groupName: groupName,
                  "share_method": "kakao",
                  "promise_count": "\(promiseInfos.count)"
                ]
              )
              let result = await kakaoShareClient.shareGroupInvite(
                groupName,
                inviteCode,
                memberCount,
                maxMembers,
                groupImageUrl,
                inviterName,
                promiseInfos
              )
              await send(.internal(.kakaoShareResult(result)))
            }

          case .systemShareSheetDismissed:
            state.showSystemShareSheet = false
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
            state.leaveError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
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
            state.deleteError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
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
            state.editGroup?.error = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .systemAuthStatusFetched(let status):
            state.systemAuthStatus = status
            return .none

          case .notificationPermissionResponse(let granted):
            state.systemAuthStatus = granted ? .authorized : .denied
            if !granted {
              state.toastMessage = ToastMessage(
                type: .warning,
                title: "알림 권한이 거부되었어요",
                subtitle: "설정에서 변경할 수 있어요.",
                position: .top
              )
            }
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
            state.toastMessage = ToastMessage(
              type: .error,
              title: "알림 설정 저장에 실패했어요",
              subtitle: message,
              position: .top
            )
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .notificationPreferenceUpdateFailed(let key, let previousValue, let message):
            state.notificationSettings.setValue(previousValue, for: key)
            state.notificationError = message
            state.toastMessage = ToastMessage(
              type: .error,
              title: "\(key.title) 설정 저장에 실패했어요",
              subtitle: message,
              position: .top
            )
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
            state.transferError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .expelMemberResponse(.success):
            let expelledMember = state.memberToExpel
            state.isExpellingMember = false
            state.memberToExpel = nil
            // 로컬 멤버 목록에서도 제거
            if let expelledMember {
              state.members.removeAll { $0.userId == expelledMember.userId }
              state.group = GroupModel(
                id: state.group.id,
                name: state.group.name,
                description: state.group.description,
                imageUrl: state.group.imageUrl,
                memberIds: state.group.memberIds.filter { $0 != expelledMember.userId },
                maxMembers: state.group.maxMembers,
                inviteCode: state.group.inviteCode,
                createdBy: state.group.createdBy,
                createdAt: state.group.createdAt,
                updatedAt: state.group.updatedAt
              )
            }
            return .merge(
              .send(.delegate(.memberExpelled)),
              .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            )

          case .expelMemberResponse(.failure(let error)):
            state.isExpellingMember = false
            state.memberToExpel = nil
            let expelErrorMessage = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            state.expelError = expelErrorMessage
            state.toastMessage = ToastMessage(
              type: .error,
              title: "멤버 추방에 실패했어요",
              subtitle: expelErrorMessage,
              position: .top
            )
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }

          case .kakaoShareResult(let result):
            state.isKakaoSharing = false
            switch result {
            case .shared, .webShared:
              state.toastMessage = ToastMessage(
                type: .success,
                title: LocalizedStrings.KakaoShare.inviteLinkShared,
                position: .top
              )
              return .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            case .fallbackToSystem:
              state.showSystemShareSheet = true
              return .none
            }

          case .groupColorUpdateFailed(let previousColor, let message):
            state.groupColor = previousColor
            state.toastMessage = ToastMessage(
              type: .error,
              title: "색상 변경에 실패했어요",
              subtitle: message,
              position: .top
            )
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
