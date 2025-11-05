// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import CoreInfrastructure
import Shared

public enum Tab: String, CaseIterable {
  case home = "홈"
  case promise = "약속"
  
  var iconName: String {
    switch self {
    case .home: return "house.fill"
    case .promise: return "calendar.badge.plus"
    }
  }
}

// MARK: - Feature Namespace

/// RootTab Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum RootTab {}


// MARK: - Reducer

extension RootTab {
  /// RootTab Feature의 Reducer
  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback
    
    public init() {}
    
    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 탭
      var selectedTab: Tab = .home
      
      /// 사이드 드로어 상태
      var sideDrawer: SideDrawerFeature.State = SideDrawerFeature.State(maxDragOffset: AppConstants.UI.SideDrawer.width)
      
      /// Promise Main State
      var home: Home.Feature.State = Home.Feature.State()
      
      /// Promise Main State
      var promiseMain: PromiseMain.Feature.State = PromiseMain.Feature.State.preview
      
      /// Create Group State
      @Presents var createGroup: CreateGroup.Feature.State?
      
      public init () {}
    }
    
    public enum Action {
      /// 앱이 나타날 때 호출
      case onAppear
      /// 탭이 선택되었을 때 호출
      case tabSelected(Tab)
      /// 사이드 드로어 관련 액션
      case sideDrawer(SideDrawerFeature.Action)
      /// Home Main 액션
      case home(Home.Feature.Action)
      /// Promise Main 액션
      case promiseMain(PromiseMain.Feature.Action)
      /// Create Group 액션
      case createGroup(PresentationAction<CreateGroup.Feature.Action>)
      /// 그룹 추가 버튼 탭
      case addGroupTapped
    }
    
    public var body: some ReducerOf<Self> {
      Scope(state: \.promiseMain, action: \.promiseMain) {
        PromiseMain.Feature()
      }
      
      Scope(state: \.home, action: \.home) {
        Home.Feature()
      }
      
      Reduce { state, action in
        switch action {
        case .onAppear:
          return .none
          
        case .tabSelected(let tab):
          state.selectedTab = tab
          return .run { _ in
            await hapticFeedback.buttonTap()
          }
          
        case .sideDrawer(let sideDrawerAction):
          return SideDrawerFeature()
            .reduce(into: &state.sideDrawer, action: sideDrawerAction)
            .map(Action.sideDrawer)
          
        case .home(.delegate(.openSideDrawer)):
          return .send(.sideDrawer(.toggle))
          
        case .home:
          return .none
          
        case .promiseMain(.delegate(.requestOpenSideDrawer)):
          // PromiseMain에서 사이드 드로워 열기 요청
          return .send(.sideDrawer(.toggle))
          
        case .promiseMain:
          return .none
          
        case .addGroupTapped:
          state.createGroup = CreateGroup.Feature.State()
          return .send(.sideDrawer(.close))
          
        case .createGroup(.presented(.delegate(.dismiss))):
          state.createGroup = nil
          return .none
          
        case .createGroup(.presented(.delegate(.groupCreated))):
          state.createGroup = nil
          // TODO: Reload groups list
          return .none
          
        case .createGroup:
          return .none
        }
      }
      .ifLet(\.$createGroup, action: \.createGroup) {
        CreateGroup.Feature()
      }
    }
  }
}

// MARK: - View

extension RootTab {
  /// RootTab Feature의 Root View
  public struct RootView: View {
    private let store: StoreOf<RootTab.Feature>
    
    public init(store: StoreOf<RootTab.Feature>) {
      self.store = store
    }
    
    public var body: some View {
      ZStack(alignment: .leading) {
        // 메인 탭 콘텐츠
        TabViewContent(store: store)
          .offset(x: store.sideDrawer.showDrawer ? AppConstants.UI.SideDrawer.width + store.sideDrawer.dragOffset : store.sideDrawer.dragOffset)
          .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: store.sideDrawer.showDrawer)
          .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0), value: store.sideDrawer.dragOffset)
        
