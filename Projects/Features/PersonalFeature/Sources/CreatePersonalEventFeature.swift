import ComposableArchitecture
import Clients
import PromisoShared
import SharedFeature

// MARK: - Namespace

public enum CreatePersonalEvent {}

// MARK: - Reducer

extension CreatePersonalEvent {
  @Reducer
  public struct Feature {
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.continuousClock) var clock
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    public init() {}

    // MARK: - Cancel IDs

    private enum CancelID {
      case emojiDebounce
    }

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
      case create
      case edit
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: PersonalEventModel
      var mode: Mode
      var isSaving: Bool = false
      var isEmojiLoading: Bool = false
      var useEndTime: Bool = false
      var useReminder: Bool = false
      var errorMessage: String?

      @Presents var locationPicker: LocationPicker.Feature.State?
      @Presents var notificationPermission: NotificationPermission.Feature.State?

      public init(event: PersonalEventModel = .empty, mode: Mode = .create) {
        self.event = event
        self.mode = mode
        self.useEndTime = event.endAt != nil
        self.useReminder = event.reminderMinutesBefore != nil
      }

      var canSave: Bool {
        event.isTitleValid && !isSaving
      }

      var navigationTitle: String {
        mode == .create ? "새 일정" : "일정 수정"
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case locationPicker(PresentationAction<LocationPicker.Feature.Action>)
      case notificationPermission(PresentationAction<NotificationPermission.Feature.Action>)
    }

    @CasePathable
    public enum View: Sendable {
      case titleChanged(String)
      case startDateChanged(Date)
      case endDateChanged(Date)
      case toggleUseEndTime
      case toggleUseReminder
      case reminderChanged(Int)
      case descriptionChanged(String)
      case locationTapped
      case removeLocation
      case saveTapped
      case dismissTapped
      case dismissError
    }

    public enum Internal: Sendable {
      case titleDebounced(String)
      case emojiGenerated(String)
      case emojiGenerationFailed
      case saveSuccess(PersonalEventModel)
      case saveFailed(String)
      case notificationStatusChecked(NotificationAuthorizationStatus)
    }

    @CasePathable
    public enum Delegate: Sendable {
      case eventCreated
      case eventUpdated(PersonalEventModel)
      case dismiss
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case let .view(viewAction):
          switch viewAction {
          case .titleChanged(let title):
            let oldTitle = state.event.title
            state.event.title = String(title.prefix(30))
            guard title != oldTitle else { return .none }
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
              state.event.emoji = nil
              return .cancel(id: CancelID.emojiDebounce)
            }
            return .run { [clock] send in
              try await clock.sleep(for: .seconds(1))
              await send(.internal(.titleDebounced(title)))
            }
            .cancellable(id: CancelID.emojiDebounce, cancelInFlight: true)

          case .startDateChanged(let date):
            state.event.startAt = date
            if let endAt = state.event.endAt, endAt <= date {
              state.event.endAt = date.addingTimeInterval(3600)
            }
            return .none

          case .endDateChanged(let date):
            state.event.endAt = date
            return .none

          case .toggleUseEndTime:
            state.useEndTime.toggle()
            if state.useEndTime {
              state.event.endAt = state.event.startAt.addingTimeInterval(3600)
            } else {
              state.event.endAt = nil
            }
            return .run { _ in await hapticFeedback.selection() }

          case .toggleUseReminder:
            if !state.useReminder {
              // 켜려고 할 때 권한 확인
              return .run { [notificationClient] send in
                let status = await notificationClient.getAuthorizationStatus()
                await send(.internal(.notificationStatusChecked(status)))
              }
            } else {
              state.useReminder = false
              state.event.reminderMinutesBefore = nil
              return .run { _ in await hapticFeedback.selection() }
            }

          case .reminderChanged(let minutes):
            state.event.reminderMinutesBefore = minutes
            return .none

          case .descriptionChanged(let text):
            let trimmed = String(text.prefix(500))
            state.event.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .locationTapped:
            state.locationPicker = LocationPicker.Feature.State()
            return .none

