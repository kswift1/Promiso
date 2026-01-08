import PromisoShared
import Clients
import SwiftUI

// MIDDLE
// TODO 5: 약속 정보 변경 (제목, 설명, 시간, 충족 인원 모두)
// TODO 7: 그룹 상세 - 그룹 이미지 공통 관리 및 변경 기능, 소개도

// LOW
// TODO 3: 요금제별 활성 약속 limit 변경 예정 - 현재는 10 통일
// TODO 1: 공유기능 고도화 해서 딥링크 연결
// TODO 8: 약속 카드 최종 개선방향 고민
// TODO 9: 최종 read 수 최적화 고민

public enum GroupMain {}

extension GroupMain {
  private enum CancelID: Hashable {
    case respond(String)
    case promiseSubscription
  }

  enum RespondingState: Equatable {
    case idle, accepting, rejecting, resetting
  }

  // MARK: - Feature Reducer
  @Reducer
  public struct Feature {

    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient

    public init() {}

    @ObservableState
    public struct State {
      var isInitialized: Bool = false
      let currentUser: UserPrivateModel

      var selectedFilter: StatusFilter = .needResponse

      var promisesState: LoadingState<[PromiseModel]> = .idle
      var proposalResponding: [String: RespondingState] = [:]
      var path = StackState<Path.State>()

      var allGroupSummaries: [UserGroupInfo]?
      var currentGroup: GroupModel?
      var currentGroupMembers: [UserPublicModel]?

      // 공유 시트용
      var sharePromise: PromiseModel?

      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var createGroup: CreateGroup.Feature.State?
      @Presents var joinGroup: JoinGroup.Feature.State?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }
    }

    @Reducer
    public enum Path {
      case manageGroupFeature(ManageGroup.Feature)
      case promiseDetail(PromiseDetail.Feature)
      case pastPromises(PastPromises.Feature)
      case pastPromiseDetail(PastPromiseDetail.Feature)
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)

      case createPromise(PresentationAction<CreatePromise.Feature.Action>)
      case createGroup(PresentationAction<CreateGroup.Feature.Action>)
      case joinGroup(PresentationAction<JoinGroup.Feature.Action>)

      case path(StackActionOf<Path>)

      public enum ViewAction: Sendable {
        case onAppear
        case refreshTriggered
        case scenePhaseChanged(ScenePhase)
        case groupChanged(UserGroupInfo)
        case filterChanged(StatusFilter)
        case proposalAccepted(String)
        case proposalRejected(String)
        case promiseDeleted(String)
        case responseChanged(String, PromiseAttendanceStatus)
        case promiseTapped(PromiseModel)
        case promiseShared(String)
        case sharePromiseDismissed
        case openSideDrawer
        case groupManageTapped
        case createNewPromise
        case createGroup
        case joinGroup
        case joinGroupWithCode(String) // 딥링크로 초대 코드와 함께 열기
      }

      public enum Internal: Sendable {
        case fetchGroupList
        case groupListResponse(Result<[UserGroupInfo], AppError>)
        case setDefaultGroup(groups: [UserGroupInfo])
        case fetchCurrentGroup(id: String)
        case currentGroupResponse(Result<GroupModel, AppError>)
        case fetchGroupMembers(groupId: String)
        case groupMembersResponse(Result<[UserPublicModel], AppError>)
        case subscribeToPromises(groupId: String)
        case cancelSubscription
        case promisesUpdated([PromiseModel])
        case proposalRespondDone(promiseId: String, status: PromiseAttendanceStatus)
        case proposalRespondFailed(promiseId: String, error: AppError)
        case respondPromise(promiseId: String, status: PromiseAttendanceStatus)
        case deletePromise(promiseId: String)
        case deletePromiseDone(promiseId: String)
        case deletePromiseFailed(promiseId: String, error: AppError)
        case toggleGroupNotifications
      }

