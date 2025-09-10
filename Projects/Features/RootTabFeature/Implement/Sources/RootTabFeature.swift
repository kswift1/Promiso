// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import RootTabFeatureInterface
import Perception
import PromiseFeatureInterface
import HomeFeatureInterface
import UIKit

// Tab 타입을 RootTabFeatureInterface에서 가져옴
public typealias Tab = RootTabFeatureInterface.Tab


// MARK: - Feature Namespace

/// RootTab Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum RootTab {}

  
  // MARK: - Reducer
  
extension RootTab {
  /// RootTab Feature의 Reducer
  @Reducer
  public struct Feature {
    public init() {}
    
    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 탭
      public var selectedTab: Tab = .home
      
      /// 사이드 드로어 표시 여부
      public var showDrawer: Bool = false
      
      /// 드래그 오프셋
      public var dragOffset: CGFloat = 0
      
      /// 오버레이 투명도 (드래그 위치에 따라 동적 변경)
      public var overlayOpacity: Double = 0.0
      
      /// State 초기화
      public init() {}
    }
    
    public enum Action: Equatable {
      /// 앱이 나타날 때 호출
      case onAppear
      /// 탭이 선택되었을 때 호출
      case tabSelected(Tab)
      /// 드로어 토글
      case toggleDrawer
      /// 드로어 닫기
      case closeDrawer
      /// 드래그 변경
      case dragChanged(CGFloat)
      /// 드래그 종료
      case dragEnded
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          return .none
          
        case .tabSelected(let tab):
          state.selectedTab = tab
          return .run { _ in
            let impactFeedback = await UIImpactFeedbackGenerator(style: .light)
            await impactFeedback.impactOccurred()
          }
          
        case .toggleDrawer:
          state.showDrawer.toggle()
          state.overlayOpacity = state.showDrawer ? 0.1 : 0.0
          return .run { _ in
            let impactFeedback = await UIImpactFeedbackGenerator(style: .medium)
            await impactFeedback.impactOccurred()
          }
          
        case .closeDrawer:
          state.showDrawer = false
          state.dragOffset = 0
          state.overlayOpacity = 0.0
          return .run { _ in
            let impactFeedback = await UIImpactFeedbackGenerator(style: .light)
            await impactFeedback.impactOccurred()
          }
          
        case .dragChanged(let offset):
          state.dragOffset = offset
          // 드래그 위치에 따라 opacity 계산
          if state.showDrawer {
            // 드로어가 열려있을 때: 닫히는 방향으로 드래그하면 opacity 감소
            let progress = max(0, min(1, (256 + offset) / 256))
            state.overlayOpacity = 0.1 * progress
          } else {
            // 드로어가 닫혀있을 때: 열리는 방향으로 드래그하면 opacity 증가
            let progress = max(0, min(1, offset / 256))
            state.overlayOpacity = 0.1 * progress
          }
          return .none
          
        case .dragEnded:
          let threshold: CGFloat = 100
          var shouldProvideHaptic = false
          
          if state.showDrawer {
            // 드로어가 열려있을 때: 음수 오프셋이 임계값보다 크면 닫기
            if state.dragOffset < -threshold {
              state.showDrawer = false
              state.overlayOpacity = 0.0
              shouldProvideHaptic = true
            } else {
               state.overlayOpacity = 0.1
            }
          } else {
            // 드로어가 닫혀있을 때: 양수 오프셋이 임계값보다 크면 열기
            if state.dragOffset > threshold {
              state.showDrawer = true
               state.overlayOpacity = 0.1
              shouldProvideHaptic = true
            } else {
              state.overlayOpacity = 0.0
            }
          }
          state.dragOffset = 0
          
          if shouldProvideHaptic {
            return .run { _ in
              let impactFeedback = await UIImpactFeedbackGenerator(style: .medium)
              await impactFeedback.impactOccurred()
            }
          } else {
          return .none
          }
        }
        }
      }
    }
  }
  
// MARK: - View
  
extension RootTab {
  /// RootTab Feature의 Root View
  public struct RootView: View {
    private let store: StoreOf<RootTab.Feature>
    private let promiseEntry: PromiseEntry
    private let homeEntry: HomeEntry
    
    public init(store: StoreOf<RootTab.Feature>, promiseEntry: PromiseEntry, homeEntry: HomeEntry) {
      self.store = store
      self.promiseEntry = promiseEntry
      self.homeEntry = homeEntry
    }
    
    public var body: some View {
      WithPerceptionTracking {
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            // 메인 탭 콘텐츠
            TabViewContent(store: store, promiseEntry: promiseEntry, homeEntry: homeEntry)
              .offset(x: store.showDrawer ? 256 + store.dragOffset : store.dragOffset)
              .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: store.showDrawer)
              .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0), value: store.dragOffset)
              .gesture(
                DragGesture()
                  .onChanged { value in
                    // 드래그 방향에 따라 드로어 상태 변경
                    if !store.showDrawer && value.translation.width > 0 {
                      // 드로어가 닫혀있을 때 오른쪽으로 드래그하면 드로어 열기
                      let offset = min(value.translation.width, 256)
                      store.send(.dragChanged(offset))
                    } else if store.showDrawer && value.translation.width < 0 {
                      // 드로어가 열려있을 때 왼쪽으로 드래그하면 드로어 닫기
                      let offset = max(value.translation.width, -256)
                      store.send(.dragChanged(offset))
                    }
                  }
                  .onEnded { _ in
                    store.send(.dragEnded)
                  }
              )
            
