//
//  CreatePromiseFeature.swift
//  PromiseFeature
//
//  Created by 김성원 on 9/30/25.
//

public enum CreatePromise {
  
  
  @Reducer
  public struct Feature {
    
    @Dependency(\.continuousClock) var clock
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient

    
    private enum CancelID: Hashable {
      case emojiSuggestDebounce
    }
    
    @ObservableState
    public struct State: Equatable {
      var currentStep: CreatePromiseStep = .first
      var promiseProposal: PromiseProposal = .empty
      var groupListState: LoadingState<[GroupModel]> = .idle
      var isCreatingPromise: Bool = false
      var creationError: Clients.PromiseClientError?

      public init(
        currentStep: CreatePromiseStep = .first,
        promiseProposal: PromiseProposal = .empty,
        groupListState: LoadingState<[GroupModel]> = .idle,
        isCreatingPromise: Bool = false,
        creationError: Clients.PromiseClientError? = nil
      ) {
        self.currentStep = currentStep
        self.promiseProposal = promiseProposal
        self.groupListState = groupListState
        self.isCreatingPromise = isCreatingPromise
        self.creationError = creationError
      }
      
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
      
      var thirdButtonDisabled: Bool {
        isCreatingPromise // 생성 중일 때만 비활성화
      }
    }
    
    public enum Action: Sendable {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)
      
      // 사용자가 트리거하는 UI 이벤트
      public enum View: Sendable {
        case onAppear
        case nextStep
        case previousStep
        case requestCreatingPromise
        case setTitle(String)
        case groupSelected(GroupModel)
        case setStartDate(Date)
        case setEndDate(Date?)
        case toggleUseEndTime
        case incrementParticipants
        case decrementParticipants
        case setArrivalSharingTime(Int?)
        case setDescription(String)
        case retryLoadGroups
        case clearCreationError
      }
      
      // 내부에서만 발생하는 이벤트 (이펙트 응답/디바운스 등)
      public enum Internal: Sendable {
        case titleDebounced(String)
        case emojiSuggestionsResponse([EmojiSuggestion])
        case fetchGroupList
        case groupListResponse(Result<[GroupModel], Error>)
        case createPromiseResponse(Result<String, Clients.PromiseClientError>)
      }
      
      // 상위 전달 이벤트 (네비/라우팅/완료 알림 등)
      public enum Delegate: Sendable {
        case promiseCreated(id: String)
        case dismiss
      }
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
          
