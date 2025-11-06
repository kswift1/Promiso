// 2025.11.05
// - 필터 적용시 애니메이션 (Like DiffableDatasource)
// - EmptyView 스켈레톤 맞추기?
// - 약속 만들기 가능하면 가져온 그룹 데이터 활용하기?
// - 반대 속성 버튼 동시 탭 막기 (수락 / 거절), adaptiveButton disabled 대응 (26 미만 버전)

// MARK: - Feature Namespace
import SwiftUI

import Domain
import Shared
/// Promise Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum PromiseMain {}

// MARK: - Core Feature Implementation

extension PromiseMain {
  
  private enum CancelID {
    case respond
  }
  
  enum RespondingState: Equatable {
    case idle
    case accepting
    case rejecting
  }
  
  // MARK: - Reducer
  
  /// Promise Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient
    
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
      var isInitialized: Bool = false
      let currentUser: UserModel
      
      //  Status Filter
      var selectedFilter: StatusFilter = .all
      
      //  Promises
      var promisesState: LoadingState<[PromiseItem]> = .idle
      var proposalResponding: RespondingState = .idle
      
      // Groups
      var allGroups: [GroupModel]?
      var currentGroup: GroupModel?
      
      // Presents
      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var groupDetail: GroupDetailState?
      
      
      public init(currentUser: UserModel) {
        self.currentUser = currentUser
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
        case groupChanged(GroupModel)
        case filterChanged(StatusFilter)
        case proposalAccepted(String)  // Promise ID
        case proposalRejected(String)  // Promise ID
        case openSideDrawer  // 햄버거 버튼
        case groupManageTapped  // 톱니 버튼
        case createNewPromise
        case groupDetailDismissed
        case createGroup
        case joinGroup
      }
      
      // MARK: - Internal Actions (내부 로직/이펙트 응답)
      public enum Internal: Sendable {
        /// Groups 불러오기
        case fetchGroupList
        case groupListResponse(Result<[GroupModel], Error>)
        
        case setDefaultGroup(groups: [GroupModel])
        
        case fetchPromises(groupId: String)
        case loadPromisesResponse(Result<[PromiseItem], Error>)
        case proposalRespondDone
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
            guard !state.isInitialized else { return .none }
            state.isInitialized = true
            return .send(.internal(.fetchGroupList))
            
          case .groupChanged(let group):
            guard group != state.currentGroup else { return .none }
            state.currentGroup = group
            state.promisesState = .loading
            state.selectedFilter = .all
            guard let groupId = state.currentGroup?.id else { return .none }
            return .send(.internal(.fetchPromises(groupId: groupId)))
            
          case .filterChanged(let filter):
            state.selectedFilter = filter
            return .none
            
          case .proposalAccepted(_):
            guard state.proposalResponding == .idle else { return .none }
            state.proposalResponding = .accepting
            return .run { send in
              // FIXME:
              try await Task.sleep(for: .seconds(1))
              print("Accepted")
              
//              try await promiseClient.accept(id)
              await send(.internal(.proposalRespondDone))
            }
            .cancellable(id: CancelID.respond, cancelInFlight: true)

          case .proposalRejected(_):
            guard state.proposalResponding == .idle else { return .none }
            state.proposalResponding = .rejecting
            return .run { send in
              // FIXME:
              try await Task.sleep(for: .seconds(5.3))
              print("Rejected")
//              try await promiseClient.reject(id)
              await send(.internal(.proposalRespondDone))
            }
            .cancellable(id: CancelID.respond, cancelInFlight: true)
            
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
            
          case .createGroup:
            // FIXME:
            return .none
            
          case .joinGroup:
            // FIXME:
            return .none
          }
          
          // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .fetchGroupList:
            state.promisesState = .loading
            return .run { [groupClient] send in
              do {
                let groups = try await groupClient.fetchGroups()
                await send(.internal(.groupListResponse(.success(groups))))
              } catch {
                await send(.internal(.groupListResponse(.failure(error))))
              }
            }
            
