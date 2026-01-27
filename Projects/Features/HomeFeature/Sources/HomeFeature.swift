// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Clients
import Lottie
import PromisoShared
import ResourceKit
import SharedFeature

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
      // MARK: User
      /// 현재 유저 정보 (RootTab과 참조 공유)
      @Shared var currentUser: UserPrivateModel

      /// 그룹 멤버 캐시 (전역 공유, groupId → members)
      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      var groupMembersCache: [String: [UserPublicModel]] = [:]

      // MARK: Data (단일 소스)
      /// 약속 데이터 (단일 API로 모두 로드)
      var promisesState: LoadingState<[PromiseModel]> = .idle

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      // MARK: Filter
      /// 선택된 그룹 ID (nil = 전체)
      var selectedGroupId: String? = nil

      /// 선택된 상태 필터
      var selectedStatusFilter: HomeModels.StatusFilter = .all

      // MARK: UI
      /// 스크롤 타겟
      var scrollTarget: HomeModels.ScrollTarget? = nil

      // MARK: Navigation
      /// 네비게이션 경로 (약속 상세)
      var path = StackState<Path.State>()

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
      }
    }

    // MARK: - Path (Navigation)

    @Reducer(state: .equatable)
    public enum Path {
      case promiseDetail(PromiseDetail.Feature)
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case path(StackActionOf<Path>)

      @CasePathable
      public enum View: Sendable {
        /// 화면 나타남
        case onAppear
        /// Pull to refresh
        case refreshTriggered
        /// 오늘 일정 약속 카드 탭
        case todayPromiseTapped(PromiseModel)
        /// 응답 필요 약속 카드 탭 (그룹 탭으로 이동)
        case pendingPromiseTapped(PromiseModel)
        /// 다가오는 약속 카드 탭
        case upcomingPromiseTapped(PromiseModel)
        /// "전체 보기" 버튼 탭
        case seeAllUpcomingTapped
        /// 그룹 필터 변경
        case groupFilterChanged(String?)
        /// 상태 필터 변경
        case statusFilterChanged(HomeModels.StatusFilter)
        /// 필터 초기화
        case resetFilters
        /// 스크롤 타겟 초기화
        case scrollTargetCleared
      }

      public enum Internal: Sendable {
        /// 데이터 조회
        case fetchPromises
        /// 데이터 응답
        case promisesResponse(Result<[PromiseModel], Error>)
        /// 응답 필요 섹션으로 스크롤
        case scrollToNeedResponse
      }

      public enum Delegate: Sendable {
        /// 약속 상세로 네비게이션 (legacy - 그룹 탭 이동용)
        case navigateToPromise(promiseId: String, groupId: String)
        /// 그룹 탭의 특정 약속으로 네비게이션 (응답 필요 카드에서)
        case navigateToGroupWithPromise(groupId: String, promiseId: String)
        /// 모든 약속 보기 화면으로 네비게이션
        case navigateToAllPromises
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 매번 최신 데이터로 갱신 (기존 데이터 유지하며 백그라운드 갱신)
            if !state.hasLoadedOnce {
              state.hasLoadedOnce = true
            }
            return .send(.internal(.fetchPromises))

          case .refreshTriggered:
            return .send(.internal(.fetchPromises))

          case .todayPromiseTapped(let promise):
            // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
            let groupMembers = state.groupMembersCache[promise.groupId]
            state.path.append(.promiseDetail(.init(
              promise: promise,
              currentUserId: state.currentUser.userId,
              groupMembers: groupMembers
            )))
            return .none

          case .pendingPromiseTapped(let promise):
            return .send(.delegate(.navigateToGroupWithPromise(
              groupId: promise.groupId,
              promiseId: promise.id
            )))

          case .upcomingPromiseTapped(let promise):
            // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
            let groupMembers = state.groupMembersCache[promise.groupId]
            state.path.append(.promiseDetail(.init(
              promise: promise,
              currentUserId: state.currentUser.userId,
              groupMembers: groupMembers
            )))
            return .none

          case .seeAllUpcomingTapped:
            return .send(.delegate(.navigateToAllPromises))

          case .groupFilterChanged(let groupId):
            state.selectedGroupId = groupId
            return .none

          case .statusFilterChanged(let filter):
            state.selectedStatusFilter = filter
            return .none

          case .resetFilters:
            state.selectedGroupId = nil
            state.selectedStatusFilter = .all
            return .none

          case .scrollTargetCleared:
            state.scrollTarget = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPromises:
            // 기존 데이터가 없을 때만 로딩 상태 표시 (깜빡임 방지)
            if state.promisesState.value == nil {
              state.promisesState = .loading
            }

            let groupIds = state.currentUser.groups.map { $0.id }

            guard !groupIds.isEmpty else {
              state.promisesState = .loaded([])
              return .none
            }

            return .run { [promiseClient] send in
              do {
                let promises = try await promiseClient.getUpcomingPromises(groupIds, 80)
                await send(.internal(.promisesResponse(.success(promises))))
              } catch {
                await send(.internal(.promisesResponse(.failure(error))))
              }
            }

          case .promisesResponse(let result):
            switch result {
            case .success(let promises):
              // 그룹 정보 매칭 (UserGroupInfo -> GroupModel 변환)
              let groupsDict = Dictionary(uniqueKeysWithValues: state.currentUser.groups.map { ($0.id, $0) })
              let promisesWithGroup = promises.map { promise -> PromiseModel in
                var updated = promise
                if let userGroupInfo = groupsDict[promise.groupId] {
                  updated.group = GroupModel(
                    id: userGroupInfo.id,
                    name: userGroupInfo.name,
                    imageUrl: userGroupInfo.imageUrl,
                    maxMembers: 0,
                    inviteCode: "",
                    createdBy: ""
                  )
                }
                return updated
              }
              state.promisesState = .loaded(promisesWithGroup)

              // 위젯 캐시 업데이트
              WidgetDataManager.savePromises(promisesWithGroup.toWidgetData())
            case .failure(let error):
              state.promisesState = .failed(error)
            }
            return .none

          case .scrollToNeedResponse:
            return .none
          }

        case .delegate:
          return .none

        // MARK: - Path Actions

        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          // 삭제 후 목록 새로고침
          return .send(.internal(.fetchPromises))

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated(let promise))))):
          // 수정된 약속 정보로 목록 업데이트
          if var promises = state.promisesState.value,
             let index = promises.firstIndex(where: { $0.id == promise.id }) {
            promises[index] = promise
            state.promisesState = .loaded(promises)
          }
          return .none

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
    }
  }
}

