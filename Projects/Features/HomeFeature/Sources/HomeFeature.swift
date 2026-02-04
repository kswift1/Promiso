// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Clients
import Lottie
import NotificationCenterFeature
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
    @Dependency(\.notificationClient) var notificationClient

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

      // MARK: Data (직접 쿼리 기반)
      /// 홈 약속 데이터 (Firestore 직접 쿼리)
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

      // MARK: Notification
      /// 안 읽은 알림 개수
      var unreadNotificationCount: Int = 0
      /// 알림 개수 조회 재시도 횟수
      var unreadCountRetryCount: Int = 0

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
      case notificationCenter(NotificationCenterFeature.NotificationCenter.Feature)
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
        /// 알림 버튼 탭
        case notificationButtonTapped
      }

      public enum Internal: Sendable {
        /// 홈 약속 조회 (Firestore 직접 쿼리)
        case fetchPromises
        /// 홈 약속 응답
        case promisesResponse(Result<[PromiseModel], Error>)
        /// 응답 필요 섹션으로 스크롤
        case scrollToNeedResponse
        /// 안 읽은 알림 개수 조회
        case fetchUnreadNotificationCount
        /// 안 읽은 알림 개수 응답
        case unreadNotificationCountResponse(Result<Int, Error>)
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
            // 첫 로드 표시
            if !state.hasLoadedOnce {
              state.hasLoadedOnce = true
            }
            // Firestore에서 직접 쿼리 (성공 시 알림 개수도 조회됨)
            return .send(.internal(.fetchPromises))

          case .refreshTriggered:
            // Pull-to-refresh도 동일하게 쿼리
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

          case .notificationButtonTapped:
            state.path.append(.notificationCenter(.init()))
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPromises:
            // 기존 데이터가 없을 때만 로딩 상태 표시 (깜빡임 방지)
            if state.promisesState.value == nil {
              state.promisesState = .loading
            }

            // 그룹이 없으면 빈 배열 반환
            let groupIds = state.currentUser.groups.map(\.id)
            guard !groupIds.isEmpty else {
              state.promisesState = .loaded([])
              return .none
            }

            return .run { [promiseClient] send in
              do {
                let promises = try await promiseClient.getHomePromises(groupIds, 10)
                await send(.internal(.promisesResponse(.success(promises))))
              } catch {
                await send(.internal(.promisesResponse(.failure(error))))
              }
            }

          case .promisesResponse(let result):
            switch result {
            case .success(let promises):
              state.promisesState = .loaded(promises)

              // 위젯 캐시 업데이트
              WidgetDataManager.savePromises(promises.toWidgetData())
              WidgetDataManager.reloadWidgets()

              // 약속 로드 성공 시 알림 개수도 조회
              return .send(.internal(.fetchUnreadNotificationCount))

            case .failure(let error):
              state.promisesState = .failed(error)
            }
            return .none

          case .scrollToNeedResponse:
            return .none

          case .fetchUnreadNotificationCount:
            let userId = state.currentUser.userId
            // userId가 아직 없으면 0.5초 후 재시도 (최대 3회)
            if userId.isEmpty {
              let retryCount = state.unreadCountRetryCount
              if retryCount < 3 {
                state.unreadCountRetryCount = retryCount + 1
                return .run { send in
                  try? await Task.sleep(for: .milliseconds(500))
                  await send(.internal(.fetchUnreadNotificationCount))
                }
              }
              return .none
            }
            state.unreadCountRetryCount = 0
            return .run { [notificationClient] send in
              do {
                let count = try await notificationClient.getUnreadCount(userId)
                await send(.internal(.unreadNotificationCountResponse(.success(count))))
              } catch {
                await send(.internal(.unreadNotificationCountResponse(.failure(error))))
              }
            }

          case .unreadNotificationCountResponse(let result):
            if case .success(let count) = result {
              state.unreadNotificationCount = count
            }
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
          // 삭제 후 다시 조회
          return .send(.internal(.fetchPromises))

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated)))):
          // 수정 후 다시 조회
          return .send(.internal(.fetchPromises))

        // MARK: - NotificationCenter Path Actions

        case .path(.element(id: _, action: .notificationCenter(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .notificationCenter(.delegate(.navigateToPromise(let promiseId, let groupId))))):
          _ = state.path.popLast()
          return .send(.delegate(.navigateToPromise(promiseId: promiseId, groupId: groupId)))

        case .path(.element(id: _, action: .notificationCenter(.delegate(.navigateToGroup(let groupId))))):
          _ = state.path.popLast()
          return .send(.delegate(.navigateToGroupWithPromise(groupId: groupId, promiseId: "")))

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
  /// 전체 약속 (nil이면 빈 배열)
  private var allPromises: [PromiseModel] {
    promisesState.value ?? []
  }

  /// 오늘 날짜 범위 (KST 기준)
  private var todayRange: (start: Date, end: Date) {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    return (startOfDay, endOfDay)
  }

  /// 오늘의 확정 약속 (오늘 + 확정, 최대 5개)
  var todayPromises: [PromiseModel] {
    let (startOfDay, endOfDay) = todayRange
    return allPromises
      .filter { $0.startAt >= startOfDay && $0.startAt < endOfDay && $0.isConfirmed }
      .prefix(5)
      .map { $0 }
  }

  /// 응답 필요 약속 (미응답 + 투표 마감 전, 마감 임박순, 최대 5개)
  var pendingPromises: [PromiseModel] {
    let userId = currentUser.userId
    return allPromises
      .filter { $0.myVoteStatus(userId: userId) == .pending && !$0.isVotingClosed }
      .sorted { lhs, rhs in
        let lhsDeadline = lhs.votes.until ?? .distantFuture
        let rhsDeadline = rhs.votes.until ?? .distantFuture
        return lhsDeadline < rhsDeadline
      }
      .prefix(5)
      .map { $0 }
  }

  /// 다가오는 확정 약속 (내일 이후 + 확정, 최대 10개)
  var upcomingPromises: [PromiseModel] {
    let (_, endOfDay) = todayRange
    return allPromises
      .filter { $0.startAt >= endOfDay && $0.isConfirmed }
      .prefix(10)
      .map { $0 }
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

  /// Critical Zone 데이터 (실시간 계산 필요)
  var criticalZoneData: HomeModels.CriticalZoneData? {
    let now = Date()

    // todayPromises에서 실시간 상태 계산
    if let livePromise = todayPromises.first(where: { $0.isRealtimeShareable }) {
      return HomeModels.CriticalZoneData(reason: .liveActivity, promise: livePromise)
    }

    if let ongoingPromise = todayPromises.first(where: { $0.isOngoing }) {
      return HomeModels.CriticalZoneData(reason: .inProgress, promise: ongoingPromise)
    }

    if let soonPromise = todayPromises.first(where: {
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
    pendingPromises.count
  }
}

// MARK: - Root View

extension Home {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.scenePhase) private var scenePhase

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
              badgeCount: store.unreadNotificationCount,
              action: {
                store.send(.view(.notificationButtonTapped))
              }
            )
            .id(store.unreadNotificationCount)
          }
        }
        .onAppear {
          store.send(.view(.onAppear))
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
          // background → active 시 다시 로드
          if oldPhase == .background && newPhase == .active {
            store.send(.view(.onAppear))
          }
        }
      } destination: { store in
        switch store.case {
        case .promiseDetail(let detailStore):
          PromiseDetail.RootView(store: detailStore)
        case .notificationCenter(let notificationStore):
          NotificationCenterFeature.NotificationCenter.RootView(store: notificationStore)
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
