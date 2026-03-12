import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Namespace

public enum RecurringPersonalEventDetail {}

// MARK: - Reducer

extension RecurringPersonalEventDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.recurringPersonalEventClient) var recurringPersonalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 반복 일정 규칙 (전체 시리즈)
      var recurringEvent: RecurringPersonalEventModel
      /// 선택된 인스턴스 (특정 날짜) - nil이면 시리즈 전체 보기
      var selectedInstance: ExpandedEventInstance?
      /// 삭제 중 여부
      var isDeleting: Bool = false
      /// 수정 시트
      @Presents var editEvent: CreateRecurringPersonalEvent.Feature.State?
      /// 삭제 확인 알럿
      @Presents var deleteAlert: AlertState<Action.Alert>?

      public init(
        recurringEvent: RecurringPersonalEventModel,
        selectedInstance: ExpandedEventInstance? = nil
      ) {
        self.recurringEvent = recurringEvent
        self.selectedInstance = selectedInstance
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case editEvent(PresentationAction<CreateRecurringPersonalEvent.Feature.Action>)
      case alert(PresentationAction<Alert>)

      public enum View: Sendable {
        case onAppear
        case editTapped
        case deleteTapped
        case excludeInstanceTapped
      }

      public enum Internal: Sendable {
        case deleteSeriesSuccess
        case deleteSeriesFailed(String)
        case excludeInstanceSuccess(RecurringPersonalEventModel)
        case excludeInstanceFailed(String)
      }

      public enum Delegate: Sendable {
        case eventUpdated(RecurringPersonalEventModel)
        case eventDeleted(id: String)
      }

      @CasePathable
      public enum Alert: Sendable {
        case confirmDeleteSeries
        case confirmExcludeInstance
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case .view(.onAppear):
          return .none

        case .view(.editTapped):
          state.editEvent = CreateRecurringPersonalEvent.Feature.State(
            event: state.recurringEvent,
            mode: .edit
          )
          return .none

        case .view(.deleteTapped):
          if state.selectedInstance != nil {
            // 인스턴스 선택된 상태면 옵션 제공
            state.deleteAlert = AlertState {
              TextState(LocalizedStrings.Common.delete)
            } actions: {
              ButtonState(action: .confirmExcludeInstance) {
                TextState(LocalizedStrings.Personal.recurringDetailExcludeInstance)
              }
              ButtonState(role: .destructive, action: .confirmDeleteSeries) {
                TextState(LocalizedStrings.Personal.recurringDeleteSeries)
              }
              ButtonState(role: .cancel) {
                TextState(LocalizedStrings.Common.cancel)
              }
            } message: {
              TextState(LocalizedStrings.Personal.recurringDeleteOptionsMessage)
            }
          } else {
            // 시리즈 전체 보기면 바로 삭제 확인
            state.deleteAlert = AlertState {
              TextState(LocalizedStrings.Personal.recurringDetailTitle)
            } actions: {
              ButtonState(role: .destructive, action: .confirmDeleteSeries) {
                TextState(LocalizedStrings.Common.delete)
              }
              ButtonState(role: .cancel) {
                TextState(LocalizedStrings.Common.cancel)
              }
            } message: {
              TextState(LocalizedStrings.Personal.recurringDeleteSeriesMessage)
            }
          }
          return .none

        case .view(.excludeInstanceTapped):
          guard let instance = state.selectedInstance else { return .none }
          var updated = state.recurringEvent
          updated.excludedDates.insert(instance.dateKey)
          return .run { [recurringPersonalEventClient] send in
            do {
              try await recurringPersonalEventClient.updateEvent(updated)
              await send(.internal(.excludeInstanceSuccess(updated)))
            } catch {
              await send(.internal(.excludeInstanceFailed(error.localizedDescription)))
            }
          }

        // MARK: - Alert Actions

        case .alert(.presented(.confirmDeleteSeries)):
          state.isDeleting = true
          let eventId = state.recurringEvent.id
          return .run { [recurringPersonalEventClient] send in
            do {
              try await recurringPersonalEventClient.deleteEvent(eventId)
              await send(.internal(.deleteSeriesSuccess))
            } catch {
              await send(.internal(.deleteSeriesFailed(error.localizedDescription)))
            }
          }

        case .alert(.presented(.confirmExcludeInstance)):
          guard let instance = state.selectedInstance else { return .none }
          var updated = state.recurringEvent
          updated.excludedDates.insert(instance.dateKey)
          return .run { [recurringPersonalEventClient] send in
            do {
              try await recurringPersonalEventClient.updateEvent(updated)
              await send(.internal(.excludeInstanceSuccess(updated)))
            } catch {
              await send(.internal(.excludeInstanceFailed(error.localizedDescription)))
            }
          }

        case .alert:
          return .none

        // MARK: - Internal Actions

        case .internal(.deleteSeriesSuccess):
          state.isDeleting = false
          let event = state.recurringEvent
          return .run { [localNotificationClient] send in
            await cancelRecurringNotifications(event: event, client: localNotificationClient)
            await send(.delegate(.eventDeleted(id: event.id)))
          }

        case .internal(.deleteSeriesFailed):
          state.isDeleting = false
          return .none

        case .internal(.excludeInstanceSuccess(let updated)):
          state.recurringEvent = updated
          return .send(.delegate(.eventUpdated(updated)))

        case .internal(.excludeInstanceFailed):
          return .none

        // MARK: - Edit Delegate

        case .editEvent(.presented(.delegate(.eventCreated))):
          state.editEvent = nil
          return .none

        case .editEvent(.presented(.delegate(.eventUpdated(let updated)))):
          state.recurringEvent = updated
          state.editEvent = nil
          return .send(.delegate(.eventUpdated(updated)))

        case .editEvent(.presented(.delegate(.dismiss))):
          state.editEvent = nil
          return .none

        case .editEvent:
          return .none

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$editEvent, action: \.editEvent) {
        CreateRecurringPersonalEvent.Feature()
      }
      .ifLet(\.$deleteAlert, action: \.alert)
    }

    // MARK: - Notification Helper

    private func cancelRecurringNotifications(
      event: RecurringPersonalEventModel,
      client: LocalNotificationClient
    ) async {
      var ids = [
        "recurring-\(event.id)-daily",
        "recurring-\(event.id)-monthly",
      ]
      for weekday in 1...7 {
        ids.append("recurring-\(event.id)-weekly-\(weekday)")
      }
      await client.cancelAll(ids)
    }
  }
}