// MARK: - State Computed Properties

extension Home.Feature.State {
  /// 모든 약속 (필터 적용 전)
  var allPromises: [PromiseModel] {
    promisesState.value ?? []
  }

  /// 오늘의 확정 약속 (시간순 정렬)
  var todayPromises: [PromiseModel] {
    allPromises
      .filter { $0.isConfirmed && Calendar.current.isDateInToday($0.startAt) }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 응답 필요 약속 (투표 마감 임박순)
  var pendingPromises: [PromiseModel] {
    allPromises
      .filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed
      }
      .sorted { $0.votes.until < $1.votes.until }
  }

  /// 다가오는 확정 약속 (오늘 제외, 날짜순)
  var upcomingPromises: [PromiseModel] {
    allPromises
      .filter { $0.isConfirmed && !Calendar.current.isDateInToday($0.startAt) && !$0.isPast }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 필터링된 약속 (id 기반 안전)
  var filteredPromises: [PromiseModel] {
    var promises = allPromises

    // 그룹 필터 적용
    if let groupId = selectedGroupId {
      promises = promises.filter { $0.groupId == groupId }
    }

    // 상태 필터 적용
    switch selectedStatusFilter {
    case .needResponse:
      promises = promises.filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed
      }
    case .confirmed:
      promises = promises.filter { $0.isConfirmed && !$0.isPast }
    case .inProgress:
      promises = promises.filter {
        !$0.isConfirmed && !$0.isVotingClosed
      }
    case .all:
      promises = promises.filter { !$0.isPast }
    }

    return promises
  }

  /// Overview 데이터
  var overviewData: HomeModels.OverviewData {
    let nextPromise = todayPromises
      .filter { $0.startAt > Date() }
      .first

    return HomeModels.OverviewData(
      todayCount: todayPromises.count,
      nextPromise: nextPromise,
      needResponseCount: pendingPromises.count
    )
  }

