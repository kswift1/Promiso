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
      /// 선택된 상태 필터
      var selectedStatusFilter: StatusFilter = .all

      // MARK: UI
      /// 스크롤 타겟
      var scrollTarget: ScrollTarget? = nil

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
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
        /// Pull to refresh
        case refreshTriggered
        /// 약속 카드 탭
        case promiseTapped(String)  // promiseId만 전달 (안전성)
        /// 응답 필요 배너 탭
        case needResponseBannerTapped
        /// 상태 필터 변경
        case statusFilterChanged(StatusFilter)
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
        /// 약속 상세로 네비게이션
        case navigateToPromise(promiseId: String, groupId: String)
        /// 그룹 탭으로 네비게이션
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

          case .statusFilterChanged(let filter):
            state.selectedStatusFilter = filter
            return .none

          case .resetFilters:
            state.selectedStatusFilter = .all
            return .none

          case .scrollTargetCleared:
            state.scrollTarget = nil
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
}

// MARK: - State Computed Properties

extension Home.Feature.State {
  /// 모든 약속 (필터 적용 전)
  var allPromises: [PromiseModel] {
    promisesState.value ?? []
  }

  /// 필터링된 약속 (상태 필터만 적용)
  var filteredPromises: [PromiseModel] {
    var promises = allPromises

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

  /// Hero 데이터 (홈 상단 "지금 가장 중요한 약속")
  /// 우선순위: departureSoon > todayNext > needResponse
  /// LiveActivity는 BottomAccessoryView에서 처리하므로 제외
  var heroData: HeroData? {
    let now = Date()
    let calendar = Calendar.current

    // 1순위: T-30분 이내 임박 약속
    let departureSoonPromises = allPromises
      .filter { $0.isConfirmed && !$0.isPast }
      .filter {
        let interval = $0.startAt.timeIntervalSince(now)
        return interval > 0 && interval <= 1800  // 30분 = 1800초
      }
      .sorted { $0.startAt < $1.startAt }

    if let soonPromise = departureSoonPromises.first {
      return HeroData(priority: .departureSoon, promise: soonPromise)
    }

    // 2순위: 오늘 가장 가까운 확정 약속
    let todayConfirmedPromises = allPromises
      .filter { $0.isConfirmed && !$0.isPast }
      .filter { calendar.isDateInToday($0.startAt) }
      .filter { $0.startAt > now }
      .sorted { $0.startAt < $1.startAt }

    if let todayPromise = todayConfirmedPromises.first {
      return HeroData(priority: .todayNext, promise: todayPromise)
    }

    // 3순위: 응답 필요한 약속 중 가장 빠른 것
    let needResponsePromises = allPromises
      .filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed
      }
      .sorted { $0.startAt < $1.startAt }

    if let needResponsePromise = needResponsePromises.first {
      return HeroData(priority: .needResponse, promise: needResponsePromise)
    }

    return nil
  }

  /// Quick Insights 데이터
  var quickInsightsData: QuickInsightsData {
    let calendar = Calendar.current
    let now = Date()
    let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
    let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

    let todayCount = allPromises
      .filter { $0.isConfirmed && calendar.isDateInToday($0.startAt) && !$0.isPast }
      .count

    let needResponseCount = allPromises
      .filter { $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed }
      .count

    let thisWeekCount = allPromises
      .filter { $0.isConfirmed && $0.startAt >= now && $0.startAt < weekEnd }
      .count

    return QuickInsightsData(
      todayCount: todayCount,
      needResponseCount: needResponseCount,
      thisWeekCount: thisWeekCount
    )
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

  /// 그룹이 있는지 여부
  var hasGroups: Bool {
    !currentUser.groups.isEmpty
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
    @State private var showFAB: Bool = true

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        ScrollViewReader { proxy in
          LazyVStack(spacing: 16, pinnedViews: []) {
            // Hero Section (지금 가장 중요한 약속)
            if let heroData = store.heroData {
              HeroCard(
                data: heroData,
                onTap: {
                  store.send(.view(.promiseTapped(heroData.promise.id)))
                },
                onActionTap: {
                  store.send(.view(.promiseTapped(heroData.promise.id)))
                }
              )
              .padding(.horizontal, 16)
              .padding(.top, 8)
            }

            // Quick Insights (가로 스크롤)
            QuickInsightsSection(
              data: store.quickInsightsData,
              onInsightTap: { insightType in
                handleInsightTap(insightType)
              }
            )
            .padding(.top, store.heroData == nil ? 8 : 0)

            // 상태 필터 (Smart Pills)
            SmartPillsFilter(
              selection: Binding(
                get: { store.selectedStatusFilter },
                set: { store.send(.view(.statusFilterChanged($0))) }
              ),
              counts: filterCounts
            )

            // Timeline
            if store.isLoading && !store.hasLoadedOnce {
              loadingView
            } else if let error = store.promisesState.error {
              errorView(error: error)
            } else if store.filteredPromises.isEmpty {
              // Warm Empty State
              if store.allPromises.isEmpty {
                WarmEmptyState(
                  style: store.hasGroups ? .noPromises : .noGroups,
                  onPrimaryAction: {
                    // TODO: 새 약속 만들기 또는 그룹 찾기
                  }
                )
              } else {
                WarmEmptyState(
                  style: .noFilterResults,
                  onPrimaryAction: {
                    store.send(.view(.resetFilters))
                  }
                )
              }
            } else {
              // Timeline 섹션들
              ForEach(store.timelineData) { section in
                TimelineSectionView(
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

            // 하단 여백 (FAB 공간)
            Color.clear
              .frame(height: 100)
          }
          .onChange(of: store.scrollTarget) { _, target in
            guard let target = target else { return }

            withAnimation {
              switch target {
              case .needResponse:
                if let firstSection = store.timelineData.first {
                  proxy.scrollTo(firstSection.id, anchor: .top)
                }
              case .date(let date):
                let dayKey = dayKeyString(from: date)
                proxy.scrollTo(dayKey, anchor: .top)
              }
            }

            store.send(.view(.scrollTargetCleared))
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
      .fabOverlay(isVisible: showFAB) {
        // TODO: 새 약속 만들기 화면으로 이동
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Handlers

    private func handleInsightTap(_ type: InsightType) {
      switch type {
      case .today:
        store.send(.view(.statusFilterChanged(.confirmed)))
      case .needResponse:
        store.send(.view(.statusFilterChanged(.needResponse)))
      case .thisWeek:
        store.send(.view(.statusFilterChanged(.all)))
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

    private func dayKeyString(from date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter.string(from: date)
    }
  }
}
