//
//  CreateGroupFeature.swift
//  GroupFeature
//
//  Created by 김성원 on 9/30/25.
//

// TODO: LiveActivity 활성화 선택 화면 추가, 지도 추가, 이미지 추가
public enum CreatePromise {
  
  
  @Reducer
  public struct Feature {
    
    @Dependency(\.continuousClock) var clock
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient

    
    private enum CancelID: Hashable {
      case emojiSuggestDebounce
    }
    
    @ObservableState
    public struct State: Equatable {
      static let maxActivePromisesPerGroup = 10

      var currentStep: CreatePromiseStep = .first
      var promise: PromiseModel = .empty
      var groupListState: LoadingState<[GroupModel]> = .idle
      var groupSummaries: [UserGroupInfo]?
      var groupPromiseCounts: [String: Int] = [:]
      var isCreatingPromise: Bool = false
      var creationError: Clients.PromiseClientError?

      // LiveActivity 정보 팝오버 상태
      var showLiveActivityInfo: Bool = false
      var hasSeenLiveActivityInfo: Bool = true  // 기본 true (로드 전까지 팝업 안 띄움)

      public init(
        currentStep: CreatePromiseStep = .first,
        promise: PromiseModel = .empty,
        groupListState: LoadingState<[GroupModel]> = .idle,
        groupSummaries: [UserGroupInfo]? = nil,
        groupPromiseCounts: [String: Int] = [:],
        isCreatingPromise: Bool = false,
        creationError: Clients.PromiseClientError? = nil,
        showLiveActivityInfo: Bool = false,
        hasSeenLiveActivityInfo: Bool = true
      ) {
        self.currentStep = currentStep
        self.promise = promise
        self.groupListState = groupListState
        self.groupSummaries = groupSummaries
        self.groupPromiseCounts = groupPromiseCounts
        self.isCreatingPromise = isCreatingPromise
        self.creationError = creationError
        self.showLiveActivityInfo = showLiveActivityInfo
        self.hasSeenLiveActivityInfo = hasSeenLiveActivityInfo
      }

      /// 그룹이 활성 약속 제한에 도달했는지 확인
      func isGroupAtLimit(_ groupId: String) -> Bool {
        guard let count = groupPromiseCounts[groupId] else { return false }
        return count >= Self.maxActivePromisesPerGroup
      }

      var firstButtonDisabled: Bool {
        // 제목이 비어있거나 그룹이 선택되지 않았거나 그룹 멤버가 1명 이하인 경우
        if !promise.isTitleValid {
          return true
        }

        guard let group = promise.group else {
          return true
        }

        // 그룹 멤버가 1명 이하면 비활성화
        if group.memberIds.count <= 1 {
          return true
        }

        return false
      }

      var secondButtonDisabled: Bool {
        // 시작 시간이 현재보다 미래인지 확인
        guard promise.isStartTimeValid else { return true }

        // 종료 시간을 사용하는 경우, 시작 시간보다 이후인지 확인
        guard promise.isEndTimeValid else { return true }

        // 최소 참가 인원이 유효한지 확인
        guard promise.isMinimumParticipantsValid else { return true }

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
        case setDescription(String)
        case setTrackingStartMinutes(Int?)
        case retryLoadGroups
        case clearCreationError
        case createGroupTapped
        // LiveActivity 정보 팝오버
        case liveActivityInfoButtonTapped
        case liveActivityInfoDismissed
        case arrivalSharingSectionAppeared
      }
      
      // 내부에서만 발생하는 이벤트 (이펙트 응답/디바운스 등)
      public enum Internal: Sendable {
        case titleDebounced(String)
        case emojiSuggestionsResponse([EmojiSuggestion])
        case fetchGroupList
        case groupListResponse(Result<[GroupModel], Error>)
        case fetchPromiseCounts([String])
        case promiseCountsResponse([String: Int])
        case createPromiseResponse(Result<String, Clients.PromiseClientError>)
        case liveActivityInfoSeenLoaded(Bool)
      }
      
      // 상위 전달 이벤트 (네비/라우팅/완료 알림 등)
      public enum Delegate: Sendable {
        case promiseCreated(id: String)
        case dismiss
        case createGroupRequested
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
            // groupId 설정 (hostId는 서버에서 auth.uid로 설정)
            var promiseToCreate = state.promise
            promiseToCreate.groupId = state.promise.group?.id ?? ""
            return .run { [promise = promiseToCreate, promiseClient] send in
              do {
                let promiseId = try await promiseClient.createPromise(promise)
                await send(.internal(.createPromiseResponse(.success(promiseId))))
              } catch let e as Clients.PromiseClientError {
                await send(.internal(.createPromiseResponse(.failure(e))))
              } catch {
                await send(.internal(.createPromiseResponse(.failure(.unknown(error.localizedDescription)))))
              }
            }
            
          case .setTitle(let title):
            state.promise.title = title
            return .merge(
              .cancel(id: CancelID.emojiSuggestDebounce),
              .run { [clock, title] send in
                try await clock.sleep(for: .milliseconds(1_000))
                await send(.internal(.titleDebounced(title)))
              }
                .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
            )

          case .groupSelected(let group):
            state.promise.group = group
            if group.memberIds.count == 2 {
              state.promise.minimumParticipants = 2
            } else {
              let defaultMinimum = Int(ceil(Double(group.memberIds.count) / 2.0))
              state.promise.minimumParticipants = defaultMinimum
            }
            return .none

