import ComposableArchitecture
import Clients

public enum PromiseDetail {}

extension PromiseDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var promise: PromiseModel
      let currentUserId: String
      var respondingState: RespondingState = .idle
      var isDeleting: Bool = false

      // 그룹 멤버 정보 (참여자 이름 표시용)
      var groupMembers: [UserPublicModel]?

      public init(
        promise: PromiseModel,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.promise = promise
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }

      var isHost: Bool {
        promise.isHost(userId: currentUserId)
      }

      var myVoteStatus: VoteStatus {
        promise.myVoteStatus(userId: currentUserId)
      }

      var responseStatus: PromiseResponseStatus {
        promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count)
      }
    }

    enum RespondingState: Equatable {
      case idle, accepting, rejecting, resetting
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case onAppear
        case dismissTapped
        case acceptTapped
        case rejectTapped
        case resetTapped
        case deleteTapped
        case editTapped
        case shareTapped
      }

      public enum Internal: Sendable {
        case respondPromise(status: PromiseAttendanceStatus)
        case respondDone(status: PromiseAttendanceStatus)
        case respondFailed(error: AppError)
        case deletePromise
        case deleteDone
        case deleteFailed(error: AppError)
        case promiseUpdated(PromiseModel)
      }

      public enum Delegate: Sendable {
        case dismiss
        case promiseDeleted(id: String)
        case promiseUpdated(PromiseModel)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .delegate:
          return .none
        }
      }
    }

    private func handleViewAction(
      _ state: inout State,
      _ action: Action.ViewAction
    ) -> Effect<Action> {
      switch action {
      case .onAppear:
        return .none

      case .dismissTapped:
        return .send(.delegate(.dismiss))

      case .acceptTapped:
        guard state.respondingState == .idle else { return .none }
        state.respondingState = .accepting
        return .send(.internal(.respondPromise(status: .accepted)))

      case .rejectTapped:
        guard state.respondingState == .idle else { return .none }
        state.respondingState = .rejecting
        return .send(.internal(.respondPromise(status: .declined)))

      case .resetTapped:
        guard state.respondingState == .idle else { return .none }
        state.respondingState = .resetting
        return .send(.internal(.respondPromise(status: .pending)))

      case .deleteTapped:
        guard !state.isDeleting else { return .none }
        state.isDeleting = true
        return .send(.internal(.deletePromise))

      case .editTapped:
        // TODO: 수정 화면 연결
        return .none

      case .shareTapped:
        // TODO: 공유 기능
        return .none
      }
    }

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.Internal
    ) -> Effect<Action> {
      switch action {
      case .respondPromise(let status):
        let promiseId = state.promise.id
        return .run { [promiseClient] send in
          do {
            try await promiseClient.respondPromise(promiseId, status)
            await send(.internal(.respondDone(status: status)))
          } catch {
            await send(.internal(.respondFailed(error: AppError(error))))
          }
        }

      case .respondDone(let status):
        state.respondingState = .idle
        // 로컬 상태 업데이트 (immutable이므로 새로 생성)
        var newAccepted = state.promise.votes.accepted.filter { $0 != state.currentUserId }
        var newDeclined = state.promise.votes.declined.filter { $0 != state.currentUserId }

        switch status {
        case .accepted:
          newAccepted.append(state.currentUserId)
        case .declined:
          newDeclined.append(state.currentUserId)
        case .pending:
          break // 둘 다 제거된 상태 유지
        }

        state.promise.votes = PromiseVotesModel(
          accepted: newAccepted,
          declined: newDeclined,
          until: state.promise.votes.until
        )
        return .send(.delegate(.promiseUpdated(state.promise)))

      case .respondFailed:
        state.respondingState = .idle
        return .none

      case .deletePromise:
        let promiseId = state.promise.id
        return .run { [promiseClient] send in
          do {
            try await promiseClient.deletePromise(promiseId)
            await send(.internal(.deleteDone))
          } catch {
            await send(.internal(.deleteFailed(error: AppError(error))))
          }
        }

      case .deleteDone:
        state.isDeleting = false
        return .send(.delegate(.promiseDeleted(id: state.promise.id)))

      case .deleteFailed:
        state.isDeleting = false
        return .none

      case .promiseUpdated(let promise):
        state.promise = promise
        return .none
      }
    }
  }
}
