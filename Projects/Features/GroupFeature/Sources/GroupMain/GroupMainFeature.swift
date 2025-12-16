// 2025.11.05
// - 필터 적용시 애니메이션 (Like DiffableDatasource)
// - EmptyView 스켈레톤 맞추기?
// - 약속 만들기 가능하면 가져온 그룹 데이터 활용하기?
// - 반대 속성 버튼 동시 탭 막기 (수락 / 거절), adaptiveButton disabled 대응 (26 미만 버전)

// MARK: - Feature Namespace
import SwiftUI
import Domain
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

      var allGroups: [GroupModel]?
      var currentGroup: GroupModel?

      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var groupDetail: GroupDetailState?
      @Presents var createGroup: CreateGroup.Feature.State?

      public init(currentUser: UserModel) {
        self.currentUser = currentUser
      }
    }
    @Reducer
    public enum Path {
      case createGroupFeature(CreateGroup.Feature)
    }
    
    public struct GroupDetailState: Equatable {
      public var isPresented: Bool = false
    }
    
    public enum Action: Sendable {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)
      
      case createPromise(PresentationAction<CreatePromise.Feature.Action>)
      case groupDetail(PresentationAction<GroupDetailAction>)
      case createGroup(PresentationAction<CreateGroup.Feature.Action>)
      
      case path(StackActionOf<Path>)
      
      public enum View: Sendable {
        case onAppear
        case groupChanged(GroupModel)
        case filterChanged(StatusFilter)
        case proposalAccepted(String)
        case proposalRejected(String)
        case openSideDrawer
        case groupManageTapped
        case createNewPromise
        case groupDetailDismissed
        case createGroup
        case joinGroup
      }
      
      public enum Internal: Sendable {
        case fetchGroupList
        case groupListResponse(Result<[GroupModel], Error>)
        case setDefaultGroup(groups: [GroupModel])
        case fetchPromises(groupId: String)
        case loadPromisesResponse(Result<[PromiseItem], Error>)
        case proposalRespondDone(promiseId: String)
        case toggleGroupNotifications
      }
      
      public enum Delegate: Sendable {
        case requestOpenSideDrawer
      }
    }
    
    public enum GroupDetailAction: Sendable, Equatable {
      case dismiss, settings, toggleNotifications
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
            
          case .groupChanged(let group):
            guard group != state.currentGroup else { return .none }
            state.currentGroup = group
            state.promisesState = .loading
            state.selectedFilter = .all
            guard let id = state.currentGroup?.id else { return .none }
            return .send(.internal(.fetchPromises(groupId: id)))
            
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
            state.groupDetail = GroupDetailState(isPresented: true)
            return .none
            
          case .createNewPromise:
            state.createPromise = CreatePromise.Feature.State()
            return .none
            
          case .groupDetailDismissed:
            state.groupDetail = nil
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
              do { await send(.internal(.groupListResponse(.success(try await groupClient.fetchGroups())))) }
              catch { await send(.internal(.groupListResponse(.failure(error)))) }
            }
            
          case .groupListResponse(.success(let groups)):
            state.allGroups = groups
            return .send(.internal(.setDefaultGroup(groups: groups)))
            
          case .groupListResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .setDefaultGroup(let groups):
            if let pinned = state.currentUser.pinnedGroupId,
               let pinnedGroup = groups.first(where: { $0.id == pinned }) {
              state.currentGroup = pinnedGroup
            } else {
              state.currentGroup = groups.first
            }
            
            if let id = state.currentGroup?.id {
              return .send(.internal(.fetchPromises(groupId: id)))
            }
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
          
        case .groupDetail(.presented(.dismiss)):
          state.groupDetail = nil
          return .none
          
        case .groupDetail:
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


// MARK: - View Implementation

extension GroupMain {
  public struct RootView: View {
    @Bindable private var store: StoreOf<GroupMain.Feature>
    
    public init(store: StoreOf<GroupMain.Feature>) {
      self.store = store
    }
    
    public var body: some View {
      NavigationStackStore(
        store.scope(state: \.path, action: \.path)) {
          rootContent
        } destination: { store in
          switch store.case {
          case .createGroupFeature(let createGroupStore):
            CreateGroup.RootView(store: createGroupStore)
          }
        }
    }
    
    
    
