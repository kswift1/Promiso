// MARK: - Feature Namespace
import Shared

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
      //      VStack(spacing: 0) {
      //        // Status Filter
      //        StatusFilterView(
      //          selectedFilter: Binding(
      //            get: { store.selectedFilter },
      //            set: { store.send(.view(.filterChanged($0))) }
      //          )
      //        )
      //        .padding(.horizontal, 16)
      //        .padding(.top, 12)
      //
      //        // Promise Timeline
      //        PromiseTimelineView(
      //          promisesState: store.promisesState,
      //          selectedFilter: store.selectedFilter,
      //          onAccept: { promiseId in store.send(.view(.promiseAccepted(promiseId))) },
      //          onReject: { promiseId in store.send(.view(.promiseRejected(promiseId))) }
      //        )
      //      }
      GroupDetailEmptyView()
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
      //        .navigationSubtitle("1개 진행중 / 0개 완료 / 0개 만료 1개 진행중 / 0개 완료 / 0개 만료 1개 진행중 / 0개 완료 / 0개 만료")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            ToolbarButton(
              imageName: "line.3.horizontal",
              action: { store.send(.view(.openSideDrawer)) }
            )
          }
          
          if let groupName = store.currentGroup?.name {
            ToolbarItem(placement: .principal) {
              Text(groupName)
            }
          }
          
          ToolbarTitleMenu {
            Button("one") {
              
            }
            
            Button("tow") {
              
            }
            
            Button("three") {
              
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
        }
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

import SwiftUI

// 그룹 상세 화면 - 그룹이 없을 때
struct GroupDetailEmptyView: View {
  @State private var showCreateGroup = false
  @State private var showJoinGroup = false
  @State private var showSideDrawer = false
  
  var body: some View {
    VStack(spacing: 0) {
      // Empty State Content
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
              if #available(iOS 26.0, *) {
                Button(action: { showCreateGroup = true }) {
                  HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                      .font(.title3)
                    Text("그룹 만들기")
                      .font(.headline)
                  }
                  .frame(maxWidth: .infinity)
                  .frame(height: 52)
                  //                  .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                //                .buttonStyle(.glass)
              } else {
                Button(action: { showCreateGroup = true }) {
                  HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                      .font(.title3)
                    Text("그룹 만들기")
                      .font(.headline)
                  }
                  .frame(maxWidth: .infinity)
                  .frame(height: 52)
                  .background(Color.blue)
                  .foregroundStyle(.white)
                  .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
              }
              
              Button(action: { showJoinGroup = true }) {
                HStack(spacing: 8) {
                  Image(systemName: "link.circle.fill")
                    .font(.title3)
                  Text("초대 코드로 참여하기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
              }
            }
            .padding(.horizontal, 40)
          }
          
          Spacer()
            .frame(height: 80)
        }
      }
    }
    .sheet(isPresented: $showSideDrawer) {
      //        SideDrawerEmptyView()
    }
    .sheet(isPresented: $showCreateGroup) {
      CreateGroupSheetPlaceholder()
    }
    .sheet(isPresented: $showJoinGroup) {
      JoinGroupSheetPlaceholder()
    }
    
  }
}

struct FilterChipDisabled: View {
  let title: String
  var icon: String? = nil
  
  var body: some View {
    HStack(spacing: 4) {
      if let icon {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(title)
        .font(.subheadline)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .foregroundStyle(.secondary)
    .background(Color(.systemBackground))
    .clipShape(Capsule())
    .opacity(0.5)
  }
}

// 약속 탭 - 그룹이 없을 때
struct PromisesTabEmptyView: View {
  @State private var showCreateGroup = false
  @State private var showJoinGroup = false
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemGroupedBackground)
          .ignoresSafeArea()
        
        VStack(spacing: 32) {
          Spacer()
          
          VStack(spacing: 24) {
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
              
              Image(systemName: "calendar.badge.exclamationmark")
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
              Text("약속을 확인할 그룹이 없어요")
                .font(.title3.bold())
              
              Text("먼저 그룹을 만들거나\n초대를 받아보세요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            
            // Action Buttons
            VStack(spacing: 12) {
              Button(action: { showCreateGroup = true }) {
                HStack(spacing: 8) {
                  Image(systemName: "plus.circle.fill")
                    .font(.title3)
                  Text("그룹 만들기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
              }
              
              Button(action: { showJoinGroup = true }) {
                HStack(spacing: 8) {
                  Image(systemName: "link.circle.fill")
                    .font(.title3)
                  Text("초대 코드로 참여하기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
              }
            }
            .padding(.horizontal, 40)
          }
          
          Spacer()
          Spacer()
        }
      }
      .sheet(isPresented: $showCreateGroup) {
        CreateGroupSheetPlaceholder()
      }
      .sheet(isPresented: $showJoinGroup) {
        JoinGroupSheetPlaceholder()
      }
    }
  }
}

struct CreateGroupSheetPlaceholder: View {
  var body: some View {
    NavigationView {
      ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("그룹 만들기 화면")
      }
      .navigationTitle("새 그룹")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct JoinGroupSheetPlaceholder: View {
  var body: some View {
    NavigationView {
      ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("초대 코드 입력 화면")
      }
      .navigationTitle("그룹 참여")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