          // MARK: - View
        case .view(let viewAction):
          switch viewAction {
            
          case .onAppear:
            return .send(.internal(.fetchGroupList))
            
          case .nextStep:
            state.currentStep.next()
            return .none
            
          case .previousStep:
            state.currentStep.previous()
            return .none
            
          case .requestCreatingPromise:
            state.isCreatingPromise = true
            state.creationError = nil
            return .run { [proposal = state.promiseProposal, promiseClient] send in
              do {
                let hostId = "sungwon" // TODO: 실제 사용자 ID
                let promiseId = try await promiseClient.createPromise(proposal, hostId)
                await send(.internal(.createPromiseResponse(.success(promiseId))))
              } catch let e as Clients.PromiseClientError {
                await send(.internal(.createPromiseResponse(.failure(e))))
              } catch {
                await send(.internal(.createPromiseResponse(.failure(.unknown))))
              }
            }
            
          case .setTitle(let title):
            state.promiseProposal.title = title
            return .merge(
              .cancel(id: CancelID.emojiSuggestDebounce),
              .run { [clock, title] send in
                try await clock.sleep(for: .milliseconds(1_000))
                await send(.internal(.titleDebounced(title)))
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
            return .send(.internal(.fetchGroupList))
            
          case .clearCreationError:
            state.creationError = nil
            return .none
            
          case .setEndDate(let date):
            state.promiseProposal.endedAt = date
            return .none
            
          case .toggleUseEndTime:
            if state.promiseProposal.endedAt == nil {
              state.promiseProposal.endedAt = state.promiseProposal.startedAt.addingTimeInterval(7200)
            } else {
              state.promiseProposal.endedAt = nil
            }
            return .none
            
          case .incrementParticipants:
            guard let max = state.promiseProposal.group?.memberCount else { return .none }
            let current = state.promiseProposal.minimumParticipants ?? 2
            if current < max { state.promiseProposal.minimumParticipants = current + 1 }
            return .none
            
          case .decrementParticipants:
            let current = state.promiseProposal.minimumParticipants ?? 2
            if current > 2 { state.promiseProposal.minimumParticipants = current - 1 }
            return .none
            
          case .setArrivalSharingTime(let minutes):
            state.promiseProposal.arrivalSharingTime = minutes
            return .none
            
          case .setDescription(let description):
            let trimmed = String(description.prefix(500))
            state.promiseProposal.details = trimmed.isEmpty ? nil : trimmed
            return .none
            
          case .setStartDate(let date):
            state.promiseProposal.startedAt = date
            if let end = state.promiseProposal.endedAt, end <= date {
              state.promiseProposal.endedAt = date.addingTimeInterval(7200)
            }
            return .none
          }
          
          // MARK: - Internal
        case .internal(let internalAction):
          switch internalAction {
            
          case .titleDebounced(let title):
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
            return .run { [title] send in
              let picks = await EmojiSuggestorProvider.shared.suggest(for: title, topK: 10)
              await send(.internal(.emojiSuggestionsResponse(picks)))
            }
            
          case .emojiSuggestionsResponse(let picks):
            state.promiseProposal.emoji = picks.first?.emoji ?? ""
            return .none
            
          case .fetchGroupList:
            state.groupListState = .loading
            return .run { [groupClient] send in
              do {
                let groups = try await groupClient.fetchGroups()
                await send(.internal(.groupListResponse(.success(groups))))
              } catch {
                await send(.internal(.groupListResponse(.failure(error))))
              }
            }
            
          case .groupListResponse(.success(let groups)):
            state.groupListState = .loaded(groups)
            return .none
            
          case .groupListResponse(.failure(let error)):
            state.groupListState = .failed(error)
            return .none
            
          case .createPromiseResponse(.success(let id)):
            state.isCreatingPromise = false
            return .send(.delegate(.promiseCreated(id: id)))
            
          case .createPromiseResponse(.failure(let e)):
            state.isCreatingPromise = false
            state.creationError = e
            return .none
          }
          
          // MARK: - Binding
        case .binding:
          return .none
          
          // MARK: - Delegate (여기선 부모가 처리하므로 기본은 .none)
        case .delegate:
          return .none
        }
      }
    }
  }
}

extension CreatePromise {

  public struct RootView: View {
    private let store: StoreOf<CreatePromise.Feature>

    public init(store: StoreOf<CreatePromise.Feature>) {
      self.store = store
    }

    public var body: some View {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          
          // Progress Header
          ProgressHeader(
            currentStep: store.currentStep.rawValue,
            totalSteps: CreatePromiseStep.allCases.count,
            title: "약속 만들기"
          ) {
            store.send(.delegate(.dismiss))
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
        store.send(.view(.onAppear))
      }
      .alert(
        "약속 생성 실패",
        isPresented: Binding(
          get: { store.creationError != nil },
          set: { if !$0 { store.send(.view(.clearCreationError)) } }
        )
      ) {
        Button("확인", role: .cancel) {
          store.send(.view(.clearCreationError))
        }
      } message: {
        if let error = store.creationError {
          Text(error.localizedDescription)
        }
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
        store.send(.view(.previousStep), animation: .default)
      }) {
        Text("이전")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
//          .background()
          .cornerRadius(12)
      }
      .adaptiveSecondaryButton(fallBackBackground: Color(.systemGray6))
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
          store.send(
            .view(.nextStep),
            animation: .easeInOut(duration: 0.25)
          )
        }
      
    case .second:
      StepButton(
        title: "다음",
        disabled: store.state.secondButtonDisabled) {
          store.send(
            .view(.nextStep),
            animation: .easeInOut(duration: 0.25)
          )
        }
      
    case .third:
      StepButton(
        title: "약속 제안하기",
        disabled: store.state.thirdButtonDisabled,
        isLoading: store.state.isCreatingPromise) {
          store.send(
            .view(.requestCreatingPromise),
            animation: .spring(response: 0.3, dampingFraction: 0.9)
          )
        }
    }
  }
}

fileprivate struct StepButton: View {
  let title: String
  var disabled: Bool
  var isLoading: Bool = false
  var action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
        
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(0.7)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 50)
//      .background(disabled ? Color.gray.opacity(0.4) : Color.blue)
      .cornerRadius(12)
    }
    .disabled(disabled)
    .adaptivePrimaryButton()
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

