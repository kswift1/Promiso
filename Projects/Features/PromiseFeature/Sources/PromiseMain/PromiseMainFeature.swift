// MARK: - Feature Namespace

/// Promise Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum PromiseMain {}

// MARK: - Core Feature Implementation

extension PromiseMain {
  
  // MARK: - Reducer
  
  /// Promise Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    /// Reducer를 위한 기본 initializer
    /// Feature가 성장함에 따라 dependency나 configuration을 여기에 추가
    public init() {}
    
    // MARK: - State
    
    /// Promise Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    ///
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      // MARK: - Status Filter
      public var selectedFilter: StatusFilter = .all
      
      // MARK: - Promises
      public var promisesState: LoadingState<[PromiseItem]> = .idle
      
      // MARK: - Groups
      public var currentGroup: CurrentGroup?
      public var groupMembers: [GroupMember] = []
      
      // MARK: - Presents
      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var groupDetail: GroupDetailState?
      
      /// State 초기화
      public init() {}
      
      // Computed property for backward compatibility
      public var promises: [PromiseItem] {
        promisesState.value ?? []
      }
    }
    
    // MARK: - Group Detail State
    public struct GroupDetailState: Equatable {
      public var isPresented: Bool = false
    }
    
    // MARK: - Action
    
    /// Promise Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent na system event를 나타내야 함
    public enum Action: Sendable {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)
      
      // Presentation actions
      case createPromise(PresentationAction<CreatePromise.Feature.Action>)
      case groupDetail(PresentationAction<GroupDetailAction>)
      
      // MARK: - View Actions (사용자가 직접 트리거)
      public enum View: Sendable {
        case onAppear
        case filterChanged(StatusFilter)
        case promiseAccepted(String)  // Promise ID
        case promiseRejected(String)  // Promise ID
        case openSideDrawer  // 햄버거 버튼
        case groupManageTapped  // 톱니 버튼
        case createNewPromise
        case groupDetailDismissed
      }
      
      // MARK: - Internal Actions (내부 로직/이펙트 응답)
      public enum Internal: Sendable {
        case loadPromisesResponse(Result<[PromiseItem], Error>)
        case toggleGroupNotifications
      }
      
      // MARK: - Delegate Actions (부모로 전달)
      public enum Delegate: Sendable {
        case requestOpenSideDrawer
      }
    }
    
    // MARK: - Group Detail Action
    public enum GroupDetailAction: Sendable, Equatable {
      case dismiss
      case settings
      case toggleNotifications
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
          
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // TODO: Load promises and group data
            return .none
            
          case .filterChanged(let filter):
            state.selectedFilter = filter
            return .none
            
          case .promiseAccepted(_):
            // TODO: Accept promise logic
            return .none
          case .promiseRejected(_):
            // TODO: Reject promise logic
            return .none
            
          case .openSideDrawer:
            // 사이드 드로워 열기 요청을 부모로 전달
            return .send(.delegate(.requestOpenSideDrawer))
            
          case .groupManageTapped:
            // 그룹 관리 화면 열기
            state.groupDetail = GroupDetailState(isPresented: true)
            return .none
            
          case .createNewPromise:
            state.createPromise = CreatePromise.Feature.State()
            return .none
            
          case .groupDetailDismissed:
            state.groupDetail = nil
            return .none
          }
          
          // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
            
          case .loadPromisesResponse(.success(let promises)):
            state.promisesState = .loaded(promises)
            return .none
            
          case .loadPromisesResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .toggleGroupNotifications:
            // TODO: Toggle notifications
            return .none
          }
          
          // MARK: - Presentation Actions
        case .createPromise(.presented(.delegate(.dismiss))):
          state.createPromise = nil
          return .none
          
        case .createPromise(.presented(.delegate(.promiseCreated))):
          state.createPromise = nil
          // TODO: Reload promises list
          return .none
          
        case .createPromise:
          return .none
          
        case .groupDetail(.presented(.dismiss)):
          state.groupDetail = nil
          return .none
          
        case .groupDetail(.presented(.settings)):
          // TODO: Navigate to settings
          return .none
          
        case .groupDetail(.presented(.toggleNotifications)):
          return .send(.internal(.toggleGroupNotifications))
          
        case .groupDetail:
          return .none
          
          // MARK: - Binding & Delegate
        case .binding:
          return .none
          
        case .delegate:
          // Delegate 액션은 부모에서 처리
          return .none
        }
      }
      .ifLet(\.$createPromise, action: \.createPromise) {
        CreatePromise.Feature()
      }
    }
  }
}

// MARK: - View Implementation

extension PromiseMain {
  /// Promise Feature의 Root View
  public struct RootView: View {
    @Bindable private var store: StoreOf<PromiseMain.Feature>
    
    public init(store: StoreOf<PromiseMain.Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      VStack(spacing: 0) {
        // Group Header
        if let group = store.currentGroup {
          GroupHeaderView(
            group: group,
            onMenuTap: { store.send(.view(.openSideDrawer)) },
            onManageTap: { store.send(.view(.groupManageTapped)) },
            onAddPromiseTap: { store.send(.view(.createNewPromise)) }
          )
          
          Divider()
        }
        
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
          onAccept: { promiseId in store.send(.view(.promiseAccepted(promiseId))) },
          onReject: { promiseId in store.send(.view(.promiseRejected(promiseId))) }
        )
      }
      .background(Color(.systemGray6))
      .onAppear {
        store.send(.view(.onAppear))
      }
      .fullScreenCover(
        store: store.scope(
          state: \.$createPromise,
          action: \.createPromise
        )
      ) { childStore in
        CreatePromise.RootView(store: childStore)
      }
      .sheet(isPresented: Binding(
        get: { store.groupDetail != nil },
        set: { if !$0 { store.send(.view(.groupDetailDismissed)) } }
      )) {
        if let group = store.currentGroup {
          GroupDetailView(
            group: group,
            members: store.groupMembers,
            onDismiss: { store.send(.groupDetail(.presented(.dismiss))) },
            onSettings: { store.send(.groupDetail(.presented(.settings))) },
            onToggleNotifications: { store.send(.groupDetail(.presented(.toggleNotifications))) }
          )
        }
      }
    }
  }
}

