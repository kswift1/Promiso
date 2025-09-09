// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import HomeFeatureInterface

// MARK: - Feature Namespace

/// Home Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum Home {}

// MARK: - Core Feature Implementation

extension Home {
  
  // MARK: - Reducer
  
  /// Home Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  /// 
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    /// Reducer를 위한 기본 initializer
    /// Feature가 성장함에 따라 dependency나 configuration을 여기에 추가
    public init() {}
    
    // MARK: - State
    
    /// Home Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    /// 
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      // Feature별 state 프로퍼티를 여기에 추가
      // 예시: public var items: IdentifiedArrayOf<HomeItem> = []
      // 예시: public var selectedItem: HomeItem?
      
      /// State를 위한 기본 initializer
      public init() {}
    }
    
    // MARK: - Action
    
    /// Home Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      // Feature별 action을 여기에 추가
      // 예시: case itemSelected(HomeItem)
      // 예시: case deleteItem(HomeItem.ID)
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // view가 나타날 때 Feature 초기화
          return .none
        }
      }
    }
  }
  
  // MARK: - Root View
  
  /// Home Feature를 위한 Main view implementation
  /// 적절한 accessibility와 state handling을 통해 SwiftUI best practice를 따름
  public struct RootView: View {
    /// Feature의 state와 action dispatch 기능을 포함하는 Store
    private var store: StoreOf<Feature>
    
    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      VStack {
        Text("Home Feature")
          .font(.title2)
          .fontWeight(.semibold)
        
        Text("Home Feature implementation입니다.")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

// MARK: - Error Types
// Feature별 Error type이 필요한 경우 여기에 추가
// 예시:
// public enum HomeError: Error, Equatable, LocalizedError {
//   case networkError
//   case dataError
//   case custom(String)
// }