          case .removeLocation:
            state.event.location = nil
            return .run { _ in await hapticFeedback.selection() }

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isSaving = true
            state.errorMessage = nil
            return .run { [event = state.event, mode = state.mode, personalEventClient, localNotificationClient, calendarSyncClient] send in
              do {
                var savedEvent = event
                let syncEnabled = UserDefaults.standard.bool(
                  forKey: AppConstants.UserDefaults.personalCalendarSync
                )

                switch mode {
                case .create:
                  let eventId = try await personalEventClient.createEvent(event)
                  savedEvent.id = eventId
                  try? await calendarSyncClient.addPersonalEvent(savedEvent, syncEnabled)
                case .edit:
                  try await personalEventClient.updateEvent(event)
                  try? await calendarSyncClient.updatePersonalEvent(savedEvent, syncEnabled)
                }

                // 기존 알림 취소 후 재스케줄링
                await localNotificationClient.cancel(savedEvent.notificationId)
                if savedEvent.canScheduleReminder, let date = savedEvent.reminderDate {
                  try? await localNotificationClient.schedule(
                    savedEvent.notificationId,
                    savedEvent.notificationTitle,
                    savedEvent.notificationBody,
                    date,
                    ["type": "personal_event_reminder", "eventId": savedEvent.id]
                  )
                }

                await send(.internal(.saveSuccess(savedEvent)))
              } catch {
                await send(.internal(.saveFailed(error.localizedDescription)))
              }
            }

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .dismissError:
            state.errorMessage = nil
            return .none
          }

        // MARK: - Internal Actions

        case let .internal(internalAction):
          switch internalAction {
          case .titleDebounced(let title):
            state.isEmojiLoading = true
            return .run { [emojiClient] send in
              do {
                let emoji = try await emojiClient.generate(title)
                await send(.internal(.emojiGenerated(emoji)))
              } catch {
                await send(.internal(.emojiGenerationFailed))
              }
            }

          case .emojiGenerated(let emoji):
            state.isEmojiLoading = false
            state.event.emoji = emoji
            return .none

          case .emojiGenerationFailed:
            state.isEmojiLoading = false
            return .none

          case .saveSuccess(let event):
            state.isSaving = false
            let delegateAction: Action = state.mode == .create
              ? .delegate(.eventCreated)
              : .delegate(.eventUpdated(event))
            return .merge(
              .run { _ in await hapticFeedback.success() },
              .send(delegateAction)
            )

          case .saveFailed(let message):
            state.isSaving = false
            state.errorMessage = message
            return .run { _ in await hapticFeedback.error() }

          case .notificationStatusChecked(let status):
            switch status {
            case .authorized, .provisional, .ephemeral:
              state.useReminder = true
              state.event.reminderMinutesBefore = 30
              return .run { _ in await hapticFeedback.selection() }
            case .notDetermined, .denied:
              state.notificationPermission = NotificationPermission.Feature.State(
                config: .init(
                  title: "알림을 켜고\n일정을 놓치지 마세요",
                  content: "설정한 시간에 맞춰\n미리 알림을 보내드려요.",
                  notificationTitle: "일정 알림 ⏰",
                  notificationContent: "30분 후 시작하는 일정이 있어요",
                  primaryButtonTitle: status == .notDetermined ? "알림 허용" : "설정으로 이동",
                  secondaryButtonTitle: "나중에 하기"
                )
              )
              return .none
            }
          }

        // MARK: - LocationPicker

        case .locationPicker(.presented(.delegate(.locationSelected(let location)))):
          state.event.location = location
          state.locationPicker = nil
          return .none

        case .locationPicker(.presented(.delegate(.dismissed))):
          state.locationPicker = nil
          return .none

        case .locationPicker:
          return .none

        // MARK: - NotificationPermission

        case .notificationPermission(.presented(.delegate(.permissionChanged(let isGranted)))):
          if isGranted {
            state.useReminder = true
            state.event.reminderMinutesBefore = 30
          }
          return .none

        case .notificationPermission(.presented(.delegate(.dismissed))):
          state.notificationPermission = nil
          return .none

        case .notificationPermission:
          return .none

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$locationPicker, action: \.locationPicker) {
        LocationPicker.Feature()
      }
      .ifLet(\.$notificationPermission, action: \.notificationPermission) {
        NotificationPermission.Feature()
      }
    }
  }
}

// MARK: - Reminder Options

extension CreatePersonalEvent {
  public enum ReminderOption: Int, CaseIterable, Sendable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120

    public var title: String {
      switch self {
      case .fiveMinutes: return "5분 전"
      case .tenMinutes: return "10분 전"
      case .fifteenMinutes: return "15분 전"
      case .thirtyMinutes: return "30분 전"
      case .oneHour: return "1시간 전"
      case .twoHours: return "2시간 전"
      }
    }
  }
}
