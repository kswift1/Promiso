// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import RootTabFeatureInterface
import Perception
import ScheduleFeatureInterface
import HomeFeatureInterface

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
      
      /// State 초기화
      public init() {}
    }
    
    public enum Action: Equatable {
      /// 앱이 나타날 때 호출
      case onAppear
      /// 탭이 선택되었을 때 호출
      case tabSelected(Tab)
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          return .none
          
        case .tabSelected(let tab):
          state.selectedTab = tab
          return .none
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
    private let scheduleEntry: ScheduleEntry
    private let homeEntry: HomeEntry
    
    public init(store: StoreOf<RootTab.Feature>, scheduleEntry: ScheduleEntry, homeEntry: HomeEntry) {
      self.store = store
      self.scheduleEntry = scheduleEntry
      self.homeEntry = homeEntry
    }
    
    public var body: some View {
      WithPerceptionTracking {
        TabViewContent(store: store, scheduleEntry: scheduleEntry, homeEntry: homeEntry)
      }
    }
  }
  
  private struct TabViewContent: View {
    let store: StoreOf<RootTab.Feature>
    let scheduleEntry: ScheduleEntry
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
        HomeTabView(homeEntry: homeEntry)
      case .schedule:
        ScheduleTabView(scheduleEntry: scheduleEntry)
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
  
  var body: some View {
    homeEntry.makeView(.init())
  }
}

// MARK: - Schedule Tab View

/// Schedule 탭의 내용을 표시하는 View
/// ScheduleEntry를 주입받아 사용
private struct ScheduleTabView: View {
  let scheduleEntry: ScheduleEntry
  
  var body: some View {
    scheduleEntry.makeView(.init())
  }
}
