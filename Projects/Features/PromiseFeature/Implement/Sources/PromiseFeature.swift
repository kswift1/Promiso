// MARK: - PromiseFeature.swift
// TCA 1.22.2를 사용한 Promise Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import PromiseFeatureInterface

// MARK: - Feature Namespace

/// Promise Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum Promise {}

// MARK: - Core Feature Implementation

extension Promise {
  
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
      // MARK: - Segment Control
      public var selectedSegment: PromiseSegment = .received
      
      // MARK: - Received Proposals
      public var receivedProposals: [ProposalItem] = [
        ProposalItem(
          id: "1",
          title: "카페 데이트",
          emoji: "☕",
          time: "오후 2:00",
          location: "스타벅스 강남점",
          with: "지민",
          status: .pending,
          isReceived: true
        ),
        ProposalItem(
          id: "2",
          title: "주말 브런치",
          emoji: "🥐",
          time: "오전 11:00",
          location: "브런치 카페",
          with: "지민",
          status: .pending,
          isReceived: true
        )
      ]
      
      // MARK: - Sent Proposals
      public var sentProposals: [ProposalItem] = [
        ProposalItem(
          id: "3",
          title: "영화 관람",
          emoji: "🎬",
          time: "오후 7:00",
          location: "CGV 강남",
          with: "지민",
          status: .accepted,
          isReceived: false
        ),
        ProposalItem(
          id: "4",
          title: "저녁 식사",
          emoji: "🍽️",
          time: "오후 6:30",
          location: "맛집 레스토랑",
          with: "지민",
          status: .pending,
          isReceived: false
        )
      ]
      
      // MARK: - Groups
      public var currentGroup: String = "지민과 나"
      public var availableGroups: [GroupItem] = [
        GroupItem(id: "1", name: "지민과 나", members: ["나", "지민"], isActive: true),
        GroupItem(id: "2", name: "회사 동료들", members: ["나", "철수", "영희"], isActive: false),
        GroupItem(id: "3", name: "대학 친구들", members: ["나", "민수", "수진"], isActive: false)
      ]
      
      /// State 초기화
      public init() {}
    }
    
    // MARK: - Action
    
    /// Promise Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      // MARK: Segment Actions
      case segmentChanged(PromiseSegment)
      
      // MARK: Proposal Actions
      case proposalSelected(String) // Proposal ID
      case acceptProposal(String) // Proposal ID
      case rejectProposal(String) // Proposal ID
      case createNewProposal
      
      // MARK: Group Actions
      case groupSelected(String) // Group ID
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
          
        case .segmentChanged(let segment):
          state.selectedSegment = segment
          return .none
          
        case .proposalSelected(_):
          // 제안 상세보기로 이동
          return .none
          
        case .acceptProposal(let id):
          // 제안 수락 로직
          if let index = state.receivedProposals.firstIndex(where: { $0.id == id }) {
            state.receivedProposals[index].status = .accepted
          }
          return .none
          
        case .rejectProposal(let id):
          // 제안 거절 로직
          if let index = state.receivedProposals.firstIndex(where: { $0.id == id }) {
            state.receivedProposals[index].status = .rejected
          }
          return .none
          
        case .createNewProposal:
          // 새 제안 만들기 화면으로 이동
          return .none
          
        case .groupSelected(let id):
          // 그룹 선택 로직
          if let selectedGroup = state.availableGroups.first(where: { $0.id == id }) {
            state.currentGroup = selectedGroup.name
            // 모든 그룹의 isActive를 false로 설정
            for i in state.availableGroups.indices {
              state.availableGroups[i].isActive = false
            }
            // 선택된 그룹의 isActive를 true로 설정
            if let index = state.availableGroups.firstIndex(where: { $0.id == id }) {
              state.availableGroups[index].isActive = true
            }
          }
          return .none
        }
      }
    }
  }
}

// MARK: - View Implementation

extension Promise {
  /// Promise Feature의 Root View
  public struct RootView: View {
    private let store: StoreOf<Promise.Feature>
    
