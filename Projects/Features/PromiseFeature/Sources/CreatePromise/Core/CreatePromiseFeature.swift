//
//  CreatePromiseFeature.swift
//  PromiseFeature
//
//  Created by 김성원 on 9/30/25.
//

import SwiftUI
import ComposableArchitecture

import Domain
import Shared

public enum CreatePromise {
  
  
  @Reducer
  public struct Feature {
    
    @Dependency(\.continuousClock) var clock
    @Dependency(\.groupClient) var groupClient
    
    private enum CancelID: Hashable {
      case emojiSuggestDebounce
    }
    
    @ObservableState
    public struct State: Equatable {
      var currentStep: CreatePromiseStep = .first
      var promiseProposal: PromiseProposal = .empty
      var groupListState: LoadingState<[GroupModel]> = .idle
      
      var firstButtonDisabled: Bool {
        !(!promiseProposal.title.isEmpty && promiseProposal.group != nil)
      }
      
      var secondButtonDisabled: Bool {
        // 시작 시간이 현재보다 미래인지 확인
        guard promiseProposal.startedAt > Date() else { return true }
        
        // 종료 시간을 사용하는 경우, 시작 시간보다 이후인지 확인
        if let endedAt = promiseProposal.endedAt {
          guard endedAt > promiseProposal.startedAt else { return true }
        }
        
        // 최소 참가 인원이 유효한지 확인
        guard let minimumParticipants = promiseProposal.minimumParticipants, minimumParticipants >= 2 else {
          return true
        }
        
        return false
      }
      
      var maxParticipants: Int? {
        promiseProposal.group?.memberCount
      }
      
      // 종료 시간 사용 여부
      var useEndTime: Bool {
        promiseProposal.endedAt != nil
      }
      
      var thirdButtonDisabled: Bool {
        false // Step3는 선택사항이므로 항상 진행 가능
      }
    }
    
    public enum Action: Sendable {
      case onAppear
      case nextStep
      case previousStep
      case requestCreatingPromise
      case dismiss
      case promiseCreated
      case setTitle(String)
      case groupSelected(GroupModel)
      case setStartDate(Date)
      case setEndDate(Date?)
      case toggleUseEndTime
      //      case setLocation(Location?)
      case setMinimumParticipants(Int)
      case incrementParticipants
      case decrementParticipants
      case setArrivalSharingTime(Int?)
      case setDescription(String)
      case retryLoadGroups  // 재시도
      case _titleDebounced(String)
      case _emojiSuggestionsResponse([EmojiSuggestion])
      case _fetchGroupList
      case _groupListResponse(Result<[GroupModel], Error>)
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // FetchGroups
          return .send(._fetchGroupList)
          
        case .nextStep:
          state.currentStep.next()
          return .none
          
        case .previousStep:
          state.currentStep.previous()
          return .none
          
        case .requestCreatingPromise:
          return .none
          
        case .dismiss:
          return .none
          
        case .promiseCreated:
          return .none
          
          // 사용자가 제목 입력
        case .setTitle(let title):
          state.promiseProposal.title = title
          
          return .merge(
            .cancel(id: CancelID.emojiSuggestDebounce),
            .run { [clock, title] send in
              try await clock.sleep(for: .milliseconds(1_000))   // 디바운스
              await send(._titleDebounced(title))
            }
              .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
          )
          
        case .groupSelected(let group):
          state.promiseProposal.group = group
          
          if group.memberCount == 2 {
            state.promiseProposal.minimumParticipants = 2
          } else {
            let defaultMinimum = Int(ceil(Double(group.memberCount) / 2.0))
            state.promiseProposal.minimumParticipants = defaultMinimum
          }

          return .none
          
        case .retryLoadGroups:
          return .send(._fetchGroupList)
          
        case .setEndDate(let date):
          state.promiseProposal.endedAt = date
          return .none
          
        case .toggleUseEndTime:
          if state.promiseProposal.endedAt == nil {
            // 종료 시간 활성화: 시작 시간 + 2시간
            state.promiseProposal.endedAt = state.promiseProposal.startedAt.addingTimeInterval(7200)
          } else {
            // 종료 시간 비활성화
            state.promiseProposal.endedAt = nil
          }
          return .none
          
          //        case .setLocation(let location):
          //          state.promiseProposal.location = location
          //          return .none
          
        case .setMinimumParticipants(let count):
          guard let maxParticipants = state.maxParticipants else { return .none }
          let validCount = max(2, min(count, maxParticipants))
          state.promiseProposal.minimumParticipants = validCount
          return .none

        case .incrementParticipants:
          guard let maxParticipants = state.maxParticipants else { return .none }
          let current = state.promiseProposal.minimumParticipants ?? 2
          if current < maxParticipants {
            state.promiseProposal.minimumParticipants = current + 1
          }
          return .none
          
