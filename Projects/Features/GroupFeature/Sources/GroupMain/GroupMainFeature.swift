// 2025.11.05
// - 필터 적용시 애니메이션 (Like DiffableDatasource)
// - EmptyView 스켈레톤 맞추기?
// - 약속 만들기 가능하면 가져온 그룹 데이터 활용하기?
// - 반대 속성 버튼 동시 탭 막기 (수락 / 거절), adaptiveButton disabled 대응 (26 미만 버전)

// MARK: - Feature Namespace
import SwiftUI
import Shared
import Shared
import ComposableArchitecture

public enum GroupMain {}

extension GroupMain {
  
  private enum CancelID: Hashable {
    case respond(String)
  }
  
  enum RespondingState: Equatable {
    case idle, accepting, rejecting
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
      let currentUser: UserModel

      var selectedFilter: StatusFilter = .all

      var promisesState: LoadingState<[PromiseItem]> = .idle
      var proposalResponding: [String: RespondingState] = [:]
      var path = StackState<Path.State>()

      var allGroupSummaries: [GroupSummary]?
      var currentGroup: GroupModel?

      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var createGroup: CreateGroup.Feature.State?

      public init(currentUser: UserModel) {
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
      
      case path(StackActionOf<Path>)
      
      public enum ViewAction: Sendable {
        case onAppear
        case refreshTriggered
        case groupChanged(GroupSummary)
        case filterChanged(StatusFilter)
        case proposalAccepted(String)
        case proposalRejected(String)
        case openSideDrawer
        case groupManageTapped
        case createNewPromise
        case createGroup
        case joinGroup
      }
      
      public enum Internal: Sendable {
        case fetchGroupList
        case groupListResponse(Result<[GroupSummary], Error>)
        case setDefaultGroup(groups: [GroupSummary])
        case fetchCurrentGroup(id: String)
        case currentGroupResponse(Result<GroupModel, Error>)
        case fetchPromises(groupId: String)
        case loadPromisesResponse(Result<[PromiseItem], Error>)
        case proposalRespondDone(promiseId: String)
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
          switch viewAction {
          case .onAppear:
            guard !state.isInitialized else { return .none }
            state.isInitialized = true
            return .send(.internal(.fetchGroupList))

          case .refreshTriggered:
            if let currentGroupId = state.currentGroup?.id {
              state.promisesState = .loading
              return .merge(
                .send(.internal(.fetchCurrentGroup(id: currentGroupId))),
                .send(.internal(.fetchPromises(groupId: currentGroupId)))
              )
            }

            return .send(.internal(.fetchGroupList))
            
          case .groupChanged(let group):
            guard group.id != state.currentGroup?.id else { return .none }
            state.currentGroup = nil
            state.promisesState = .loading
            state.selectedFilter = .all
            return .send(.internal(.fetchCurrentGroup(id: group.id)))
            
          case .filterChanged(let filter):
            state.selectedFilter = filter
            return .none
            
          case .proposalAccepted(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .accepting
            return .run { [id] send in
              await send(.internal(.proposalRespondDone(promiseId: id)))
            }.cancellable(id: CancelID.respond(id), cancelInFlight: true)
            
          case .proposalRejected(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .rejecting
            return .run { [id] send in
              await send(.internal(.proposalRespondDone(promiseId: id)))
            }.cancellable(id: CancelID.respond(id), cancelInFlight: true)
            
          case .openSideDrawer:
            return .send(.delegate(.requestOpenSideDrawer))
            
          case .groupManageTapped:
            guard let currentGroup = state.currentGroup else { return .none }
            let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
            state.path.append(.manageGroupFeature(.init(group: currentGroup, summary: summary)))
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
            return .none
          }
          
        case .internal(let internalAction):
          switch internalAction {
          case .fetchGroupList:
            return .run { [groupClient] send in
              do {
                await send(.internal(.groupListResponse(.success(try await groupClient.fetchGroupSummaries()))))
              }
              catch {
                await send(.internal(.groupListResponse(.failure(error))))
              }
            }
            
          case .groupListResponse(.success(let groupSummaries)):
            state.allGroupSummaries = groupSummaries
            return .send(.internal(.setDefaultGroup(groups: groupSummaries)))
            
          case .groupListResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .setDefaultGroup(let groups):
            if let pinned = state.currentUser.pinnedGroupId,
               let pinnedGroup = groups.first(where: { $0.id == pinned }) {
              return .send(.internal(.fetchCurrentGroup(id: pinnedGroup.id)))
            } else {
              guard let firstGroup = groups.first else { return .none }
              return .send(.internal(.fetchCurrentGroup(id: firstGroup.id)))
            }

          case .fetchCurrentGroup(let id):
            return .run { [groupClient, id] send in
              do {
                let group = try await groupClient.fetchGroup(id)
                await send(.internal(.currentGroupResponse(.success(group))))
              } catch {
                await send(.internal(.currentGroupResponse(.failure(error))))
              }
            }

          case .currentGroupResponse(.success(let group)):
            state.currentGroup = group
            return .send(.internal(.fetchPromises(groupId: group.id)))

          case .currentGroupResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .fetchPromises(let id):
            return .run { [promiseClient, id] send in
              do {
                let promises = try await promiseClient.getActivePromises(id, 20)
                await send(.internal(.loadPromisesResponse(.success(promises))))
              }
              catch { await send(.internal(.loadPromisesResponse(.failure(error)))) }
            }
            
          case .loadPromisesResponse(.success(let promises)):
            state.promisesState = .loaded(promises)
            return .none
            
          case .loadPromisesResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .proposalRespondDone(let id):
            // FIXME: proposal responding 액션 구현
            state.proposalResponding[id] = nil
            return .none
            
          case .toggleGroupNotifications:
            return .none
          }
          
        case .createPromise(.presented(.delegate(.dismiss))):
          state.createPromise = nil
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
          
          //        case let .path(.element(id: id, action: .createGroup(.delegate(.dismiss)))):
          //          state.path[id: id] = nil
          //          return .none
          //
          //        case let .path(.element(id: id, action: .createGroup(.delegate(.groupCreated)))):
          //          state.path[id: id] = nil
          //          return .send(.internal(.fetchGroupList))
          //
          //        case let .path(.popFromID(id: id)):
          //          state.path[id: id] = nil
          //          return .none
          //
          //        case .path(.popToRoot):
          //          state.path = .init()
          //          return .none
          
        case .path:
          return .none
          
        case .binding, .delegate:
          return .none
          
        }
      }
      .ifLet(\.$createPromise, action: \.createPromise) { CreatePromise.Feature() }
      .ifLet(\.$createGroup, action: \.createGroup) { CreateGroup.Feature() }
      .forEach(\.path, action: \.path)
    }
  }
}
