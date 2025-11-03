// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture

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
      
      // MARK: - Today's Confirmed Promises
      public var todaysPromises: [PromiseItem] = [
        PromiseItem(
          id: "1",
          title: "영화 관람",
          emoji: "🍿",
          time: "오후 7:00",
          location: "CGV 강남",
          with: "지민과 나",
          status: .today,
          liveActivityStatus: .canStart
        ),
        PromiseItem(
          id: "2",
          title: "팀 회식",
          emoji: "🍺",
          time: "오후 9:00",
          location: "강남역 근처",
          with: "회사 동료들",
          status: .today,
          liveActivityStatus: .scheduled
        )
      ]
      
      // MARK: - Pending Responses
      public var pendingResponses: [PendingResponse] = [
        PendingResponse(
          id: "1",
          title: "주말 브런치",
          emoji: "⚠️",
          from: "지민",
          group: "지민과 나",
          daysLeft: 1
        ),
        PendingResponse(
          id: "2",
          title: "월례 회의",
          emoji: "📅",
          from: "철수",
          group: "회사 동료들",
          daysLeft: 3
        )
      ]
      
      public var upcomingPromises: [PromiseItem] = [
        
      ]
      
      // MARK: - Weekly Summary
      public var weeklyPromiseCount: Int = 7
      public var pendingResponseCount: Int = 3
      
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
      
      // MARK: Promise Actions
      case startLiveActivity(String) // Promise ID
      case viewWeeklyPromises
      case createNewProposal
      
      // MARK: Response Actions
      case viewPendingResponses
      case respondToProposal(String, Bool) // ID, Accept/Reject
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
          
        case .startLiveActivity(let promiseId):
          // Live Activity 시작 로직
          return .none
          
        case .viewWeeklyPromises:
          // 주간 약속 보기로 이동
          return .none
          
        case .createNewProposal:
          // 새 제안 만들기
          return .none
          
        case .viewPendingResponses:
          // 대기 중인 응답 보기로 이동
          return .none
          
        case .respondToProposal(let id, let accept):
          // 제안에 응답
          state.pendingResponses.removeAll { $0.id == id }
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
      ScrollView {
        LazyVStack(spacing: 24) {
//            // 헤더
//            HomeHeader(badgeCount: 3)
          
          // 오늘 확정된 약속
          TodayPromiseSection(store: store)
          
          // 다가오는 약속
          UpcomingPromiseSection(store: store)
          
          // 답변 필요한 제안
          PendingResponseSection(store: store)
          
        }
        .padding(.top, 8)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("오늘의 일정")
//      .navigationSubtitle("모든 그룹의 약속을 한눈에")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            // FIXME: Alert Open
          } label: {
            Image(systemName: "bell")
          }
          .badge(3) // FIXME: Alert Badge
        }
      }
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
  
  // MARK: - Data Models
  
  /// 약속 아이템을 나타내는 모델
  public struct PromiseItem: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let time: String
    public let location: String
    public let with: String
    public let status: PromiseStatus
    public let liveActivityStatus: LiveActivityStatus
    
    public init(id: String, title: String, emoji: String, time: String, location: String, with: String, status: PromiseStatus, liveActivityStatus: LiveActivityStatus) {
      self.id = id
      self.title = title
      self.emoji = emoji
      self.time = time
      self.location = location
      self.with = with
      self.status = status
      self.liveActivityStatus = liveActivityStatus
    }
  }
  
  /// 약속 상태를 나타내는 열거형
  public enum PromiseStatus: Equatable {
    case today
    case upcoming
    case confirmed
  }
  
  /// Live Activity 상태를 나타내는 열거형
  public enum LiveActivityStatus: Equatable {
    case canStart
    case scheduled
    case active
  }
  
  /// 대기 중인 응답을 나타내는 모델
  public struct PendingResponse: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let from: String
    public let group: String
    public let daysLeft: Int
    
    public init(id: String, title: String, emoji: String, from: String, group: String, daysLeft: Int) {
      self.id = id
      self.title = title
      self.emoji = emoji
      self.from = from
      self.group = group
      self.daysLeft = daysLeft
    }
  }
}