  /// Critical Zone 데이터
  var criticalZoneData: HomeModels.CriticalZoneData? {
    let now = Date()

    if let livePromise = allPromises.first(where: { $0.isRealtimeShareable }) {
      return HomeModels.CriticalZoneData(reason: .liveActivity, promise: livePromise)
    }

    if let ongoingPromise = allPromises.first(where: { $0.isOngoing }) {
      return HomeModels.CriticalZoneData(reason: .inProgress, promise: ongoingPromise)
    }

    if let soonPromise = allPromises.first(where: {
      let interval = $0.startAt.timeIntervalSince(now)
      return interval > 0 && interval <= 1800
    }) {
      return HomeModels.CriticalZoneData(reason: .departureSoon, promise: soonPromise)
    }

    return nil
  }

  /// Timeline 데이터 (날짜별 그룹화)
  var timelineData: [HomeModels.TimelineSection] {
    let grouped = Dictionary(grouping: filteredPromises) { promise in
      Calendar.current.startOfDay(for: promise.startAt)
    }

    return grouped
      .sorted { $0.key < $1.key }
      .map { day, promises in
        HomeModels.TimelineSection(
          day: day,
          promises: promises.sorted { $0.startAt < $1.startAt }
        )
      }
  }

  /// 사용 가능한 그룹 목록
  var availableGroups: [HomeModels.GroupInfo] {
    currentUser.groups.map { HomeModels.GroupInfo(id: $0.id, name: $0.name) }
  }

  /// 로딩 중 여부
  var isLoading: Bool {
    promisesState.isLoading
  }

  /// 응답 필요 개수 (배지용)
  var pendingResponseCount: Int {
    overviewData.needResponseCount
  }
}

// MARK: - Root View

extension Home {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        ScrollView {
          LazyVStack(spacing: 20) {
            if store.isLoading && !store.hasLoadedOnce {
              loadingView
            } else if let error = store.promisesState.error {
              errorView(error: error)
            } else {
              // 오늘의 일정 카드
              TodayScheduleCard(
                promises: store.todayPromises,
                onPromiseTap: { promise in
                  store.send(.view(.todayPromiseTapped(promise)))
                }
              )
              .padding(.horizontal, 16)

              // 응답 필요 섹션 (있을 때만 표시)
              if !store.pendingPromises.isEmpty {
                PendingSection(
                  promises: store.pendingPromises,
                  onPromiseTap: { promise in
                    store.send(.view(.pendingPromiseTapped(promise)))
                  }
                )
                .padding(.horizontal, 16)
              }

              // 다가오는 약속 섹션
              UpcomingSection(
                promises: store.upcomingPromises,
                onPromiseTap: { promise in
                  store.send(.view(.upcomingPromiseTapped(promise)))
                },
                onSeeAllTap: {
                  store.send(.view(.seeAllUpcomingTapped))
                }
              )
              .padding(.horizontal, 16)
            }

            // 하단 여백 (FAB 및 탭바 공간)
            Color.clear
              .frame(height: 100)
          }
          .padding(.top, 8)
        }
        .refreshable {
          store.send(.view(.refreshTriggered))
        }
        .auroraBackground()
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
      } destination: { store in
        switch store.case {
        case .promiseDetail(let detailStore):
          PromiseDetail.RootView(store: detailStore)
        }
      }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      VStack(spacing: 16) {
        // 오늘의 일정 스켈레톤
        RoundedRectangle(cornerRadius: 20)
          .fill(Color(.systemGray6))
          .frame(height: 200)
          .shimmer()

        // 응답 필요 스켈레톤
        VStack(alignment: .leading, spacing: 12) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(width: 100, height: 24)

          HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .frame(width: 160, height: 140)
            }
          }
        }

        // 다가오는 약속 스켈레톤
        VStack(alignment: .leading, spacing: 12) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(width: 120, height: 24)

          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 14)
              .fill(Color(.systemGray6))
              .frame(height: 80)
          }
        }
      }
      .padding(.horizontal, 16)
      .shimmer()
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button("다시 시도") {
          store.send(.view(.refreshTriggered))
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }
  }
}
