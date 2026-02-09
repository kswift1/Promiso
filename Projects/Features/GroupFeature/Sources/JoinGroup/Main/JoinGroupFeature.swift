import SwiftUI
import ComposableArchitecture

import PromisoShared
import Clients

// MARK: - Feature Namespace

public enum JoinGroup {}

// MARK: - Feature Implementation

extension JoinGroup {

  // MARK: - Step

  public enum Step: Equatable {
    case enterCode
    case preview(GroupPreviewModel)
    case settings(GroupModel)
  }

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.eventKitClient) var eventKitClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    private enum CancelID {
      case previewGroup
      case joinGroup
      case saveSettings
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Step
      var step: Step = .enterCode

      // Invite Code
      var inviteCode: String = ""
      let currentUser: UserPrivateModel

      // Progress & Error
      var isLoadingPreview: Bool = false
      var isJoining: Bool = false
      var previewError: String?
      var joinError: String?

      // Settings (그룹 참여 후 초기 설정)
      var notificationEnabled: Bool = true
      var calendarSyncEnabled: Bool = true
      var isSavingSettings: Bool = false

      // Notification Permission
      var notificationAuthStatus: NotificationAuthorizationStatus = .notDetermined

      // Calendar Permission
      var calendarAuthStatus: CalendarAuthorizationStatus = .notDetermined
      var showCalendarPermissionInfoAlert: Bool = false

      // Image Detail
      var selectedMemberForImage: UserPublicModel?
      var showGroupImageDetail: Bool = false

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // Validation
      var isValidCode: Bool {
        inviteCode.count == 6 && inviteCode.allSatisfy { $0.isLetter || $0.isNumber }
      }

      var canProceedToPreview: Bool {
        isValidCode && !isLoadingPreview
      }

      var canJoin: Bool {
        !isJoining
      }

      var formattedCode: String {
        inviteCode.uppercased()
      }
    }

    // MARK: - Action

    public enum Action: Sendable, BindableAction {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case codeChanged(String)
        case nextTapped // 코드 입력 후 "다음" 버튼
        case backTapped // 미리보기에서 "뒤로" 버튼
        case joinGroupTapped // 미리보기에서 "참여하기" 버튼
        case cancelTapped
        case previewErrorAlertDismissed
        case joinErrorAlertDismissed
        // Settings
        case notificationToggled(Bool)
        case calendarSyncToggled(Bool)
        case settingsCompleted
        case settingsSkipped
        case settingsAppeared
        // Calendar Permission Info Alert
        case calendarPermissionInfoAlertDismissed
        // Image Detail
        case memberImageTapped(UserPublicModel)
        case groupImageTapped
        case imageDetailDismissed
      }

      @CasePathable
      public enum Internal: Sendable {
        case previewGroupResponse(Result<GroupPreviewModel, Error>)
        case joinGroupResponse(Result<GroupModel, Error>)
        case saveSettingsResponse(Result<Void, Error>)
        case notificationAuthStatusChecked(NotificationAuthorizationStatus)
        case notificationPermissionResponse(Bool)
        case calendarAuthStatusChecked(CalendarAuthorizationStatus)
        case calendarPermissionResponse(Bool)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case dismiss
        case groupJoined(GroupModel)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      BindingReducer()

      Reduce { state, action in
        switch action {

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .codeChanged(let newCode):
            // 영숫자만 허용, 대문자로 변환, 최대 6자리
            let filtered = newCode
              .uppercased()
              .filter { $0.isLetter || $0.isNumber }
              .prefix(6)
            state.inviteCode = String(filtered)
            return .none

          case .nextTapped:
            guard state.canProceedToPreview else { return .none }
            state.isLoadingPreview = true
            state.previewError = nil
            let inviteCode = state.formattedCode
            return .run { send in
              do {
                let result = try await groupClient.previewGroup(inviteCode)
                await send(.internal(.previewGroupResponse(.success(result))))
              } catch {
                await send(.internal(.previewGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.previewGroup, cancelInFlight: true)

          case .backTapped:
            state.step = .enterCode
            return .none

          case .joinGroupTapped:
            guard state.canJoin else { return .none }
            guard case .preview = state.step else { return .none }
            state.isJoining = true
            state.joinError = nil
            let inviteCode = state.formattedCode
            return .run { send in
              do {
                let result = try await groupClient.joinGroup(inviteCode)
                await send(.internal(.joinGroupResponse(.success(result))))
              } catch {
                await send(.internal(.joinGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.joinGroup, cancelInFlight: true)

          case .cancelTapped:
            return .send(.delegate(.dismiss))

          case .previewErrorAlertDismissed:
            state.previewError = nil
            return .none

          case .joinErrorAlertDismissed:
            state.joinError = nil
            return .none

          case .notificationToggled(let enabled):
            // OFF로 전환할 때는 권한 체크 불필요
            guard enabled else {
              state.notificationEnabled = false
              return .none
            }

            // 권한 상태에 따라 처리
            let status = state.notificationAuthStatus
            switch status {
            case .authorized, .provisional, .ephemeral:
              // 권한 있음 - ON
              state.notificationEnabled = true
              return .none

            case .notDetermined:
              // 권한 요청 필요
              state.notificationEnabled = true
              return .run { send in
                let granted = (try? await notificationClient.requestAuthorization()) ?? false
                await send(.internal(.notificationPermissionResponse(granted)))
              }

            case .denied:
              // 권한 거부됨 - OFF 유지, 설정으로 이동
              state.notificationEnabled = false
              return .run { _ in
                await notificationClient.openNotificationSettings()
              }
            }

          case .calendarSyncToggled(let enabled):
            // OFF로 전환할 때는 권한 체크 불필요
            guard enabled else {
              state.calendarSyncEnabled = false
              return .none
            }

            // ON으로 전환
            state.calendarSyncEnabled = true

            // 권한 상태에 따라 처리
            let status = state.calendarAuthStatus
            switch status {
            case .fullAccess, .writeOnly, .authorized:
              // 권한 있음 - 완료
              return .none

            case .notDetermined:
              // 권한 요청 필요
              return .run { send in
                let granted = try await eventKitClient.requestAccess()
                await send(.internal(.calendarPermissionResponse(granted)))
              }

            case .denied, .restricted:
              // 권한 거부됨 - 토글 ON 유지하고 안내 Alert 표시
              state.showCalendarPermissionInfoAlert = true
              return .none
            }

          case .calendarPermissionInfoAlertDismissed:
            state.showCalendarPermissionInfoAlert = false
            return .none

          case .settingsAppeared:
            // 설정에서 돌아왔을 때 권한 상태 새로고침
            return .merge(
              .run { send in
                let status = await notificationClient.getAuthorizationStatus()
                await send(.internal(.notificationAuthStatusChecked(status)))
              },
              .run { send in
                let status = eventKitClient.authorizationStatus()
                await send(.internal(.calendarAuthStatusChecked(status)))
              }
            )

          case .settingsCompleted:
            guard case .settings(let group) = state.step else { return .none }
            state.isSavingSettings = true
            let settings = GroupNotificationSettings(
              enabled: state.notificationEnabled,
              calendarSync: state.calendarSyncEnabled
            )
            return .run { [groupId = group.id] send in
              do {
                try await groupClient.updateGroupNotificationSettings(groupId, settings)
                await send(.internal(.saveSettingsResponse(.success(()))))
              } catch {
                await send(.internal(.saveSettingsResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.saveSettings, cancelInFlight: true)

          case .settingsSkipped:
            guard case .settings(let group) = state.step else { return .none }
            analyticsClient.logEvent(
              AnalyticsClient.EventName.groupJoined,
              [
                AnalyticsClient.ParameterKey.groupID: group.id,
                AnalyticsClient.ParameterKey.groupName: group.name
              ]
            )
            return .send(.delegate(.groupJoined(group)))

          case .memberImageTapped(let member):
            state.selectedMemberForImage = member
            return .none

          case .groupImageTapped:
            state.showGroupImageDetail = true
            return .none

          case .imageDetailDismissed:
            state.selectedMemberForImage = nil
            state.showGroupImageDetail = false
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .previewGroupResponse(.success(let preview)):
            state.isLoadingPreview = false
            state.step = .preview(preview)
            return .none

          case .previewGroupResponse(.failure(let error)):
            state.isLoadingPreview = false
            state.previewError = error.localizedDescription
            return .none

          case .joinGroupResponse(.success(let group)):
            state.isJoining = false
            state.step = .settings(group)
            // 알림 및 캘린더 권한 상태 확인
            return .merge(
              .run { send in
                let status = await notificationClient.getAuthorizationStatus()
                await send(.internal(.notificationAuthStatusChecked(status)))
              },
              .run { send in
                let status = eventKitClient.authorizationStatus()
                await send(.internal(.calendarAuthStatusChecked(status)))
              }
            )

          case .joinGroupResponse(.failure(let error)):
            state.isJoining = false
            state.joinError = error.localizedDescription
            return .none

          case .saveSettingsResponse(.success), .saveSettingsResponse(.failure):
            // .failure의 경우에도 그룹 참여는 완료된 것으로 간주하고 진행합니다.
            state.isSavingSettings = false
            guard case .settings(let group) = state.step else { return .none }
            analyticsClient.logEvent(
              AnalyticsClient.EventName.groupJoined,
              [
                AnalyticsClient.ParameterKey.groupID: group.id,
                AnalyticsClient.ParameterKey.groupName: group.name
              ]
            )
            return .send(.delegate(.groupJoined(group)))

          case .notificationAuthStatusChecked(let status):
            let previousStatus = state.notificationAuthStatus
            state.notificationAuthStatus = status

            // 권한 상태에 따라 토글 값 설정
            switch status {
            case .authorized, .provisional, .ephemeral:
              // 이전에 denied였다가 authorized로 변경된 경우 (설정에서 허용)
              if previousStatus == .denied {
                state.notificationEnabled = true
              }
            case .denied, .notDetermined:
              state.notificationEnabled = false
            }
            return .none

          case .notificationPermissionResponse(let granted):
            if granted {
              state.notificationAuthStatus = .authorized
              // notificationEnabled은 이미 true로 설정됨
            } else {
              state.notificationAuthStatus = .denied
              // 권한 거부 - 토글 OFF
              state.notificationEnabled = false
            }
            return .none

          case .calendarAuthStatusChecked(let status):
            let previousStatus = state.calendarAuthStatus
            state.calendarAuthStatus = status

            // 권한 상태에 따라 토글 값 설정
            if status.canWriteEvents {
              // 이전에 denied였다가 권한이 생긴 경우 (설정에서 허용)
              // 캘린더는 토글이 ON인 상태에서 설정 갔다 왔을 수 있으므로 토글 상태 유지
              if !previousStatus.canWriteEvents && state.calendarSyncEnabled {
                // 이미 ON이면 유지, Alert만 닫기
                state.showCalendarPermissionInfoAlert = false
              }
            } else {
              state.calendarSyncEnabled = false
            }
            return .none

          case .calendarPermissionResponse(let granted):
            if granted {
              state.calendarAuthStatus = .fullAccess
              // calendarSyncEnabled은 이미 true로 설정됨
            } else {
              state.calendarAuthStatus = .denied
              // 권한 거부 - 토글 ON 유지하고 안내 Alert 표시
              state.showCalendarPermissionInfoAlert = true
            }
            return .none
          }

        case .binding:
          return .none

        case .delegate:
          state.step = .enterCode
          state.isJoining = false
          state.isSavingSettings = false
          return .none
        }
      }
    }
  }
}
