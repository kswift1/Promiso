import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Namespace

public enum CreatePersonalEvent {}

// MARK: - Reducer

extension CreatePersonalEvent {
  @Reducer
  public struct Feature {
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.continuousClock) var clock

    public init() {}

    // MARK: - Cancel IDs

    private enum CancelID {
      case emojiDebounce
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: PersonalEventModel
      var isCreating: Bool = false
      var isEmojiLoading: Bool = false
      var useEndTime: Bool = false
      var useReminder: Bool = false
      var errorMessage: String?

      public init(event: PersonalEventModel = .empty) {
        self.event = event
        self.useEndTime = event.endAt != nil
        self.useReminder = event.reminderMinutesBefore != nil
      }

      var canSave: Bool {
        event.isTitleValid && !isCreating
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
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
      case saveTapped
      case dismissTapped
      case dismissError
    }

    public enum Internal: Sendable {
      case titleDebounced(String)
      case emojiGenerated(String)
      case emojiGenerationFailed
      case createEventSuccess(String)
      case createEventFailed(String)
    }

    public enum Delegate: Sendable {
      case eventCreated(id: String)
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
            state.event.title = title
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
            state.useReminder.toggle()
            if state.useReminder {
              state.event.reminderMinutesBefore = 30
            } else {
              state.event.reminderMinutesBefore = nil
            }
            return .run { _ in await hapticFeedback.selection() }

          case .reminderChanged(let minutes):
            state.event.reminderMinutesBefore = minutes
            return .none

          case .descriptionChanged(let text):
            state.event.description = text.isEmpty ? nil : text
            return .none

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isCreating = true
            state.errorMessage = nil
            return .run { [event = state.event, personalEventClient] send in
              do {
                let eventId = try await personalEventClient.createEvent(event)
                await send(.internal(.createEventSuccess(eventId)))
              } catch {
                await send(.internal(.createEventFailed(error.localizedDescription)))
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

          case .createEventSuccess(let eventId):
            state.isCreating = false
            return .merge(
              .run { _ in await hapticFeedback.success() },
              .send(.delegate(.eventCreated(id: eventId)))
            )

          case .createEventFailed(let message):
            state.isCreating = false
            state.errorMessage = message
            return .run { _ in await hapticFeedback.error() }
          }

        // MARK: - Delegate

        case .delegate:
          return .none
        }
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