      public enum Delegate: Sendable {
        case requestOpenSideDrawer
      }
    }

    // MARK: - Reducer Body
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        // MARK: - View Actions
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard !state.isInitialized else { return .none }
            state.isInitialized = true
            let summaries = state.currentUser.sortedGroups
            state.allGroupSummaries = state.currentUser.sortedGroups
            return .send(.internal(.setDefaultGroup(groups: summaries)))

          case .refreshTriggered:
            if !state.promisesState.isLoaded {
              state.promisesState = .loading
            }
            return .send(.internal(.fetchGroupList))

          case .scenePhaseChanged(let phase):
            switch phase {
            case .background:
              return .send(.internal(.cancelSubscription))
            case .active:
              guard let groupId = state.currentGroup?.id else { return .none }
              return .send(.internal(.subscribeToPromises(groupId: groupId)))
            case .inactive:
              return .none
            @unknown default:
              return .none
            }

          case .groupChanged(let group):
            guard group.id != state.currentGroup?.id else { return .none }
            state.currentGroup = nil
            state.currentGroupMembers = nil
            state.promisesState = .loading
            state.selectedFilter = .needResponse
            return .send(.internal(.fetchCurrentGroup(id: group.id)))

          case .filterChanged(let filter):
            state.selectedFilter = filter
            return .none

          case .proposalAccepted(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .accepting
            return .send(.internal(.respondPromise(promiseId: id, status: .accepted)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .proposalRejected(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .rejecting
            return .send(.internal(.respondPromise(promiseId: id, status: .declined)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .promiseDeleted(let id):
            return .send(.internal(.deletePromise(promiseId: id)))

          case .responseChanged(let id, let status):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            switch status {
            case .accepted:
              state.proposalResponding[id] = .accepting
            case .declined:
              state.proposalResponding[id] = .rejecting
            case .pending:
              state.proposalResponding[id] = .resetting
            }
            return .send(.internal(.respondPromise(promiseId: id, status: status)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .promiseTapped(let promise):
            state.path.append(.promiseDetail(.init(
              promise: promise,
              currentUserId: state.currentUser.userId,
              groupMembers: state.currentGroupMembers
            )))
            return .none

          case .promiseShared(let promiseId):
            guard let promise = state.promisesState.value?.first(where: { $0.id == promiseId }) else {
              return .none
            }
            state.sharePromise = promise
            return .none

          case .sharePromiseDismissed:
            state.sharePromise = nil
            return .none

          case .openSideDrawer:
            return .send(.delegate(.requestOpenSideDrawer))

          case .groupManageTapped:
            guard let currentGroup = state.currentGroup else { return .none }
            let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
            state.path.append(.manageGroupFeature(.init(
              group: currentGroup,
              summary: summary,
              currentUserId: state.currentUser.userId,
              preloadedMembers: state.currentGroupMembers,
              promises: state.promisesState.value ?? []
            )))
            return .none

          case .createNewPromise:
            state.createPromise = CreatePromise.Feature.State(
              groupSummaries: state.allGroupSummaries
            )
            return .none

          case .createGroup:
            state.createGroup = CreateGroup.Feature.State(
              currentUser: state.currentUser
            )
            return .none

          case .joinGroup:
            state.joinGroup = JoinGroup.Feature.State(
              currentUser: state.currentUser
            )
            return .none

          case .joinGroupWithCode(let inviteCode):
            var joinState = JoinGroup.Feature.State(
              currentUser: state.currentUser
            )
            joinState.inviteCode = inviteCode
            state.joinGroup = joinState
            return .send(.joinGroup(.presented(.view(.nextTapped))))
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .fetchGroupList:
            return .run { [groupClient] send in
              do {
                let summaries = try await groupClient.fetchGroupSummaries()
                await send(.internal(.groupListResponse(.success(summaries))))
              } catch {
                await send(.internal(.groupListResponse(.failure(AppError(error)))))
              }
            }

          case .groupListResponse(.success(let groupSummaries)):
            state.allGroupSummaries = groupSummaries
            if let currentGroupId = state.currentGroup?.id,
               groupSummaries.contains(where: { $0.id == currentGroupId }) {
              return .send(.internal(.fetchCurrentGroup(id: currentGroupId)))
            }
            return .send(.internal(.setDefaultGroup(groups: groupSummaries)))

          case .groupListResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none

          case .setDefaultGroup(let groups):
            guard let firstGroup = groups.first else { return .none }
            return .send(.internal(.fetchCurrentGroup(id: firstGroup.id)))

          case .fetchCurrentGroup(let id):
            return .run { [groupClient] send in
              do {
                let group = try await groupClient.fetchGroup(id)
                await send(.internal(.currentGroupResponse(.success(group))))
              } catch {
                await send(.internal(.currentGroupResponse(.failure(AppError(error)))))
              }
            }

          case .currentGroupResponse(.success(let group)):
            state.currentGroup = group
            // 멤버 정보 먼저 fetch 후 promises subscribe
            return .send(.internal(.fetchGroupMembers(groupId: group.id)))

          case .currentGroupResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none

          case .fetchGroupMembers(let groupId):
            return .run { [groupClient] send in
              do {
                let members = try await groupClient.fetchGroupMembers(groupId)
                await send(.internal(.groupMembersResponse(.success(members))))
              } catch {
                await send(.internal(.groupMembersResponse(.failure(AppError(error)))))
              }
            }

          case .groupMembersResponse(.success(let members)):
            state.currentGroupMembers = members
            // 멤버 로드 완료 후 promises subscribe
            guard let groupId = state.currentGroup?.id else { return .none }
            return .send(.internal(.subscribeToPromises(groupId: groupId)))

          case .groupMembersResponse(.failure):
            state.currentGroupMembers = nil
            // 멤버 조회 실패해도 promises는 subscribe
            guard let groupId = state.currentGroup?.id else { return .none }
            return .send(.internal(.subscribeToPromises(groupId: groupId)))

          case .subscribeToPromises(let groupId):
            if !state.promisesState.isLoaded {
              state.promisesState = .loading
            }
            print("[GroupMain] 🔔 subscribeToPromises 시작: groupId=\(groupId)")
            return .run { [promiseClient] send in
              print("[GroupMain] 🔔 리스너 연결 시작...")
              for await promises in promiseClient.subscribeToPromises(groupId, 20) {
                print("[GroupMain] 📥 promises 수신: \(promises.count)개")
                await send(.internal(.promisesUpdated(promises)))
              }
              print("[GroupMain] ⚠️ 리스너 스트림 종료됨")
            }
            .cancellable(id: CancelID.promiseSubscription, cancelInFlight: true)

          case .cancelSubscription:
            print("[GroupMain] ⏸️ 백그라운드 진입 - 구독 취소")
            return .cancel(id: CancelID.promiseSubscription)

          case .promisesUpdated(let promises):
            print("[GroupMain] ✅ promisesUpdated: \(promises.count)개 로드됨")
            state.promisesState = .loaded(promises)
            return .none

          case .proposalRespondDone(let id, _):
            state.proposalResponding[id] = nil
            return .none

          case .proposalRespondFailed(let id, let error):
            state.proposalResponding[id] = nil
            state.promisesState = .failed(error)
            return .none

          case .respondPromise(let promiseId, let status):
            return .run { [promiseClient] send in
              do {
                try await promiseClient.respondPromise(promiseId, status)
                await send(.internal(.proposalRespondDone(promiseId: promiseId, status: status)))
              } catch {
                await send(.internal(.proposalRespondFailed(promiseId: promiseId, error: AppError(error))))
              }
            }

          case .deletePromise(let promiseId):
            return .run { [promiseClient] send in
              do {
                try await promiseClient.deletePromise(promiseId)
                await send(.internal(.deletePromiseDone(promiseId: promiseId)))
              } catch {
                await send(.internal(.deletePromiseFailed(promiseId: promiseId, error: AppError(error))))
              }
            }

          case .deletePromiseDone:
            return .none

          case .deletePromiseFailed(_, let error):
            state.promisesState = .failed(error)
            return .none

          case .toggleGroupNotifications:
            return .none
          }

        // MARK: - Child Feature Actions
        case .createPromise(.presented(.delegate(.dismiss))):
          state.createPromise = nil
          return .none

        case .createPromise(.presented(.delegate(.promiseCreated))):
          state.createPromise = nil
          return .none

        case .createPromise(.presented(.delegate(.createGroupRequested))):
          state.createPromise = nil
          state.createGroup = CreateGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .createPromise:
          return .none

        case .createGroup(.presented(.delegate(.dismiss))):
          state.createGroup = nil
          return .none

        case .createGroup(.presented(.delegate(.groupCreated))):
          state.createGroup = nil
          return .send(.internal(.fetchGroupList))

        case .createGroup:
          return .none

        case .joinGroup(.presented(.delegate(.dismiss))):
          state.joinGroup = nil
          return .none

        case .joinGroup(.presented(.delegate(.groupJoined))):
          state.joinGroup = nil
          return .send(.internal(.fetchGroupList))

        case .joinGroup:
          return .none

        // MARK: - Path Actions
        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupLeft)))):
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupDeleted)))):
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.pastPromisesTapped)))):
          guard let groupId = state.currentGroup?.id else { return .none }
          state.path.append(.pastPromises(.init(
            groupId: groupId,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .pastPromises(.delegate(.promiseSelected(let promise))))):
          state.path.append(.pastPromiseDetail(.init(
            promise: promise,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated)))):
          return .none

        case .path:
          return .none

        case .binding, .delegate:
          return .none
        }
      }
      .ifLet(\.$createPromise, action: \.createPromise) { CreatePromise.Feature() }
      .ifLet(\.$createGroup, action: \.createGroup) { CreateGroup.Feature() }
      .ifLet(\.$joinGroup, action: \.joinGroup) { JoinGroup.Feature() }
      .forEach(\.path, action: \.path)
    }
  }
}