    @ViewBuilder
    private var rootContent: some View {
      Group {
        if store.shouldShowEmptyGroupView {
          groupDetailEmptyView
        } else {
          groupDetailView
        }
      }
      .auroraBackground()
      .toolbarVisibility(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .onAppear { store.send(.view(.onAppear)) }
      .fullScreenCover(
        store: store.scope(state: \.$createPromise, action: \.createPromise)
      ) { childStore in
        CreatePromise.RootView(store: childStore)
      }
      .fullScreenCover(
        store: store.scope(state: \.$createGroup, action: \.createGroup)
      ) { childStore in
        NavigationStack {
          CreateGroup.RootView(store: childStore)
        }
      }
      .sheet(
        store: store.scope(state: \.$groupDetail, action: \.groupDetail)
      ) { childStore in
        //        GroupDetailView(store: childStore)
      }
    }
    
    
    @ViewBuilder
    private var groupDetailView: some View {
      ScrollView {
        // Status Filter
        StatusFilterView(
          selectedFilter: Binding(
            get: { store.selectedFilter },
            set: { store.send(.view(.filterChanged($0))) }
          )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        
        // Promise Timeline
        PromiseTimelineView(
          promisesState: store.promisesState,
          selectedFilter: store.selectedFilter,
          onAccept: { promiseId in store.send(.view(.proposalAccepted(promiseId))) },
          acceptLoadingIds: store.acceptingProposalIds,
          onReject: { promiseId in store.send(.view(.proposalRejected(promiseId))) },
          rejectLoadingIds: store.rejectingProposalIds
        )
      }
    }
    
    @ViewBuilder
    private var groupDetailEmptyView: some View {
      ScrollView {
        VStack(spacing: 0) {
          Spacer()
            .frame(height: 80)
          
          VStack(spacing: 32) {
            // Illustration
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 120, height: 120)
              
              Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                  LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            }
            
            // Text
            VStack(spacing: 12) {
              Text("그룹이 선택되지 않았어요")
                .font(.title3.bold())
              
              Text("그룹을 만들거나 참여해서\n친구들과 약속을 시작해보세요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            
            // Action Buttons
            VStack(spacing: 12) {
              GlassActionButton(
                title: "그룹 만들기",
                leadingSystemImage: "plus.circle.fill",
                isPrimary: true,
                action: { store.send(.view(.createGroup))
                }
              )
              
              GlassActionButton(
                title: "초대 코드로 참여하기",
                leadingSystemImage: "link.circle.fill",
                isPrimary: false,
                action: { store.send(.view(.joinGroup)) }
              )
            }
            .padding(.horizontal, 40)
          }
          
          Spacer()
            .frame(height: 80)
        }
      }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      if let currentGroup = store.currentGroup {
        ToolbarItem(placement: .principal) {
          Text(currentGroup.title)
        }
        
        ToolbarTitleMenu {
          if let allGroups = store.allGroups, allGroups.isEmpty == false {
            ForEach(allGroups, id: \.id) { group in
              Button {
                store.send(.view(.groupChanged(group)))
              } label: {
                if group == currentGroup {
                  Label(group.title, systemImage: "checkmark")
                } else {
                  Text(group.title)
                }
              }
              .disabled(group == currentGroup)
            }
            
            Divider()
          }
          
          Menu("그룹 추가") {
            Button("그룹 만들기", systemImage: "plus") {
              store.send(.view(.createGroup))
            }
            
            Button("초대 코드로 참여하기", systemImage: "link") {
              store.send(.view(.joinGroup))
            }
          }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          ToolbarButton(
            imageName: "plus",
            action: { store.send(.view(.createNewPromise)) }
          )
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          ToolbarButton(
            imageName: "gearshape",
            action: { store.send(.view(.groupManageTapped)) }
          )
        }
      } else {
        ToolbarItem(placement: .principal) {
          EmptyView()
        }
      }
    }
  }
}

private extension GroupMain.Feature.State {
  
  /// 속한 그룹이 없는 경우
  private var hasNoGroups: Bool {
    allGroups?.isEmpty == true && currentGroup == nil
  }
  
  /// 활성화된 그룹이 없는 경우
  var shouldShowEmptyGroupView: Bool {
    !promisesState.isLoading && hasNoGroups
  }
  
  /// 현재 수락 처리중인 약속 ID 목록
  var acceptingProposalIds: Set<String> {
    Set(proposalResponding.compactMap { entry in
      entry.value == .accepting ? entry.key : nil
    })
  }
  
  /// 현재 거절 처리중인 약속 ID 목록
  var rejectingProposalIds: Set<String> {
    Set(proposalResponding.compactMap { entry in
      entry.value == .rejecting ? entry.key : nil
    })
  }
  
  /// 특정 약속의 응답 상태 조회
  func respondingState(for promiseId: String) -> GroupMain.RespondingState {
    proposalResponding[promiseId] ?? .idle
  }
}
