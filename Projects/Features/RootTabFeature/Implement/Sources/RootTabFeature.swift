// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import RootTabFeatureInterface

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
      // MARK: UI State
      /// Feature가 현재 async operation을 수행 중인지 추적
      public var isLoading: Bool = false
      
      /// 사용자 대상 error message 표시를 위한 Error state
      public var error: RootTabError?
      
      // Feature별 state 프로퍼티를 여기에 추가
      // 예시: public var items: IdentifiedArrayOf<RootTabItem> = []
      // 예시: public var selectedItem: RootTabItem?
      
      /// State를 위한 기본 initializer
      /// 모든 state 프로퍼티에 대해 합리적인 기본값을 제공
      
      public init(
        isLoading: Bool = false,
        error: RootTabError? = nil
      ) {
        self.isLoading = isLoading
        self.error = error
      }
    }
    
    // MARK: - Action
    
    /// RootTab Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      /// view가 data를 새로고침해야 할 때 트리거
      case refresh
      
      // MARK: User Actions
      /// 사용자 상호작용 예시 - Feature별 action으로 교체
      case didTapAction
      
      // MARK: Internal Actions
      /// async operation 완료 처리를 위한 Internal action
      case loadDataResponse(Result<Void, RootTabError>)
      
      /// error state 해제를 위한 Action
      case dismissError
      
      // Feature별 action을 여기에 추가
      // 예시: case itemSelected(RootTabItem)
      // 예시: case deleteItem(RootTabItem.ID)
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // view가 나타날 때 Feature 초기화
          state.isLoading = true
          state.error = nil
          
          // async data loading 시뮬레이션
          return .run { send in
            await send(.loadDataResponse(.success(())))
          }
          
        case .refresh:
          // pull-to-refresh 또는 명시적 refresh 요청 처리
          state.isLoading = true
          state.error = nil
          
          return .run { send in
            await send(.loadDataResponse(.success(())))
          }
          
        case .didTapAction:
          // 사용자 상호작용 처리
          // 여기에 business logic을 추가
          return .none
          
        case let .loadDataResponse(.success):
          // 성공적인 data loading 처리
          state.isLoading = false
          return .none
          
        case let .loadDataResponse(.failure(error)):
          // data loading 실패 처리
          state.isLoading = false
          state.error = error
          return .none
          
        case .dismissError:
          // error state 정리
          state.error = nil
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
    @Bindable private var store: StoreOf<Feature>
    
    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      NavigationStack {
        contentView
          .navigationTitle("RootTab")
          .onAppear {
            store.send(.onAppear)
          }
          .refreshable {
            store.send(.refresh)
          }
          .alert(
            "Error",
            isPresented: .constant(store.error != nil),
            presenting: store.error
          ) { error in
            Button("OK") {
              store.send(.dismissError)
            }
          } message: { error in
            Text(error.localizedDescription)
          }
      }
    }
    
    // MARK: - Content View
    
    /// Feature의 interface를 보여주는 Main content view
    @ViewBuilder
    private var contentView: some View {
      if store.isLoading {
        loadingView
      } else {
        mainContentView
      }
    }
    
    /// Loading state view
    @ViewBuilder
    private var loadingView: some View {
      ProgressView("Loading...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// data가 로드되었을 때의 Main content
    @ViewBuilder
    private var mainContentView: some View {
      VStack(spacing: 24) {
        // Feature 아이콘 또는 헤더
        Image(systemName: "star.circle.fill")
          .font(.system(size: 60))
          .foregroundColor(.accentColor)
        
        // Feature 제목
        Text("RootTab Feature")
          .font(.title2)
          .fontWeight(.semibold)
        
        // Feature 설명
        Text("RootTab Feature implementation입니다.")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        
        // Action 버튼
        Button("Tap Action") {
          store.send(.didTapAction)
        }
        .buttonStyle(.borderedProminent)
        
        Spacer()
      }
      .padding()
    }
  }
}

// MARK: - Error Types

/// RootTab Feature에 특화된 Error type
/// 사용자 친화적인 메시지와 함께 구조화된 error handling을 제공
public enum RootTabError: Error, Equatable, LocalizedError {
  /// Network 연결 또는 server error
  case networkError
  
  /// Data parsing 또는 validation error
  case dataError
  
  /// 커스텀 메시지를 가진 Generic error
  case custom(String)
  
  /// 사용자 친화적인 error 설명
  public var errorDescription: String? {
    switch self {
    case .networkError:
      return "네트워크 연결에 실패했습니다. 다시 시도해 주세요."
    case .dataError:
      return "데이터를 처리할 수 없습니다. 다시 시도해 주세요."
    case .custom(let message):
      return message
    }
  }
}