            // 전체 화면 오버레이 (드로어가 열려있을 때만)
            if store.showDrawer || store.overlayOpacity > 0 {
              Color.black.opacity(store.overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                  store.send(.closeDrawer)
                }
                .transition(.opacity)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0), value: store.overlayOpacity)
                .allowsHitTesting(true)
                .gesture(
                  DragGesture()
                    .onChanged { value in
                      // 오버레이에서도 드래그로 닫기 가능
                      if store.showDrawer && value.translation.width < 0 {
                        let offset = max(value.translation.width, -256)
                        store.send(.dragChanged(offset))
                      }
                    }
                    .onEnded { _ in
                      store.send(.dragEnded)
                    }
                )
            }
            
            // 사이드 드로어 (오버레이 위에 표시)
            sideDrawerView
              .frame(width: 256)
              .offset(x: store.showDrawer ? store.dragOffset : -256 + store.dragOffset)
              .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: store.showDrawer)
              .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0), value: store.dragOffset)
              .gesture(
                DragGesture()
                  .onChanged { value in
                    if store.showDrawer && value.translation.width < 0 {
                      let offset = max(value.translation.width, -256)
                      store.send(.dragChanged(offset))
                    }
                  }
                  .onEnded { _ in
                    store.send(.dragEnded)
                  }
              )
          }
        }
      }
    }
  }
  
  private struct TabViewContent: View {
    let store: StoreOf<RootTab.Feature>
    let promiseEntry: PromiseEntry
    let homeEntry: HomeEntry
    
    var body: some View {
      WithPerceptionTracking {
        @Perception.Bindable var store = store
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
    }
    
    @ViewBuilder
    private func tabContentView(for tab: Tab) -> some View {
      switch tab {
      case .home:
        HomeTabView(homeEntry: homeEntry, store: store)
      case .promise:
        PromiseTabView(promiseEntry: promiseEntry, store: store)
      }
    }
  }
  
  private struct PlaceholderTabView: View {
    let tab: Tab
    
    var body: some View {
      VStack {
        Image(systemName: tab.iconName)
          .font(.largeTitle)
          .foregroundColor(.secondary)
        Text(tab.rawValue)
          .font(.title2)
          .foregroundColor(.secondary)
        Text("준비 중입니다")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground))
    }
  }
}

// MARK: - Home Tab View

/// Home 탭의 내용을 표시하는 View
/// HomeEntry를 주입받아 사용
private struct HomeTabView: View {
  let homeEntry: HomeEntry
  let store: StoreOf<RootTab.Feature>
  
  var body: some View {
    VStack(spacing: 0) {
      // 햄버거 메뉴가 있는 헤더
      HStack {
        Button(action: {
          store.send(.toggleDrawer)
        }) {
          Image(systemName: "line.3.horizontal")
            .font(.title2)
            .foregroundColor(.primary)
        }
        
        Spacer()
        
        Text("홈")
          .font(.title2)
          .fontWeight(.semibold)
        
        Spacer()
        
        // 햄버거 버튼과 균형을 맞추기 위한 투명한 버튼
        Button(action: {}) {
          Image(systemName: "line.3.horizontal")
            .font(.title2)
            .foregroundColor(.clear)
        }
        .disabled(true)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 8)
      
      // Home Feature 콘텐츠
      homeEntry.makeView(.init())
    }
  }
}

// MARK: - Promise Tab View

/// Promise 탭의 내용을 표시하는 View
/// PromiseEntry를 주입받아 사용
private struct PromiseTabView: View {
  let promiseEntry: PromiseEntry
  let store: StoreOf<RootTab.Feature>
  
  var body: some View {
    VStack(spacing: 0) {
      // 햄버거 메뉴가 있는 헤더
      HStack {
        Button(action: {
          store.send(.toggleDrawer)
        }) {
          Image(systemName: "line.3.horizontal")
            .font(.title2)
            .foregroundColor(.primary)
        }
        
        Spacer()
        
        Text("약속")
          .font(.title2)
          .fontWeight(.semibold)
        
        Spacer()
        
        // 햄버거 버튼과 균형을 맞추기 위한 투명한 버튼
        Button(action: {}) {
          Image(systemName: "line.3.horizontal")
            .font(.title2)
            .foregroundColor(.clear)
        }
        .disabled(true)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 8)
      
      // Promise Feature 콘텐츠
      promiseEntry.makeView(.init())
    }
  }
}

// MARK: - Side Drawer View

extension RootTab.RootView {
  private var sideDrawerView: some View {
    WithPerceptionTracking {
      VStack(alignment: .leading, spacing: 0) {
        // 드로어 헤더
        drawerHeader
        
        // 그룹 목록
        drawerGroupsList
        
        // 설정 메뉴
        drawerSettingsMenu
        
        Spacer()
      }
           .frame(width: 256, alignment: .leading)
      .background(Color.white)
      .shadow(color: .black.opacity(0.1), radius: 5, x: 2, y: 0)
    }
  }
  
  private var drawerHeader: some View {
    WithPerceptionTracking {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Promiso")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(.primary)
            
            Text("약속을 지키는 습관")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          Spacer()
          
          Button(action: {
            store.send(.closeDrawer)
          }) {
            Image(systemName: "xmark")
              .foregroundColor(.secondary)
              .font(.title3)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        
        Divider()
      }
    }
  }
  
  private var drawerGroupsList: some View {
    WithPerceptionTracking {
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
            store.send(.closeDrawer)
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
      }
    }
  }
  
  private var drawerSettingsMenu: some View {
    WithPerceptionTracking {
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
            store.send(.closeDrawer)
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
