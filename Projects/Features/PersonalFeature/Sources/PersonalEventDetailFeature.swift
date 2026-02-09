import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Namespace

public enum PersonalEventDetail {}

// MARK: - Reducer

extension PersonalEventDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: PersonalEventModel
      var isDeleting: Bool = false
      var showShareSheet: Bool = false

      @Presents var editEvent: CreatePersonalEvent.Feature.State?
      @Presents var deleteAlert: AlertState<Action.Alert>?

      public init(event: PersonalEventModel) {
        self.event = event
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case editEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case alert(PresentationAction<Alert>)

      public enum View: Sendable {
        case editTapped
        case deleteTapped
        case shareTapped
        case shareSheetDismissed
      }

      public enum Internal: Sendable {
        case deleteSuccess
        case deleteFailed(String)
      }

      public enum Delegate: Sendable {
        case eventUpdated(PersonalEventModel)
        case eventDeleted(id: String)
      }

      @CasePathable
      public enum Alert: Sendable {
        case confirmDelete
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case let .view(viewAction):
          switch viewAction {
          case .editTapped:
            state.editEvent = CreatePersonalEvent.Feature.State(
              event: state.event,
              mode: .edit
            )
            return .none

          case .deleteTapped:
            let eventTitle = state.event.title
            state.deleteAlert = AlertState {
              TextState("일정 삭제")
            } actions: {
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("삭제")
              }
              ButtonState(role: .cancel) {
                TextState("취소")
              }
            } message: {
              TextState("'\(eventTitle)' 일정을 삭제하시겠습니까?")
            }
            return .none

          case .shareTapped:
            state.showShareSheet = true
            return .none

          case .shareSheetDismissed:
            state.showShareSheet = false
            return .none
          }

        // MARK: - Internal Actions

        case let .internal(internalAction):
          switch internalAction {
          case .deleteSuccess:
            state.isDeleting = false
            return .merge(
              .run { _ in await hapticFeedback.success() },
              .send(.delegate(.eventDeleted(id: state.event.id)))
            )

          case .deleteFailed:
            state.isDeleting = false
            return .run { _ in await hapticFeedback.error() }
          }

        // MARK: - Alert Actions

        case .alert(.presented(.confirmDelete)):
          state.isDeleting = true
          return .run { [event = state.event] send in
            do {
              try await personalEventClient.deleteEvent(event.id)
              await localNotificationClient.cancel(event.notificationId)
              await send(.internal(.deleteSuccess))
            } catch {
              await send(.internal(.deleteFailed(error.localizedDescription)))
            }
          }

        case .alert:
          return .none

        // MARK: - Edit Event Delegate

        case .editEvent(.presented(.delegate(.eventUpdated(let updatedEvent)))):
          state.event = updatedEvent
          state.editEvent = nil
          return .send(.delegate(.eventUpdated(updatedEvent)))

        case .editEvent(.presented(.delegate(.dismiss))):
          state.editEvent = nil
          return .none

        case .editEvent(.presented(.delegate(.eventCreated))):
          return .none

        case .editEvent:
          return .none

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$editEvent, action: \.editEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.$deleteAlert, action: \.alert)
    }
  }
}
