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
      
      // MARK: - Today's Promises
      public var todaysPromises: [PromiseItem] = [
        PromiseItem(
          id: "1",
          title: "영화 관람",
          emoji: "🍿",
          time: "오후 7:00",
          location: "CGV 강남",
          with: "지민",
          status: .today
        )
      ]
      
      // MARK: - Pending Responses
      public var pendingResponses: [PendingResponse] = [
        PendingResponse(
          id: "1",
          title: "카페 데이트",
          emoji: "☕",
          from: "지민",
          daysLeft: 4
        ),
        PendingResponse(
          id: "2",
          title: "주말 브런치",
          emoji: "🥐",
          from: "지민",
          daysLeft: 6
        )
      ]
      
      // MARK: - Quick Actions
      public var weeklyPromiseCount: Int = 4
      
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
      WithPerceptionTracking {
        ScrollView {
          VStack(spacing: 24) {
            
            // 오늘의 약속
            todaysPromisesSection
            
            // 답변 필요
            pendingResponsesSection
            
            // 빠른 액션
            quickActionsSection
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
          store.send(.onAppear)
        }
      }
    }
    
    // MARK: - Today's Promises Section
    
    private var todaysPromisesSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("오늘의 약속")
          .font(.title2)
          .fontWeight(.semibold)
        
        ForEach(store.todaysPromises) { promise in
          PromiseCard(promise: promise) {
            store.send(.startLiveActivity(promise.id))
          }
        }
      }
    }
    
    // MARK: - Pending Responses Section
    
    private var pendingResponsesSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("답변 필요")
            .font(.title2)
            .fontWeight(.semibold)
          
          Spacer()
          
          Button("지금 확인하기 →") {
            store.send(.viewPendingResponses)
          }
          .font(.caption)
          .foregroundColor(.orange)
        }
        
        VStack(spacing: 8) {
          HStack {
            Circle()
              .fill(Color.orange)
              .frame(width: 8, height: 8)
              .opacity(0.8)
            
            Text("답변 대기중")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.orange)
            
            Text("\(store.pendingResponses.count)건")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(Color.orange.opacity(0.2))
              .foregroundColor(.orange)
              .cornerRadius(8)
            
            Spacer()
          }
          
          Text(store.pendingResponses.map { $0.title }.joined(separator: ", "))
            .font(.caption)
            .foregroundColor(.orange.opacity(0.8))
            .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
      }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("빠른 액션")
          .font(.title2)
          .fontWeight(.semibold)
        
        HStack(spacing: 12) {
          QuickActionButton(
            icon: "calendar",
            title: "이번주",
            subtitle: "약속 \(store.weeklyPromiseCount)개",
            color: .blue
          ) {
            store.send(.viewWeeklyPromises)
          }
          
          QuickActionButton(
            icon: "plus",
            title: "새 제안",
            subtitle: "만들기",
            color: .blue,
            isPrimary: true
          ) {
            store.send(.createNewProposal)
          }
        }
      }
    }
  }
  
  // MARK: - Promise Card
  
  private struct PromiseCard: View {
    let promise: PromiseItem
    let onLiveActivityTap: () -> Void
    
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(promise.emoji)
            .font(.title2)
          
          Text(promise.title)
            .font(.headline)
            .fontWeight(.semibold)
          
          Spacer()
          
          Text("오늘")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.2))
            .foregroundColor(.green)
            .cornerRadius(8)
        }
        
        Text("\(promise.time) · \(promise.location) · with \(promise.with)")
          .font(.subheadline)
          .foregroundColor(.secondary)
        
        Button("Live Activity 시작") {
          onLiveActivityTap()
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(8)
      }
      .padding(16)
      .background(Color(.systemBackground))
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
  }
  
  // MARK: - Quick Action Button
  
  private struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String, color: Color, isPrimary: Bool = false, action: @escaping () -> Void) {
      self.icon = icon
      self.title = title
      self.subtitle = subtitle
      self.color = color
      self.isPrimary = isPrimary
      self.action = action
    }
    
    var body: some View {
      Button(action: action) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundColor(isPrimary ? color : color)
          
          Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isPrimary ? color : .primary)
          
          Text(subtitle)
            .font(.caption)
            .foregroundColor(isPrimary ? color.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isPrimary ? color.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isPrimary ? color.opacity(0.2) : Color.clear, lineWidth: 1)
        )
      }
      .buttonStyle(PlainButtonStyle())
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
  
  public init(id: String, title: String, emoji: String, time: String, location: String, with: String, status: PromiseStatus) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.time = time
    self.location = location
    self.with = with
    self.status = status
  }
}

/// 약속 상태를 나타내는 열거형
public enum PromiseStatus: Equatable {
  case today
  case upcoming
  case confirmed
}

/// 대기 중인 응답을 나타내는 모델
public struct PendingResponse: Equatable, Identifiable {
  public let id: String
  public let title: String
  public let emoji: String
  public let from: String
  public let daysLeft: Int
  
  public init(id: String, title: String, emoji: String, from: String, daysLeft: Int) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.from = from
    self.daysLeft = daysLeft
  }
}