        // 전체 화면 오버레이 (드로어가 열려있을 때만)
        if store.sideDrawer.showDrawer || store.sideDrawer.overlayOpacity > 0 {
          Color.black.opacity(store.sideDrawer.overlayOpacity)
            .ignoresSafeArea()
            .onTapGesture {
              store.send(.sideDrawer(.close))
            }
            .transition(.opacity)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0), value: store.sideDrawer.overlayOpacity)
            .allowsHitTesting(true)
        }
        
        // 사이드 드로어 (오버레이 위에 표시)
        sideDrawerView
          .frame(width: AppConstants.UI.SideDrawer.width)
          .offset(x: store.sideDrawer.showDrawer ? store.sideDrawer.dragOffset : AppConstants.UI.SideDrawer.minDragOffset + store.sideDrawer.dragOffset)
          .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: store.sideDrawer.showDrawer)
          .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0), value: store.sideDrawer.dragOffset)
      }
      .simultaneousGesture(
        DragGesture(minimumDistance: 15)
          .onChanged { value in
            
            let dragDistance = value.translation.width
            let horizontalMovement = abs(dragDistance)
            let verticalMovement = abs(value.translation.height)
            
            // 수평 드래그가 수직보다 명확히 클 때만 처리 (스크롤과 구분)
            guard horizontalMovement > verticalMovement * 1.5 else { return }
            
            let isDraggingToOpen = !store.sideDrawer.showDrawer && dragDistance > 0
            let isDraggingToClose = store.sideDrawer.showDrawer && dragDistance < 0
            
            guard isDraggingToOpen || isDraggingToClose else { return }
            
            // Offset 계산
            let clampedOffset: CGFloat
            if isDraggingToOpen {
              clampedOffset = min(dragDistance, AppConstants.UI.SideDrawer.maxDragOffset)
            } else {
              clampedOffset = max(dragDistance, AppConstants.UI.SideDrawer.minDragOffset)
            }
            
            store.send(.sideDrawer(.dragChanged(clampedOffset)))
          }
          .onEnded { _ in
            store.send(.sideDrawer(.dragEnded))
          }
      )
      .fullScreenCover(
        store: store.scope(
          state: \.$createGroup,
          action: \.createGroup
        )
      ) { childStore in
        CreateGroup.RootView(store: childStore)
      }
    }
  }
  
  private struct TabViewContent: View {
    @Bindable var store: StoreOf<RootTab.Feature>
    
    var body: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        ForEach(Tab.allCases, id: \.self) { tab in
          tabContentView(for: tab)
            .tabItem {
              Label(tab.rawValue, systemImage: tab.iconName)
            }
            .tag(tab)
        }
      }
      .onAppear {
        store.send(.onAppear)
      }
    }
    
    @ViewBuilder
    private func tabContentView(for tab: Tab) -> some View {
      switch tab {
      case .home:
        NavigationStack {
          Home.RootView(
            store: store.scope(
              state: \.home,
              action: \.home
            )
          )
        }
        
      case .promise:
        NavigationStack {
          PromiseMain.RootView(
            store: store.scope(
              state: \.promiseMain,
              action: \.promiseMain
            )
          )
        }
      }
    }
  }
}


// MARK: - Side Drawer View

extension RootTab.RootView {
  private var sideDrawerView: some View {
//    SideDrawerEmptyStatePreview()
    VStack(alignment: .leading, spacing: 0) {
      // 드로어 헤더
      drawerHeader
      
      // 그룹 목록
      drawerGroupsList
      
      // 설정 메뉴
      drawerSettingsMenu
      
      Spacer()
    }
    .frame(width: AppConstants.UI.SideDrawer.width, alignment: .leading)
    .background(Color.white)
    .shadow(color: .black.opacity(0.1), radius: 5, x: 2, y: 0)
  }
  
  private var drawerHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Promiso")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(.primary)
        
        Text("약속을 지키는 습관")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 16)
      
      Divider()
    }
  }
  
  private var drawerGroupsList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("그룹")
        .font(.headline)
        .fontWeight(.semibold)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
      
      ForEach(sampleGroups) { group in
        Button(action: {
          // 그룹 선택 로직
          store.send(.sideDrawer(.close))
        }) {
          HStack {
            Image(systemName: "person.2.fill")
              .foregroundColor(group.isActive ? .blue : .secondary)
              .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
              Text(group.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
              
              Text("\(group.memberCount)명")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if group.isActive {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(group.isActive ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
      }
      
      // 추가하기 버튼
      Button(action: {
        store.send(.addGroupTapped)
      }) {
        HStack {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(.blue)
            .font(.title3)
          
          Text("추가하기")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
          
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }
  
  private var drawerSettingsMenu: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("설정")
        .font(.headline)
        .fontWeight(.semibold)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
      
      ForEach(sampleSettings) { setting in
        Button(action: {
          // 설정 액션
          store.send(.sideDrawer(.close))
        }) {
          HStack {
            Image(systemName: setting.iconName)
              .foregroundColor(.secondary)
              .font(.title3)
              .frame(width: 24)
            
            Text(setting.title)
              .font(.subheadline)
              .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
              .font(.caption)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
  }
}

// MARK: - Sample Data

private struct GroupItem: Equatable, Identifiable {
  let id = UUID()
  let name: String
  let memberCount: Int
  let isActive: Bool
}

private struct DrawerSettingItem: Equatable, Identifiable {
  let id = UUID()
  let title: String
  let iconName: String
}

private let sampleGroups: [GroupItem] = [
  GroupItem(name: "가족", memberCount: 4, isActive: true),
  GroupItem(name: "친구들", memberCount: 8, isActive: false),
  GroupItem(name: "동료", memberCount: 12, isActive: false)
]

private let sampleSettings: [DrawerSettingItem] = [
  DrawerSettingItem(title: "프로필", iconName: "person.circle"),
  DrawerSettingItem(title: "알림 설정", iconName: "bell"),
  DrawerSettingItem(title: "도움말", iconName: "questionmark.circle"),
  DrawerSettingItem(title: "설정", iconName: "gearshape")
]
