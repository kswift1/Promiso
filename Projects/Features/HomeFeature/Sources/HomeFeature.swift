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
      // MARK: User
      /// 현재 유저 정보
      var currentUser: UserPrivateModel

      // MARK: Data (단일 소스)
      /// 약속 데이터 (단일 API로 모두 로드)
      var promisesState: LoadingState<[PromiseModel]> = .idle

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      // MARK: Filter
      /// 선택된 그룹 ID (nil = 전체)
      var selectedGroupId: String? = nil

      /// 선택된 상태 필터
      var selectedStatusFilter: StatusFilter = .all

      // MARK: UI
      /// 스크롤 타겟
      var scrollTarget: ScrollTarget? = nil

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }
    }
  }
}

// MARK: - State Computed Properties

extension Home.Feature.State {
    /// 모든 약속 (필터 적용 전)
    var allPromises: [PromiseModel] {
      promisesState.value ?? []
    }

    /// 필터링된 약속 (id 기반 안전)
    var filteredPromises: [PromiseModel] {
      var promises = allPromises

      // 그룹 필터 적용 (id 기반)
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
    var overviewData: OverviewData {
      let today = Calendar.current.startOfDay(for: Date())

      let todayPromises = allPromises.filter {
        $0.isConfirmed &&
        Calendar.current.isDate($0.startAt, inSameDayAs: Date())
      }

      let needResponsePromises = allPromises.filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending &&
        !$0.isVotingClosed
      }

      let nextPromise = todayPromises
        .filter { $0.startAt > Date() }
        .sorted { $0.startAt < $1.startAt }
        .first

      return OverviewData(
        todayCount: todayPromises.count,
        nextPromise: nextPromise,
        needResponseCount: needResponsePromises.count
      )
    }

    /// Critical Zone 데이터 (조건부, 우선순위: liveActivity > inProgress > departureSoon)
    var criticalZoneData: CriticalZoneData? {
      let now = Date()

      // LiveActivity 공유 중 (최우선)
      if let livePromise = allPromises.first(where: { $0.isRealtimeShareable }) {
        return CriticalZoneData(reason: .liveActivity, promise: livePromise)
      }

      // 진행 중
      if let ongoingPromise = allPromises.first(where: { $0.isOngoing }) {
        return CriticalZoneData(reason: .inProgress, promise: ongoingPromise)
      }

      // 출발 임박 (30분 전)
      if let soonPromise = allPromises.first(where: {
        let interval = $0.startAt.timeIntervalSince(now)
        return interval > 0 && interval <= 1800  // 30분 = 1800초
      }) {
        return CriticalZoneData(reason: .departureSoon, promise: soonPromise)
      }

      return nil
    }

    /// Timeline 데이터 (날짜별 그룹화, dayKey로 안전)
    var timelineData: [TimelineSection] {
      let grouped = Dictionary(grouping: filteredPromises) { promise in
        Calendar.current.startOfDay(for: promise.startAt)
      }

      return grouped
        .sorted { $0.key < $1.key }
        .map { day, promises in
          TimelineSection(
            day: day,  // startOfDay로 정규화
            promises: promises.sorted { $0.startAt < $1.startAt }
          )
        }
    }

