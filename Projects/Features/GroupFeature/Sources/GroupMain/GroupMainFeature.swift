import PromisoShared
import Clients

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
      var myResponses: [String: PromiseAttendanceStatus] = [:]
      var path = StackState<Path.State>()

      var allGroupSummaries: [UserGroupInfo]?
      var currentGroup: GroupModel?
      var currentGroupMembers: [UserPublicModel]?

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
        case groupChanged(UserGroupInfo)
        case filterChanged(StatusFilter)
        case proposalAccepted(String)
        case proposalRejected(String)
        case promiseDeleted(String)
        case responseChanged(String, PromiseAttendanceStatus)
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
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .createPromise(.presented(.delegate(.dismiss))):
          state.createPromise = nil
          return .none
        case .createPromise(.presented(.delegate(.promiseCreated(id: _)))):
          state.createPromise = nil
          // 리스너가 자동으로 새 약속을 감지함
          return .none
        case .createPromise:
          return .none
        case .createGroup(.presented(.delegate(.dismiss))):
          state.createGroup = nil
          return .none
        case .createGroup(.presented(.delegate(.groupCreated(id: _)))):
          state.createGroup = nil
          return .send(.internal(.fetchGroupList))
        case .createGroup:
          return .none
        case .joinGroup(.presented(.delegate(.dismiss))):
          state.joinGroup = nil
          return .none
        case .joinGroup(.presented(.delegate(.groupJoined(_)))):
          state.joinGroup = nil
          return .send(.internal(.fetchGroupList))
        case .joinGroup:
          return .none
        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupLeft)))):
          // 그룹 나가기 성공 -> 그룹 목록 새로고침
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))
        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupDeleted)))):
          // 그룹 삭제 성공 -> 그룹 목록 새로고침
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))
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

    private func handleViewAction(
      _ state: inout State,
      _ viewAction: Action.ViewAction
    ) -> EffectOf<Self> {
      switch viewAction {
      case .onAppear:
        guard !state.isInitialized else { return .none }
        state.isInitialized = true
        // 초기 로드: currentUser.sortedGroups 사용
        let summaries = state.currentUser.sortedGroups
        state.allGroupSummaries = state.currentUser.sortedGroups
        return .send(.internal(.setDefaultGroup(groups: summaries)))
      case .refreshTriggered:
        // 리로드: 서버에서 최신 데이터 조회
        state.promisesState = .loading
        return .send(.internal(.fetchGroupList))
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
        return .send(
          .internal(.respondPromise(promiseId: id, status: .accepted))
        )
        .cancellable(id: CancelID.respond(id), cancelInFlight: true)
      case .proposalRejected(let id):
        guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
        state.proposalResponding[id] = .rejecting
        return .send(
          .internal(.respondPromise(promiseId: id, status: .declined))
        )
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
        return .send(
          .internal(.respondPromise(promiseId: id, status: status))
        )
        .cancellable(id: CancelID.respond(id), cancelInFlight: true)
      case .openSideDrawer:
        return .send(.delegate(.requestOpenSideDrawer))
      case .groupManageTapped:
        guard let currentGroup = state.currentGroup else { return .none }
        let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
        state.path.append(.manageGroupFeature(.init(
          group: currentGroup,
          summary: summary,
          currentUserId: state.currentUser.userId,
          preloadedMembers: state.currentGroupMembers
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
        // 초대 코드 자동 입력 및 미리보기 자동 시작
        joinState.inviteCode = inviteCode
        state.joinGroup = joinState
        // 자동으로 미리보기 시작
        return .send(.joinGroup(.presented(.view(.nextTapped))))
      }
    }

    private func handleInternalAction(
      _ state: inout State,
      _ internalAction: Action.Internal
    ) -> EffectOf<Self> {
      switch internalAction {
      case .fetchGroupList:
        return .run { [groupClient] send in
          do {
            await send(.internal(.groupListResponse(.success(try await groupClient.fetchGroupSummaries()))))
          }
          catch {
            await send(.internal(.groupListResponse(.failure(AppError(error)))))
          }
        }
      case .groupListResponse(.success(let groupSummaries)):
        state.allGroupSummaries = groupSummaries
        // 현재 선택된 그룹이 있으면 해당 그룹 데이터도 새로고침
        if let currentGroupId = state.currentGroup?.id,
           groupSummaries.contains(where: { $0.id == currentGroupId }) {
          return .merge(
            .send(.internal(.fetchCurrentGroup(id: currentGroupId))),
            .send(.internal(.fetchGroupMembers(groupId: currentGroupId))),
            .send(.internal(.subscribeToPromises(groupId: currentGroupId)))
          )
        }
        // 현재 그룹이 없거나 삭제된 경우 첫 번째 그룹으로 설정
        return .send(.internal(.setDefaultGroup(groups: groupSummaries)))
      case .groupListResponse(.failure(let error)):
        state.promisesState = .failed(error)
        return .none
      case .setDefaultGroup(let groups):
        guard let firstGroup = groups.first else { return .none }
        return .send(.internal(.fetchCurrentGroup(id: firstGroup.id)))
      case .fetchCurrentGroup(let id):
        return .run { [groupClient, id] send in
          do {
            let group = try await groupClient.fetchGroup(id)
            await send(.internal(.currentGroupResponse(.success(group))))
          } catch {
            await send(.internal(.currentGroupResponse(.failure(AppError(error)))))
          }
        }
      case .currentGroupResponse(.success(let group)):
        state.currentGroup = group
        return .merge(
          .send(.internal(.fetchGroupMembers(groupId: group.id))),
          .send(.internal(.subscribeToPromises(groupId: group.id)))
        )
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
        return .none
      case .groupMembersResponse(.failure):
        // 멤버 조회 실패는 치명적이지 않으므로 무시
        state.currentGroupMembers = nil
        return .none
      case .subscribeToPromises(let groupId):
        state.promisesState = .loading
        return .run { [promiseClient, groupId] send in
          for await promises in promiseClient.subscribeToPromises(groupId, 20) {
            await send(.internal(.promisesUpdated(promises)))
          }
        }
        .cancellable(id: CancelID.promiseSubscription, cancelInFlight: true)
      case .promisesUpdated(let promises):
        state.promisesState = .loaded(promises)
        return .none
      case .proposalRespondDone(let id, let status):
        state.proposalResponding[id] = nil
        state.myResponses[id] = status
        return .none
      case .proposalRespondFailed(let id, let error):
        state.proposalResponding[id] = nil
        state.promisesState = .failed(error)
        return .none
      case .respondPromise(let promiseId, let status):
        return .run { [promiseClient, promiseId, status] send in
          do {
            try await promiseClient.respondPromise(promiseId, status)
            await send(.internal(.proposalRespondDone(promiseId: promiseId, status: status)))
            // 리스너가 자동으로 변경사항을 감지함
          } catch {
            await send(.internal(.proposalRespondFailed(promiseId: promiseId, error: AppError(error))))
          }
        }
      case .deletePromise(let promiseId):
        return .run { [promiseClient, promiseId] send in
          do {
            try await promiseClient.deletePromise(promiseId)
            await send(.internal(.deletePromiseDone(promiseId: promiseId)))
            // 리스너가 자동으로 변경사항을 감지함
          } catch {
            await send(.internal(.deletePromiseFailed(promiseId: promiseId, error: AppError(error))))
          }
        }
      case .deletePromiseDone:
        // Optimistically remove from list or refresh
        return .none
      case .deletePromiseFailed(_, let error):
        state.promisesState = .failed(error)
        return .none
      case .toggleGroupNotifications:
        return .none
      }
    }
  }
}
