// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import RootTabFeatureInterface

// Tab 타입을 RootTabFeatureInterface에서 가져옴
public typealias Tab = RootTabFeatureInterface.Tab

// MARK: - Feature Namespace

/// RootTab Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum RootTab {}

// MARK: - Core Feature Implementation

extension RootTab {
  
  // MARK: - Reducer
  
  /// RootTab Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    /// Reducer를 위한 기본 initializer
    /// Feature가 성장함에 따라 dependency나 configuration을 여기에 추가
    public init() {}
    
    // MARK: - State
    
    /// RootTab Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    ///
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 탭
      public var selectedTab: Tab = .home
      
      /// State를 위한 기본 initializer
      public init(selectedTab: Tab = .home) {
        self.selectedTab = selectedTab
      }
    }
    
    // MARK: - Action
    
    /// RootTab Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      // MARK: Tab Actions
      /// 탭이 선택되었을 때 트리거
      case tabSelected(Tab)
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // 탭바가 처음 나타날 때 초기화
          return .none
          
        case let .tabSelected(tab):
          // 탭이 선택되었을 때 상태 업데이트
          state.selectedTab = tab
          return .none
        }
      }
    }
  }
  
  // MARK: - Root View
  
  /// RootTab Feature를 위한 Main view implementation
  /// 적절한 accessibility와 state handling을 통해 SwiftUI best practice를 따름
  public struct RootView: View {
    /// Feature의 state와 action dispatch 기능을 포함하는 Store
    @ComposableArchitecture.Bindable private var store: StoreOf<RootTab.Feature>
    
    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        ForEach(Tab.allCases.sorted(by: { $0.order < $1.order }), id: \.self) { tab in
          tabContentView(for: tab)
            .tabItem {
              Image(systemName: tab.iconName)
              Text(tab.rawValue)
            }
            .tag(tab)
        }
      }
      .onAppear {
        store.send(.onAppear)
      }
    }
    
    // MARK: - Tab Content Views
    
    /// 각 탭에 해당하는 콘텐츠 뷰를 생성
    /// 현재는 플레이스홀더로 구현, 추후 실제 Feature들로 교체 예정
    @ViewBuilder
    private func tabContentView(for tab: Tab) -> some View {
      NavigationStack {
        VStack(spacing: 24) {
          // 탭 아이콘
          Image(systemName: tab.iconName)
            .font(.system(size: 60))
            .foregroundColor(.accentColor)
          
          // 탭 제목
          Text(tab.rawValue)
            .font(.title2)
            .fontWeight(.semibold)
          
          // 탭 설명
          Text("\(tab.rawValue) 기능이 구현될 예정입니다.")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          
          Spacer()
        }
        .padding()
        .navigationTitle(tab.rawValue)
      }
    }
  }
}

// MARK: - Error Types
// Feature별 Error type이 필요한 경우 여기에 추가
// 예시:
// public enum RootTabError: Error, Equatable, LocalizedError {
//   case networkError
//   case dataError
//   case custom(String)
// }