    public init(store: StoreOf<Promise.Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      WithPerceptionTracking {
        mainContentView
          .onAppear {
            store.send(.onAppear)
          }
      }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
      WithPerceptionTracking {
        ScrollView {
          VStack(spacing: 20) {
            // 현재 그룹 표시
            currentGroupSection
            
            // 세그먼트 컨트롤
            segmentControl
            
            // 제안 목록
            proposalsList
            
            // 새 제안 만들기 버튼
            createNewProposalButton
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
        }
      }
    }
    
    
    // MARK: - Current Group Section
    
    private var currentGroupSection: some View {
      WithPerceptionTracking {
        HStack {
          Image(systemName: "person.2.fill")
            .foregroundColor(.blue)
            .font(.title2)
          
          VStack(alignment: .leading, spacing: 4) {
            Text(store.currentGroup)
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
            
            Text("현재 그룹")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          Spacer()
          
          Button(action: {
            // 그룹 선택 화면으로 이동
          }) {
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
              .font(.caption)
          }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
      }
    }
    
    // MARK: - Segment Control
    
    private var segmentControl: some View {
      HStack(spacing: 0) {
        ForEach(PromiseSegment.allCases, id: \.self) { segment in
          WithPerceptionTracking {
            Button(action: {
              store.send(.segmentChanged(segment))
            }) {
              Text(segment.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(store.selectedSegment == segment ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(store.selectedSegment == segment ? Color.blue : Color.clear)
                )
            }
          }
        }
      }
      .padding(4)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(12)
    }
    
    // MARK: - Proposals List
    
    private var proposalsList: some View {
      LazyVStack(spacing: 12) {
        ForEach(currentProposals) { proposal in
          WithPerceptionTracking {
            ProposalCard(proposal: proposal) {
              store.send(.proposalSelected(proposal.id))
            } onAccept: {
              store.send(.acceptProposal(proposal.id))
            } onReject: {
              store.send(.rejectProposal(proposal.id))
            }
          }
        }
      }
    }
    
    // MARK: - Create New Proposal Button
    
    private var createNewProposalButton: some View {
      WithPerceptionTracking {
        Button(action: {
          store.send(.createNewProposal)
        }) {
          HStack {
            Image(systemName: "plus.circle.fill")
              .font(.title2)
              .foregroundColor(.white)
            
            Text("새 약속 만들기")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(.white)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(Color.blue)
          .cornerRadius(12)
        }
      }
    }
    
    // MARK: - Computed Properties
    
    private var currentProposals: [ProposalItem] {
      switch store.selectedSegment {
      case .received:
        return store.receivedProposals
      case .sent:
        return store.sentProposals
      }
    }
  }
}

// MARK: - Proposal Card View

private struct ProposalCard: View {
  let proposal: ProposalItem
  let onTap: () -> Void
  let onAccept: () -> Void
  let onReject: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(proposal.emoji)
          .font(.title)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(proposal.title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
          
          HStack {
            Image(systemName: "clock")
              .foregroundColor(.secondary)
              .font(.caption)
            Text(proposal.time)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          HStack {
            Image(systemName: "location")
              .foregroundColor(.secondary)
              .font(.caption)
            Text(proposal.location)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          HStack {
            Image(systemName: "person")
              .foregroundColor(.secondary)
              .font(.caption)
            Text("with \(proposal.with)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        
        Spacer()
        
        statusBadge
      }
      
      if proposal.isReceived && proposal.status == .pending {
        HStack(spacing: 12) {
          Button(action: onReject) {
            Text("거절")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.red)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(Color.red.opacity(0.1))
              .cornerRadius(8)
          }
          
          Button(action: onAccept) {
            Text("수락")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(Color.blue)
              .cornerRadius(8)
          }
        }
      }
    }
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    .onTapGesture {
      onTap()
    }
  }
  
  private var statusBadge: some View {
    Text(proposal.status.title)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundColor(proposal.status.textColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(proposal.status.backgroundColor)
      .cornerRadius(6)
  }
}

// MARK: - Data Models

/// 약속 세그먼트를 나타내는 열거형
public enum PromiseSegment: CaseIterable, Equatable, Sendable {
  case received
  case sent
  
  public var title: String {
    switch self {
    case .received: return "받은 제안"
    case .sent: return "보낸 제안"
    }
  }
}

/// 제안 아이템을 나타내는 구조체
public struct ProposalItem: Equatable, Identifiable {
  public let id: String
  public let title: String
  public let emoji: String
  public let time: String
  public let location: String
  public let with: String
  public var status: ProposalStatus
  public let isReceived: Bool
}

/// 제안 상태를 나타내는 열거형
public enum ProposalStatus: Equatable {
  case pending
  case accepted
  case rejected
  
  public var title: String {
    switch self {
    case .pending: return "대기중"
    case .accepted: return "수락됨"
    case .rejected: return "거절됨"
    }
  }
  
  public var textColor: Color {
    switch self {
    case .pending: return .orange
    case .accepted: return .green
    case .rejected: return .red
    }
  }
  
  public var backgroundColor: Color {
    switch self {
    case .pending: return .orange.opacity(0.1)
    case .accepted: return .green.opacity(0.1)
    case .rejected: return .red.opacity(0.1)
    }
  }
}

/// 그룹 아이템을 나타내는 구조체
public struct GroupItem: Equatable, Identifiable {
  public let id: String
  public let name: String
  public let members: [String]
  public var isActive: Bool
}
