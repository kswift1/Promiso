import ComposableArchitecture
import Clients

public enum EditPromise {}

extension EditPromise {
  @Reducer
  public struct Feature {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.promiseClient) var promiseClient

    private enum CancelID: Hashable {
      case emojiSuggestDebounce
    }

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var originalPromise: PromiseModel
      var editedPromise: PromiseModel
      var isUpdating: Bool = false
      var updateError: Clients.PromiseClientError?

      /// 그룹 최대 멤버 수 (minimumParticipants 상한)
      var maxMembers: Int

      public init(
        promise: PromiseModel,
        maxMembers: Int
      ) {
        self.originalPromise = promise
        self.editedPromise = promise
        self.maxMembers = maxMembers
      }

      /// 변경 사항 있는지 확인
      var hasChanges: Bool {
        originalPromise.title != editedPromise.title ||
        originalPromise.emoji != editedPromise.emoji ||
        originalPromise.description != editedPromise.description ||
        originalPromise.startAt != editedPromise.startAt ||
        originalPromise.endAt != editedPromise.endAt ||
        originalPromise.minimumParticipants != editedPromise.minimumParticipants ||
        originalPromise.trackingStartMinutesBefore != editedPromise.trackingStartMinutesBefore
      }

      /// 저장 가능 여부
      var canSave: Bool {
        hasChanges &&
        editedPromise.isTitleValid &&
        editedPromise.isStartTimeValid &&
        editedPromise.isEndTimeValid &&
        editedPromise.isMinimumParticipantsValid
      }

      /// 종료 시간 사용 여부
      var useEndTime: Bool {
        editedPromise.endAt != nil
      }

      /// 실시간 공유 사용 여부
      var useRealtimeShare: Bool {
        editedPromise.trackingStartMinutesBefore != nil
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case setTitle(String)
        case setEmoji(String)
        case setDescription(String)
        case setStartDate(Date)
        case setEndDate(Date?)
        case toggleUseEndTime
        case incrementParticipants
        case decrementParticipants
        case toggleUseRealtimeShare
        case setTrackingMinutes(Int)
        case saveTapped
        case cancelTapped
        case clearError
      }

      public enum Internal: Sendable {
        case titleDebounced(String)
        case emojiSuggestionsResponse([EmojiSuggestion])
        case updatePromiseResponse(Result<Void, Clients.PromiseClientError>)
      }

      public enum Delegate: Sendable {
        case cancelled
        case promiseUpdated(PromiseModel)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .setTitle(let title):
            state.editedPromise.title = title
            return .merge(
              .cancel(id: CancelID.emojiSuggestDebounce),
              .run { [clock, title] send in
                try await clock.sleep(for: .milliseconds(1_000))
                await send(.internal(.titleDebounced(title)))
              }
              .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
            )

          case .setEmoji(let emoji):
            state.editedPromise.emoji = emoji.isEmpty ? nil : emoji
            return .none

          case .setDescription(let description):
            let trimmed = String(description.prefix(500))
            state.editedPromise.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .setStartDate(let date):
            state.editedPromise.startAt = date
            if let end = state.editedPromise.endAt, end <= date {
              state.editedPromise.endAt = date.addingTimeInterval(7200)
            }
            return .none

          case .setEndDate(let date):
            state.editedPromise.endAt = date
            return .none

          case .toggleUseEndTime:
            if state.editedPromise.endAt == nil {
              state.editedPromise.endAt = state.editedPromise.startAt.addingTimeInterval(7200)
            } else {
              state.editedPromise.endAt = nil
            }
            return .none

          case .incrementParticipants:
            let current = state.editedPromise.minimumParticipants
            if current < state.maxMembers {
              state.editedPromise.minimumParticipants = current + 1
            }
            return .none

          case .decrementParticipants:
            let current = state.editedPromise.minimumParticipants
            if current > 2 {
              state.editedPromise.minimumParticipants = current - 1
            }
            return .none

          case .toggleUseRealtimeShare:
            if state.editedPromise.trackingStartMinutesBefore == nil {
              state.editedPromise.trackingStartMinutesBefore = 30  // 기본값 30분
            } else {
              state.editedPromise.trackingStartMinutesBefore = nil
            }
            return .none

          case .setTrackingMinutes(let minutes):
            state.editedPromise.trackingStartMinutesBefore = minutes
            return .none

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isUpdating = true
            state.updateError = nil
            return .run { [promise = state.editedPromise, promiseClient] send in
              do {
                try await promiseClient.updatePromise(promise)
                await send(.internal(.updatePromiseResponse(.success(()))))
              } catch let e as Clients.PromiseClientError {
                await send(.internal(.updatePromiseResponse(.failure(e))))
              } catch {
                await send(.internal(.updatePromiseResponse(.failure(.unknown(error.localizedDescription)))))
              }
            }

          case .cancelTapped:
            return .send(.delegate(.cancelled))

          case .clearError:
            state.updateError = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .titleDebounced(let title):
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
            // 제목이 원본과 다를 때만 이모지 추천
            guard title != state.originalPromise.title else { return .none }
            return .run { [title] send in
              let picks = await EmojiSuggestorProvider.shared.suggest(for: title, topK: 10)
              await send(.internal(.emojiSuggestionsResponse(picks)))
            }

          case .emojiSuggestionsResponse(let picks):
            if let firstEmoji = picks.first?.emoji {
              state.editedPromise.emoji = firstEmoji
            }
            return .none

          case .updatePromiseResponse(.success):
            state.isUpdating = false
            return .send(.delegate(.promiseUpdated(state.editedPromise)))

          case .updatePromiseResponse(.failure(let error)):
            state.isUpdating = false
            state.updateError = error
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