        case .decrementParticipants:
          let current = state.promiseProposal.minimumParticipants ?? 2
          if current > 2 {
            state.promiseProposal.minimumParticipants = current - 1
          }
          return .none

        case .setArrivalSharingTime(let minutes):
          state.promiseProposal.arrivalSharingTime = minutes
          return .none

        case .setDescription(let description):
          let trimmed = String(description.prefix(500))
          state.promiseProposal.details = trimmed.isEmpty ? nil : trimmed
          return .none
          
          // 디바운스 종료 → 실제 추천 호출
        case ._titleDebounced(let title):
          // 빈 문자열이면 추천 비움
          guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .none
          }
          return .run { [title] send in
            let picks = await EmojiSuggestorProvider.shared.suggest(for: title, topK: 10)
            await send(._emojiSuggestionsResponse(picks))
          }
          
          // 추천 결과 수신 → 상태 반영
        case ._emojiSuggestionsResponse(let picks):
          state.promiseProposal.emoji = picks.first?.emoji ?? ""
          return .none
          
        case ._fetchGroupList:
          state.groupListState = .loading
          
          return .run { [groupClient] send in
            do {
              let groups = try await groupClient.fetchGroups()
              await send(._groupListResponse(.success(groups)))
            } catch {
              await send(._groupListResponse(.failure(error)))
            }
          }
          
        case ._groupListResponse(.success(let groups)):
          state.groupListState = .loaded(groups)
          return .none
          
        case ._groupListResponse(.failure(let error)):
          state.groupListState = .failed(error)
          return .none
        case .setStartDate(let date):
          state.promiseProposal.startedAt = date
          
          // 종료 시간이 시작 시간보다 이전이면 자동 조정
          if let endDate = state.promiseProposal.endedAt, endDate <= date {
            state.promiseProposal.endedAt = date.addingTimeInterval(7200) // 2시간 후
          }
          return .none
        }
      }
    }
  }
}

extension CreatePromise {
  
  struct RootView: View {
    private let store: StoreOf<CreatePromise.Feature>
    
    init(store: StoreOf<CreatePromise.Feature>) {
      self.store = store
    }
    
    var body: some View {
      GeometryReader { geometry in
        VStack(spacing: 0) {

          // Progress Header
          ProgressHeader(
            currentStep: store.currentStep.rawValue,
            totalSteps: CreatePromiseStep.allCases.count,
            title: "약속 만들기"
          ) {
            store.send(.dismiss)
          }

          store.currentStep.contentView(store: store)

          Spacer()

          // Bottom Buttons (키보드에 가려지지 않도록 고정)
          HStack(spacing: 12) {
            store.currentStep.leftButton(store: store)

            store.currentStep.rightButton(store: store)
          }
          .padding(16)
          .background(Color(.systemBackground))
          .overlay(
            Rectangle()
              .fill(Color(.systemGray5))
              .frame(height: 1),
            alignment: .top
          )
        }
        .frame(height: geometry.size.height)
      }
      .navigationBarHidden(true)
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

extension CreatePromiseStep {
  @ViewBuilder
  func leftButton(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      EmptyView()
      
    case .second, .third:
      Button(action: {
        store.send(.previousStep, animation: .default)
      }) {
        Text("이전")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color(.systemGray6))
          .cornerRadius(12)
      }
    }
  }
  
  /// 하단 오른쪽 버튼 (다음 or 완료 버튼)
  @ViewBuilder
  func rightButton(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      StepButton(
        title: "다음",
        disabled: store.state.firstButtonDisabled) {
          store.send(.nextStep, animation: .easeInOut(duration: 0.25))
        }
      
    case .second:
      StepButton(
        title: "다음",
        disabled: store.state.secondButtonDisabled) {
          store.send(.nextStep, animation: .easeInOut(duration: 0.25))
        }
      
    case .third:
      StepButton(
        title: "약속 제안하기",
        disabled: store.state.thirdButtonDisabled) {
          store.send(.requestCreatingPromise, animation: .spring(response: 0.3, dampingFraction: 0.9))
        }
    }
  }
}

fileprivate struct StepButton: View {
  let title: String
  var disabled: Bool
  var action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(disabled ? Color.gray.opacity(0.4) : Color.blue)
        .cornerRadius(12)
    }
    .disabled(disabled)
  }
}

// MARK: - CreatePromiseStep Extension
extension CreatePromiseStep {
  @ViewBuilder
  func contentView(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      CreatePromiseStep1View(store: store)
    case .second:
      CreatePromiseStep2View(store: store)
    case .third:
      CreatePromiseStep3View(store: store)
    }
  }
}

