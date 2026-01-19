// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Lottie
import ResourceKit

// MARK: - Feature Namespace

/// Home Feature 컴포넌트를 위한 Namespace
public enum Home {}

// MARK: - Feature Implementation

extension Home {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 유저 정보
      var currentUser: UserPrivateModel

      /// 오늘의 약속 로딩 상태
      var todaysPromisesState: LoadingState<[PromiseModel]> = .idle

      /// 응답 필요한 약속 로딩 상태
      var pendingResponsesState: LoadingState<[PromiseModel]> = .idle

      /// 다가오는 약속 로딩 상태
      var upcomingPromisesState: LoadingState<[PromiseModel]> = .idle

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // MARK: - Computed Properties

      /// 오늘 확정된 약속 (시간순)
      var todaysPromises: [PromiseModel] {
        (todaysPromisesState.value ?? [])
          .filter { $0.isConfirmed }
          .sorted { $0.startAt < $1.startAt }
      }

      /// 응답 필요한 약속
      var pendingResponses: [PromiseModel] {
        (pendingResponsesState.value ?? [])
          .sorted { $0.votes.until < $1.votes.until }
      }

      /// 다가오는 약속 (확정된 것만)
      var upcomingPromises: [PromiseModel] {
        (upcomingPromisesState.value ?? [])
          .filter { $0.isConfirmed }
          .sorted { $0.startAt < $1.startAt }
      }

      /// 전체 로딩 중 여부
      var isLoading: Bool {
        todaysPromisesState.isLoading ||
        pendingResponsesState.isLoading ||
        upcomingPromisesState.isLoading
      }

      /// 응답 필요 개수 (배지용)
      var pendingResponseCount: Int {
        pendingResponses.count
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        /// 화면 나타남
        case onAppear
        /// 약속 카드 탭
        case promiseTapped(PromiseModel)
        /// 응답하기 버튼 탭
        case respondTapped(PromiseModel)
        /// Pull to refresh
        case refreshTriggered
      }

      public enum Internal: Sendable {
        case fetchAllData
        case todaysPromisesResponse(Result<[PromiseModel], Error>)
        case pendingResponsesResponse(Result<[PromiseModel], Error>)
        case upcomingPromisesResponse(Result<[PromiseModel], Error>)
      }

      public enum Delegate: Sendable {
        case navigateToGroup(groupId: String)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard !state.hasLoadedOnce else { return .none }
            state.hasLoadedOnce = true
            return .send(.internal(.fetchAllData))

          case .promiseTapped(let promise):
            return .send(.delegate(.navigateToGroup(groupId: promise.groupId)))

          case .respondTapped(let promise):
            return .send(.delegate(.navigateToGroup(groupId: promise.groupId)))

          case .refreshTriggered:
            return .send(.internal(.fetchAllData))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchAllData:
            state.todaysPromisesState = .loading
            state.pendingResponsesState = .loading
            state.upcomingPromisesState = .loading

            let userId = state.currentUser.userId
            let groupIds = state.currentUser.groups.map { $0.id }
            let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))

            // 그룹이 없으면 빈 결과 반환
            guard !groupIds.isEmpty else {
              state.todaysPromisesState = .loaded([])
              state.pendingResponsesState = .loaded([])
              state.upcomingPromisesState = .loaded([])
              return .none
            }

            return .run { [promiseClient] send in
              do {
                // 1. 오늘의 약속 조회
                async let todayPromisesTask = promiseClient.getTodayPromises(groupIds)
                // 2. 다가오는 약속 조회
                async let upcomingPromisesTask = promiseClient.getUpcomingPromises(groupIds, 10)

                let (todayPromises, allUpcoming) = try await (todayPromisesTask, upcomingPromisesTask)

                // 오늘의 약속 응답
                await send(.internal(.todaysPromisesResponse(.success(todayPromises))))

                // 응답 필요: pending 상태, 투표 마감 전
                let pending = allUpcoming.filter { promise in
                  promise.myVoteStatus(userId: userId) == .pending && !promise.isVotingClosed
                }
                await send(.internal(.pendingResponsesResponse(.success(pending))))

                // 다가오는 약속: 내일 이후, 확정된 것
                let upcoming = allUpcoming.filter { $0.startAt >= tomorrow && $0.isConfirmed }
                await send(.internal(.upcomingPromisesResponse(.success(upcoming))))

              } catch {
                await send(.internal(.todaysPromisesResponse(.failure(error))))
                await send(.internal(.pendingResponsesResponse(.failure(error))))
                await send(.internal(.upcomingPromisesResponse(.failure(error))))
              }
            }

          case .todaysPromisesResponse(let result):
            switch result {
            case .success(let promises):
              state.todaysPromisesState = .loaded(promises)
            case .failure(let error):
              state.todaysPromisesState = .failed(error)
            }
            return .none

          case .pendingResponsesResponse(let result):
            switch result {
            case .success(let promises):
              state.pendingResponsesState = .loaded(promises)
            case .failure(let error):
              state.pendingResponsesState = .failed(error)
            }
            return .none

          case .upcomingPromisesResponse(let result):
            switch result {
            case .success(let promises):
              state.upcomingPromisesState = .loaded(promises)
            case .failure(let error):
              state.upcomingPromisesState = .failed(error)
            }
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        LazyVStack(spacing: 24) {
          // 오늘 확정된 약속
          TodayPromiseSection(store: store)

          // 응답 필요한 제안
          PendingResponseSection(store: store)

          // 다가오는 약속
          UpcomingPromiseSection(store: store)
        }
        .padding(.top, 8)
      }
      .refreshable {
        store.send(.view(.refreshTriggered))
      }
      .auroraBackground()
      .navigationTitle("오늘의 일정")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NotificationButton(
            badgeCount: store.pendingResponseCount,
            action: { }
          )
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}
