import ComposableArchitecture
import Clients
import PromisoShared

public enum PromiseDetail {}

extension PromiseDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.liveActivityClient) var liveActivityClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var promise: PromiseModel
      let currentUserId: String
      var respondingState: RespondingState = .idle
      var isDeleting: Bool = false
      var showShareSheet: Bool = false

      // 그룹 멤버 정보 (참여자 이름 표시용)
      var groupMembers: [UserPublicModel]?

      // 멤버 시트 상태
      var memberSheet: MemberSheetState?

      // 수정 시트 상태
      @Presents var editPromise: EditPromise.Feature.State?

      // 삭제 확인 알럿
      @Presents var alert: AlertState<Action.Alert>?

      // MARK: - Live Activity State
      // iOS 18 Broadcast 방식으로 전환: 수동 시작 제거, 자동 시작만 사용
      var isLiveActivityActive: Bool = false
      var liveActivityId: String?

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

      /// 수정 가능 여부 (호스트 && 시작 전)
      var canEdit: Bool {
        isHost && promise.startAt > Date()
      }

      // canStartLiveActivity 제거됨 - iOS 18 Broadcast 방식으로 자동 시작만 사용

      /// 내가 약속에 참여 중인지 (accepted)
      var isParticipating: Bool {
        promise.votes.accepted.contains(currentUserId)
      }
    }

    enum RespondingState: Equatable {
      case idle, accepting, rejecting, resetting
    }

    public struct MemberSheetState: Equatable, Identifiable {
      public var id: String { title }
      let title: String
      let members: [UserPublicModel]
      let colorType: ParticipantColorType
    }

    public enum ParticipantColorType: Sendable, Equatable {
      case accepted   // green
      case declined   // red
      case pending    // gray
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)
      case editPromise(PresentationAction<EditPromise.Feature.Action>)
      case alert(PresentationAction<Alert>)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case dismissTapped
        case acceptTapped
        case rejectTapped
        case resetTapped
        case deleteTapped
        case editTapped
        case shareTapped
        case shareSheetDismissed
        case participantGroupTapped(title: String, userIds: [String], colorType: ParticipantColorType)
        case memberSheetDismissed
        // Live Activity - 수동 시작 제거됨, 종료/도착만 유지
        case liveActivityStopTapped
        case markArrivedTapped
        case checkPendingIntents
      }

      @CasePathable
      public enum Alert: Sendable {
        case confirmDelete
      }

      public enum Internal: Sendable {
        case respondPromise(status: PromiseAttendanceStatus)
        case respondDone(status: PromiseAttendanceStatus)
        case respondFailed(error: AppError)
        case deletePromise
        case deleteDone
        case deleteFailed(error: AppError)
        case promiseUpdated(PromiseModel)
        // Live Activity - startLiveActivity, liveActivityStarted 제거됨 (자동 시작으로 전환)
        case liveActivityEnded
        case markArrivalDone
        case markArrivalFailed(error: AppError)
        case processPendingETAUpdate(ETAUpdate)
        case liveActivityUpdated
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
          switch viewAction {
          case .onAppear:
            // Pending Intent 확인 (Widget에서 저장한 출발/도착 상태)
            return .send(.view(.checkPendingIntents))

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
            let promiseTitle = state.promise.title
            state.alert = AlertState {
              TextState("약속 삭제")
            } actions: {
              ButtonState(role: .cancel) {
                TextState("취소")
              }
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("삭제")
              }
            } message: {
              TextState("'\(promiseTitle)' 약속을 삭제하시겠습니까?\n삭제된 약속은 복구할 수 없습니다.")
            }
            return .none

          case .editTapped:
            guard state.canEdit else { return .none }
            let maxMembers = state.groupMembers?.count ?? state.promise.minimumParticipants
            state.editPromise = EditPromise.Feature.State(
              promise: state.promise,
              maxMembers: maxMembers
            )
            return .none

          case .shareTapped:
            state.showShareSheet = true
            return .none

          case .shareSheetDismissed:
            state.showShareSheet = false
            return .none

          case let .participantGroupTapped(title, userIds, colorType):
            guard let members = state.groupMembers else { return .none }
            let resolvedMembers = userIds.compactMap { userId in
              members.first { $0.userId == userId }
            }
            state.memberSheet = MemberSheetState(
              title: title,
              members: resolvedMembers,
              colorType: colorType
            )
            return .none

          case .memberSheetDismissed:
            state.memberSheet = nil
            return .none
            
          // MARK: - Live Activity View Actions
          case .liveActivityStopTapped:
            guard let activityId = state.liveActivityId else { return .none }
            return .run { [liveActivityClient] send in
              try await liveActivityClient.end(activityId)
              await send(.internal(.liveActivityEnded))
            }

          case .markArrivedTapped:
            // TODO: Firebase Functions 호출하여 도착 상태 업데이트
            // 현재는 로컬에서만 처리
            return .send(.internal(.markArrivalDone))

          case .checkPendingIntents:
            // Widget에서 저장한 Intent 확인 후 처리
            guard state.isLiveActivityActive else { return .none }

            return .run { [liveActivityClient] send in
              // ETA 업데이트 Intent 확인
              if let etaUpdate = liveActivityClient.pendingETAUpdate() {
                liveActivityClient.clearETAUpdate()
                await send(.internal(.processPendingETAUpdate(etaUpdate)))
              }
            }
          }

        case .internal(let internalAction):
          switch internalAction {
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

          // MARK: - Live Activity Internal Actions
          // startLiveActivity, liveActivityStarted, liveActivityFailed 제거됨
          // iOS 18 Broadcast 방식: 예약 시간에 자동 시작됨

          case .liveActivityEnded:
            state.isLiveActivityActive = false
            state.liveActivityId = nil
            return .none

          case .markArrivalDone:
            // TODO: 서버 연동 후 상태 업데이트
            return .none

          case .markArrivalFailed:
            return .none

          case .processPendingETAUpdate(let etaUpdate):
            // Widget에서 저장한 ETA 업데이트 처리
            guard let activityId = state.liveActivityId,
                  etaUpdate.promiseId == state.promise.id else {
              return .none
            }

            return .run { [liveActivityClient] send in
              guard let currentState = liveActivityClient.currentState() else { return }
              let updatedState = currentState.updating(
                participantId: etaUpdate.userId,
                estimatedArrivalMinutes: etaUpdate.estimatedMinutes
              )
              try await liveActivityClient.update(activityId, updatedState)
              await send(.internal(.liveActivityUpdated))
            } catch: { _, _ in
              // 업데이트 실패 시 무시
            }

          case .liveActivityUpdated:
            // UI 업데이트 완료
            return .none
          }

        case .delegate:
          return .none

        case .editPromise(.presented(.delegate(.cancelled))):
          state.editPromise = nil
          return .none

        case .editPromise(.presented(.delegate(.promiseUpdated(let promise)))):
          state.editPromise = nil
          state.promise = promise
          return .send(.delegate(.promiseUpdated(promise)))

        case .editPromise:
          return .none

        case .alert(.presented(.confirmDelete)):
          state.isDeleting = true
          return .send(.internal(.deletePromise))

        case .alert:
          return .none
        }
      }
      .ifLet(\.$editPromise, action: \.editPromise) {
        EditPromise.Feature()
      }
      .ifLet(\.$alert, action: \.alert)
    }
  }
}
