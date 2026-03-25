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
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.weatherClient) var weatherClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: PersonalEventModel
      var isDeleting: Bool = false

      var weatherInfo: WeatherInfo?

      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

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
        case onAppear
        case editTapped
        case deleteTapped
        case toggleChecklist(blockId: String, itemId: String)
      }

      public enum Internal: Sendable {
        case deleteSuccess
        case deleteFailed(String)
        case fetchWeather
        case weatherFetched(Result<WeatherInfo, Error>)
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
          case .onAppear:
            if let cached = state.weatherCache[state.event.id] {
              state.weatherInfo = cached
            }
            let needsFetch = state.weatherInfo == nil
              || isWeatherStale(state.weatherInfo)
            if needsFetch {
              return .send(.internal(.fetchWeather))
            }
            return .none

          case .editTapped:
            state.editEvent = CreatePersonalEvent.Feature.State(
              event: state.event,
              mode: .edit
            )
            return .none

          case let .toggleChecklist(blockId, itemId):
            guard let blockIndex = state.event.descriptionBlocks.firstIndex(where: { $0.id == blockId }),
                  case .checklist(var items) = state.event.descriptionBlocks[blockIndex].content,
                  let itemIndex = items.firstIndex(where: { $0.id == itemId }) else {
              return .none
            }
            items[itemIndex].isChecked.toggle()
            state.event.descriptionBlocks[blockIndex].content = .checklist(items)
            let updatedEvent = state.event
            return .merge(
              .run { _ in await hapticFeedback.light() },
              .run { _ in
                try? await personalEventClient.updateEvent(updatedEvent)
              },
              .send(.delegate(.eventUpdated(updatedEvent)))
            )

          case .deleteTapped:
            let eventTitle = state.event.title
            state.deleteAlert = AlertState {
              TextState(LocalizedStrings.Shared.deleteEvent)
            } actions: {
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState(LocalizedStrings.Common.delete)
              }
              ButtonState(role: .cancel) {
                TextState(LocalizedStrings.Common.cancel)
              }
            } message: {
              TextState(LocalizedStrings.Shared.deleteEventConfirm(eventTitle))
            }
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

          case .fetchWeather:
            guard state.isPro else { return .none }
            guard let lat = state.event.location?.latitude,
                  let lng = state.event.location?.longitude,
                  !state.event.isPast else {
              return .none
            }
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)
            guard state.event.startAt < maxDate else { return .none }

            let date = state.event.startAt
            return .run { [weatherClient] send in
              do {
                let info = try await weatherClient.getWeather(lat, lng, date)
                await send(.internal(.weatherFetched(.success(info))))
              } catch {
                await send(.internal(.weatherFetched(.failure(error))))
              }
            }

          case .weatherFetched(let result):
            if case .success(let info) = result {
              state.weatherInfo = info
              state.$weatherCache.withLock { $0[state.event.id] = info }
            }
            return .none
          }

        // MARK: - Alert Actions

        case .alert(.presented(.confirmDelete)):
          state.isDeleting = true
          return .run { [event = state.event, calendarSyncClient, imageUploadClient] send in
            do {
              try await personalEventClient.deleteEvent(event.id)
              await localNotificationClient.cancel(event.notificationId)
              try? await calendarSyncClient.removePersonalEvent(event.id)

              // 이미지 Storage에서 제거 (best-effort)
              // TODO: Functions에서 prefix 기반 삭제로 변경 (schedule 삭제와 일관성)
              let validUrls = event.imageUrls.filter { !$0.isEmpty }
              if !validUrls.isEmpty {
                await imageUploadClient.deleteImages(validUrls)
              }

              await send(.internal(.deleteSuccess))
            } catch {
              await send(.internal(.deleteFailed(LocalizedStrings.Error.unknownError)))
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

    /// 날씨 캐시 유효 시간 (6시간)
    private static let weatherStalenessInterval: TimeInterval = 6 * 3600

    private func isWeatherStale(_ info: WeatherInfo?) -> Bool {
      guard let info else { return true }
      return Date().timeIntervalSince(info.fetchedAt) > Self.weatherStalenessInterval
    }
  }
}
