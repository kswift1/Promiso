import SwiftUI
import PhotosUI
import ComposableArchitecture
import PromisoShared
import Clients

// MARK: - Feature Namespace

public enum CreateGroup {}

// MARK: - Feature Implementation

extension CreateGroup {

  // MARK: - Step

  public enum Step: Equatable {
    case input
    case success(GroupCreationResultModel)
    case settings(GroupCreationResultModel)
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
      case createGroup
      case saveSettings
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Step
      var step: Step = .input

      // Photo
      var selectedPhoto: PhotosPickerItem?
      var photoData: Data?

      // Group Info
      var groupName: String = ""
      var groupDescription: String = ""
      var maxMembers: MaxMembers = .five
      let currentUser: UserPrivateModel

      // Progress & Error
      var isCreating: Bool = false
      var creationError: String?

      // Settings (그룹 생성 후 초기 설정)
      var notificationEnabled: Bool = true
      var calendarSyncEnabled: Bool = true
      var isSavingSettings: Bool = false

      // Notification Permission
      var notificationAuthStatus: NotificationAuthorizationStatus = .notDetermined

      // Calendar Permission
      var calendarAuthStatus: CalendarAuthorizationStatus = .notDetermined
      var showCalendarPermissionInfoAlert: Bool = false

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // Validation
      var isValid: Bool {
        trimmedGroupName.count >= 2
      }

      var canSubmit: Bool {
        isValid && !isCreating
      }

      var trimmedGroupName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      var characterCount: Int {
        groupName.count
      }

      var descriptionCharacterCount: Int {
        groupDescription.count
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
        case photoSelected(PhotosPickerItem?)
        case createGroupTapped
        case cancelTapped
        case errorAlertDismissed
        // Success
        case successAcknowledged
        // Settings
        case notificationToggled(Bool)
        case calendarSyncToggled(Bool)
        case settingsCompleted
        case settingsSkipped
        case settingsAppeared
        // Calendar Permission Info Alert
        case calendarPermissionInfoAlertDismissed
      }

      @CasePathable
      public enum Internal: Sendable {
        case photoLoaded(Data?)
        case createGroupResponse(Result<GroupCreationResultModel, Error>)
        case saveSettingsResponse(Result<Void, Error>)
        case notificationAuthStatusChecked(NotificationAuthorizationStatus)
        case notificationPermissionResponse(Bool)
        case calendarAuthStatusChecked(CalendarAuthorizationStatus)
        case calendarPermissionResponse(Bool)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case dismiss
        case groupCreated(id: String)
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

          case .photoSelected(let item):
            state.selectedPhoto = item
            guard let item else {
              state.photoData = nil
              return .none
            }

            return .run { send in
              if let data = try? await item.loadTransferable(type: Data.self) {
                await send(.internal(.photoLoaded(data)))
              }
            }

          case .createGroupTapped:
            guard state.canSubmit else { return .none }
            state.isCreating = true
            state.creationError = nil
            let request = state.makeCreateRequest()
            return .run { send in
              do {
                let result = try await groupClient.createGroup(request)
                await send(.internal(.createGroupResponse(.success(result))))
              } catch {
                await send(.internal(.createGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.createGroup, cancelInFlight: true)

          case .cancelTapped:
            return .send(.delegate(.dismiss))

          case .errorAlertDismissed:
            state.creationError = nil
            return .none

          case .successAcknowledged:
            guard case .success(let result) = state.step else { return .none }
            state.step = .settings(result)
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
            guard case .settings(let result) = state.step else { return .none }
            state.isSavingSettings = true
            let settings = GroupNotificationSettings(
              enabled: state.notificationEnabled,
              calendarSync: state.calendarSyncEnabled
            )
            return .run { [groupId = result.id] send in
              do {
                try await groupClient.updateGroupNotificationSettings(groupId, settings)
                await send(.internal(.saveSettingsResponse(.success(()))))
              } catch {
                await send(.internal(.saveSettingsResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.saveSettings, cancelInFlight: true)

          case .settingsSkipped:
            guard case .settings(let result) = state.step else { return .none }
            analyticsClient.logEvent(
              AnalyticsClient.EventName.groupCreated,
              [
                AnalyticsClient.ParameterKey.groupID: result.id,
                AnalyticsClient.ParameterKey.groupName: result.name
              ]
            )
            return .send(.delegate(.groupCreated(id: result.id)))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.photoData = data
            return .none

          case .createGroupResponse(.success(let result)):
            state.isCreating = false
            state.step = .success(result)
            return .none

          case .createGroupResponse(.failure(let error)):
            state.isCreating = false
            state.creationError = error.localizedDescription
            return .none

          case .saveSettingsResponse(.success), .saveSettingsResponse(.failure):
            // .failure의 경우에도 그룹 생성은 완료된 것으로 간주하고 진행합니다.
            state.isSavingSettings = false
            guard case .settings(let result) = state.step else { return .none }
            analyticsClient.logEvent(
              AnalyticsClient.EventName.groupCreated,
              [
                AnalyticsClient.ParameterKey.groupID: result.id,
                AnalyticsClient.ParameterKey.groupName: result.name
              ]
            )
            return .send(.delegate(.groupCreated(id: result.id)))

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
          state.step = .input
          state.isCreating = false
          state.isSavingSettings = false
          return .none
        }
      }
    }
  }
}

// MARK: - Max Members

public enum MaxMembers: Int, CaseIterable, Equatable, Sendable {
  case two = 2
  case three = 3
  case four = 4
  case five = 5
  case six = 6
  case seven = 7
  case eight = 8
  case nine = 9
  case ten = 10

  var displayText: String {
    "\(rawValue)명"
  }
}

private extension CreateGroup.Feature.State {
  func makeCreateRequest() -> CreateGroupRequestModel {
    CreateGroupRequestModel(
      name: trimmedGroupName,
      maxMembers: maxMembers.rawValue,
      description: groupDescription.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      creatorId: currentUser.id,
      photoData: photoData
    )
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