          case .groupListResponse(.success(let groups)):
            state.allGroups = groups
            return .send(.internal(.setDefaultGroup(groups: groups)))
            
          case .groupListResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .setDefaultGroup(let groups):
            
            // 1. 유저의 pinnedGroupId 확인
            let pinnedId = state.currentUser.pinnedGroupId
            
            // 2. 매칭되는 그룹 찾기
            if let pinnedGroup = groups.first(where: { $0.id == pinnedId }) {
              state.currentGroup = pinnedGroup
            } else if let firstGroup = groups.first {
              state.currentGroup = firstGroup
            } else {
              // 그룹이 없음 -> 빈 상태
              state.currentGroup = nil
              state.promisesState = .loaded([])
            }
            
            // 3. 선택된 그룹의 약속 로드
            if let currentGroupId = state.currentGroup?.id {
              return .send(.internal(.fetchPromises(groupId: currentGroupId)))
            } else {
              return .none
            }
            
          case .fetchPromises(groupId: let groupId):
            return .run { [groupId] send in
              do {
                let promises = try await promiseClient.getActivePromises(groupId: groupId, limit: 20)
                await send(.internal(.loadPromisesResponse(.success(promises))))
              } catch {
                await send(.internal(.loadPromisesResponse(.failure(error))))
              }
            }
            
          case .loadPromisesResponse(.success(let promises)):
            state.promisesState = .loaded(promises)
            return .none
            
          case .loadPromisesResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none
            
          case .proposalRespondDone:
            state.proposalResponding = .idle
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
      Group {
        if store.shouldShowEmptyGroupView {
          groupDetailEmptyView
        } else {
          groupDetailView
        }
      }
      .background(Color(.systemGroupedBackground))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
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
          // FIXME: 
//          GroupDetailView(
//            group: group,
//            onDismiss: { store.send(.groupDetail(.presented(.dismiss))) },
//            onSettings: { store.send(.groupDetail(.presented(.settings))) },
//            onToggleNotifications: { store.send(.groupDetail(.presented(.toggleNotifications))) }
//          )
        }
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
          acceptLoading: store.proposalIsAccepting,
          onReject: { promiseId in store.send(.view(.proposalRejected(promiseId))) },
          rejectLoading: store.proposalIsRejecting
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
              Button {
                store.send(.view(.createGroup))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "plus.circle.fill")
                    .font(.title3)
                  Text("그룹 만들기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
              }
              .adaptivePrimaryButton()

              Button {
                store.send(.view(.joinGroup))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "link.circle.fill")
                    .font(.title3)
                  Text("초대 코드로 참여하기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.blue)
              }
              .adaptiveSecondaryButton()
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
      if let availableGroups = store.availableGroups,
         let currentGroup = store.currentGroup {
        ToolbarItem(placement: .principal) {
          Text(currentGroup.title)
        }
        
        if availableGroups.isNotEmpty {
          ToolbarTitleMenu {
            ForEach(availableGroups, id: \.id) { group in
              Button(group.title) {
                store.send(.view(.groupChanged(group)))
              }
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
          Text(" ")
        }
      }
    }
  }
}

private extension PromiseMain.Feature.State {
  
  /// 현재 그룹을 제외한 다른 그룹들
  var availableGroups: [GroupModel]? {
    guard let currentId = currentGroup?.id else {
      return allGroups
    }
    return allGroups?.filter { $0.id != currentId }
  }
  
  /// 속한 그룹이 없는 경우
  private var hasNoGroups: Bool {
    allGroups?.isEmpty == true && currentGroup == nil
  }
  
  /// 활성화된 그룹이 없는 경우
  var shouldShowEmptyGroupView: Bool {
    !promisesState.isLoading && hasNoGroups
  }
  
  /// 제안 수락 로딩중
  var proposalIsAccepting: Bool {
    proposalResponding == .accepting
  }
  
  /// 제안 수락 로딩중
  var proposalIsRejecting: Bool {
    proposalResponding == .rejecting
  }
}