    /// 사용 가능한 그룹 목록
    var availableGroups: [GroupInfo] {
      currentUser.groups.map { GroupInfo(id: $0.id, name: $0.name) }
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

// MARK: - Feature (continued)

extension Home.Feature {
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
        /// Pull to refresh
        case refreshTriggered
        /// 약속 카드 탭
        case promiseTapped(String)  // promiseId만 전달 (안전성)
        /// 응답 필요 배너 탭
        case needResponseBannerTapped
        /// 그룹 필터 변경
        case groupFilterChanged(String?)  // groupId (nil = 전체)
        /// 상태 필터 변경
        case statusFilterChanged(StatusFilter)
        /// 필터 초기화
        case resetFilters  // group nil + status .all
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
        /// 약속 상세로 네비게이션
        case navigateToPromise(promiseId: String, groupId: String)
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
            return .send(.internal(.fetchPromises))

          case .refreshTriggered:
            return .send(.internal(.fetchPromises))

          case .promiseTapped(let promiseId):
            // promiseId로 약속 찾기
            guard let promise = state.allPromises.first(where: { $0.id == promiseId }) else {
              return .none
            }
            return .send(.delegate(.navigateToPromise(
              promiseId: promiseId,
              groupId: promise.groupId
            )))

          case .needResponseBannerTapped:
            // 필터를 응답 필요로 변경
            state.selectedStatusFilter = .needResponse

            // 응답 필요한 첫 번째 날짜로 스크롤
            if let firstSection = state.timelineData.first {
              state.scrollTarget = .date(firstSection.day)
            }
            return .none

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
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPromises:
            state.promisesState = .loading

            let groupIds = state.currentUser.groups.map { $0.id }

            // 그룹이 없으면 빈 결과 반환
            guard !groupIds.isEmpty else {
              state.promisesState = .loaded([])
              return .none
            }

            return .run { [promiseClient] send in
              do {
                // 단일 API 호출 (80개 limit)
                let promises = try await promiseClient.getUpcomingPromises(groupIds, 80)
                await send(.internal(.promisesResponse(.success(promises))))
              } catch {
                await send(.internal(.promisesResponse(.failure(error))))
              }
            }

          case .promisesResponse(let result):
            switch result {
            case .success(let promises):
              state.promisesState = .loaded(promises)
            case .failure(let error):
              state.promisesState = .failed(error)
            }
            return .none

          case .scrollToNeedResponse:
            // 스크롤 처리는 View에서 ScrollViewReader로 구현
            return .none
          }

        case .delegate:
          return .none
        }
      }
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
      ScrollView {
        ScrollViewReader { proxy in
          LazyVStack(spacing: 20, pinnedViews: []) {
            // Overview Section
            OverviewSection(
              overviewData: store.overviewData,
              criticalZoneData: store.criticalZoneData,
              onNeedResponseTap: {
                store.send(.view(.needResponseBannerTapped))
              },
              onCriticalZoneTap: {
                if let criticalData = store.criticalZoneData {
                  store.send(.view(.promiseTapped(criticalData.promise.id)))
                }
              }
            )
            .padding(.top, 8)

            // Filters
            VStack(spacing: 8) {
              // 그룹 필터
              GroupFilterBar(
                groups: store.availableGroups,
                selectedGroupId: $store.selectedGroupId
              )

              // 상태 필터
              CategoryFilterBar<StatusFilter>(
                selection: $store.selectedStatusFilter,
                counts: filterCounts
              )
            }

            // Timeline
            if store.isLoading && !store.hasLoadedOnce {
              // 첫 로딩 - 스켈레톤
              loadingView
            } else if let error = store.promisesState.error {
              // 에러 상태
              errorView(error: error)
            } else if store.filteredPromises.isEmpty {
              // 빈 상태
              emptyStateView
            } else {
              // Timeline 섹션들
              ForEach(store.timelineData) { section in
                TimelineSection(
                  section: section,
                  currentUserId: store.currentUser.userId,
                  onPromiseTap: { promise in
                    store.send(.view(.promiseTapped(promise.id)))
                  }
                )
                .padding(.horizontal, 16)
                .id(section.id)
              }
            }

            // 하단 여백
            Color.clear
              .frame(height: 80)
          }
          .onChange(of: store.scrollTarget) { _, target in
            guard let target = target else { return }

            withAnimation {
              switch target {
              case .needResponse:
                // 응답 필요한 첫 번째 섹션으로 스크롤
                if let firstSection = store.timelineData.first {
                  proxy.scrollTo(firstSection.id, anchor: .top)
                }
              case .date(let date):
                // 특정 날짜로 스크롤
                let dayKey = dayKeyString(from: date)
                proxy.scrollTo(dayKey, anchor: .top)
              }
            }

            // 스크롤 타겟 초기화
            store.scrollTarget = nil
          }
        }
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

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      LazyVStack(spacing: 12) {
        ForEach(0..<3, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemGray6))
            .frame(height: 80)
            .shimmer()
        }
      }
      .padding(.horizontal, 16)
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

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
      VStack(spacing: 16) {
        Image(systemName: emptyStateIcon)
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text(emptyStateTitle)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(emptyStateMessage)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)

        if store.selectedGroupId != nil || store.selectedStatusFilter != .all {
          Button("필터 초기화") {
            store.send(.view(.resetFilters))
          }
          .buttonStyle(.bordered)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }

    // MARK: - Computed Properties

    private var filterCounts: [StatusFilter: Int] {
      let all = store.allPromises.filter { !$0.isPast }

      return [
        .all: all.count,
        .needResponse: all.filter {
          $0.myVoteStatus(userId: store.currentUser.userId) == .pending && !$0.isVotingClosed
        }.count,
        .confirmed: all.filter { $0.isConfirmed }.count,
        .inProgress: all.filter { !$0.isConfirmed && !$0.isVotingClosed }.count
      ]
    }

    private var emptyStateIcon: String {
      if store.allPromises.isEmpty {
        return "calendar"
      } else {
        return "line.3.horizontal.decrease.circle"
      }
    }

    private var emptyStateTitle: String {
      if store.allPromises.isEmpty {
        return "약속이 없어요"
      } else {
        return "필터 결과가 없어요"
      }
    }

    private var emptyStateMessage: String {
      if store.allPromises.isEmpty {
        return "새로운 약속을 만들어보세요\n+ 버튼을 눌러 시작할 수 있어요"
      } else {
        return "선택한 필터 조건에 맞는\n약속이 없습니다"
      }
    }

    private func dayKeyString(from date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter.string(from: date)
    }
  }
}