          case .retryLoadGroups:
            return .send(.internal(.fetchGroupList))

          case .clearCreationError:
            state.creationError = nil
            return .none

          case .setEndDate(let date):
            state.promise.endAt = date
            return .none

          case .toggleUseEndTime:
            if state.promise.endAt == nil {
              state.promise.endAt = state.promise.startAt.addingTimeInterval(7200)
            } else {
              state.promise.endAt = nil
            }
            return .none

          case .incrementParticipants:
            guard let max = state.promise.group?.memberIds.count else { return .none }
            let current = state.promise.minimumParticipants
            if current < max { state.promise.minimumParticipants = current + 1 }
            return .none

          case .decrementParticipants:
            let current = state.promise.minimumParticipants
            if current > 2 { state.promise.minimumParticipants = current - 1 }
            return .none

          case .setDescription(let description):
            let trimmed = String(description.prefix(500))
            state.promise.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .setTrackingStartMinutes(let minutes):
            state.promise.trackingStartMinutesBefore = minutes
            return .none

          case .setStartDate(let date):
            state.promise.startAt = date
            if let end = state.promise.endAt, end <= date {
              state.promise.endAt = date.addingTimeInterval(7200)
            }
            return .none

          case .createGroupTapped:
            return .send(.delegate(.createGroupRequested))

          case .liveActivityInfoButtonTapped:
            state.showLiveActivityInfo = true
            return .none

          case .liveActivityInfoDismissed:
            state.showLiveActivityInfo = false
            // 팝오버를 봤으므로 저장
            if !state.hasSeenLiveActivityInfo {
              state.hasSeenLiveActivityInfo = true
              return .run { [userDefaultsClient] _ in
                userDefaultsClient.markLiveActivityInfoSeen()
              }
            }
            return .none

          case .arrivalSharingSectionAppeared:
            // 본 적 있는지 확인
            return .run { [userDefaultsClient] send in
              let hasSeen = userDefaultsClient.hasSeenLiveActivityInfo
              await send(.internal(.liveActivityInfoSeenLoaded(hasSeen)))
            }
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
            state.promise.emoji = picks.first?.emoji
            return .none
            
          case .fetchGroupList:
            state.groupListState = .loading
            return .run { [groupClient, groupSummaries = state.groupSummaries] send in
              do {
                let groups: [GroupModel]
                if let groupSummaries, groupSummaries.isEmpty == false {
                  let ids = groupSummaries.map(\.id)
                  groups = try await groupClient.fetchGroupsByIds(ids)
                } else {
                  groups = try await groupClient.fetchGroups()
                }
                await send(.internal(.groupListResponse(.success(groups))))
              } catch {
                await send(.internal(.groupListResponse(.failure(error))))
              }
            }
            
          case .groupListResponse(.success(let groups)):
            state.groupListState = .loaded(groups)
            let groupIds = groups.map(\.id)
            return .send(.internal(.fetchPromiseCounts(groupIds)))
            
          case .groupListResponse(.failure(let error)):
            state.groupListState = .failed(error)
            return .none

          case .fetchPromiseCounts(let groupIds):
            return .run { [promiseClient] send in
              var counts: [String: Int] = [:]
              await withTaskGroup(of: (String, Int?).self) { group in
                for groupId in groupIds {
                  group.addTask {
                    let count = try? await promiseClient.getActivePromiseCount(groupId)
                    return (groupId, count)
                  }
                }
                for await (groupId, count) in group {
                  if let count {
                    counts[groupId] = count
                  }
                }
              }
              await send(.internal(.promiseCountsResponse(counts)))
            }

          case .promiseCountsResponse(let counts):
            state.groupPromiseCounts = counts
            return .none

          case .createPromiseResponse(.success(let id)):
            state.isCreatingPromise = false
            return .send(.delegate(.promiseCreated(id: id)))
            
          case .createPromiseResponse(.failure(let e)):
            state.isCreatingPromise = false
            state.creationError = e
            return .none

          case .liveActivityInfoSeenLoaded(let hasSeen):
            state.hasSeenLiveActivityInfo = hasSeen
            // 처음 보는 사용자에게 자동으로 팝오버 표시
            if !hasSeen {
              state.showLiveActivityInfo = true
            }
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
      PreviousStepButton {
        store.send(.view(.previousStep), animation: .default)
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

fileprivate struct PreviousStepButton: View {
  let action: () -> Void
  @State private var isPressed = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
        Text("이전")
          .font(.system(size: 16, weight: .semibold))
      }
      .foregroundColor(.primary)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color(.systemGray5))
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
    )
  }
}

fileprivate struct StepButton: View {
  let title: String
  var disabled: Bool
  var isLoading: Bool = false
  var action: () -> Void
  @State private var isPressed = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(0.8)
        } else {
          Image(systemName: title == "완료" ? "checkmark.circle.fill" : "arrow.right.circle.fill")
            .font(.system(size: 18))
        }

        Text(title)
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        LinearGradient(
          colors: disabled ? [Color(.systemGray4)] : [.blue, .purple],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: disabled ? .clear : .blue.opacity(0.3),
        radius: 12,
        x: 0,
        y: 6
      )
    }
    .scaleEffect(isPressed && !disabled ? 0.95 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed && !disabled)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in if !disabled { isPressed = true } }
        .onEnded { _ in isPressed = false }
    )
    .disabled(disabled)
    .animation(.easeInOut(duration: 0.2), value: disabled)
    .animation(.easeInOut(duration: 0.2), value: isLoading)
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
