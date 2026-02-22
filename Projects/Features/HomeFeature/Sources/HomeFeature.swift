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
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.weatherClient) var weatherClient

    public init() {}

    // MARK: - CancelID

    private enum CancelID {
      case overlayDotsAnimation
    }

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

      /// 개인 일정 데이터
      var personalEventsState: LoadingState<[PersonalEventModel]> = .idle

      /// 날씨 캐시 (scheduleId → WeatherInfo)
      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

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
      /// 화면 상단/하단 토스트 메시지
      var toastMessage: ToastMessage?

      // MARK: Calendar Overlay
      /// 캘린더 오버레이 표시 여부
      var showCalendarOverlay: Bool = false
      /// 오버레이 닫기 애니메이션 진행 중
      var isCalendarDismissing: Bool = false
      /// 오버레이 캘린더 현재 월
      var overlayCalendarMonth: Date = Date()
      /// 오버레이 캘린더 선택 날짜
      var overlaySelectedDate: Date = Date()
      /// 오버레이 인디케이터 dot 표시 여부 (지연 애니메이션)
      var overlayDotsVisible: Bool = false

      // MARK: Notification
      /// 안 읽은 알림 개수
      var unreadNotificationCount: Int = 0

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
      case personalEventDetail(PersonalEventDetail.Feature)
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
        /// 알림 배지 새로고침 (외부에서 호출)
        case refreshNotificationBadge
        /// 개인 일정 카드 탭
        case personalEventTapped(PersonalEventModel)
        /// 토스트 닫힘
        case toastDismissed
        /// 캘린더 오버레이 열기
        case calendarOverlayOpened
        /// 캘린더 오버레이 닫기
        case calendarOverlayClosed
        /// 오버레이 캘린더 날짜 선택
        case overlayDateSelected(Date)
        /// 오버레이 캘린더 이전 월
        case overlayPreviousMonth
        /// 오버레이 캘린더 다음 월
        case overlayNextMonth
        /// 오버레이 dots 애니메이션 완료
        case overlayDotsAppeared
        /// 오버레이 닫기 애니메이션 완료
        case overlayDismissCompleted
      }

      @CasePathable
      public enum Internal: Sendable {
        /// 홈 약속 조회 (Firestore 직접 쿼리)
        case fetchPromises
        /// 홈 약속 응답
        case promisesResponse(Result<[PromiseModel], Error>)
        /// 개인 일정 조회
        case fetchPersonalEvents
        /// 개인 일정 응답
        case personalEventsResponse(Result<[PersonalEventModel], Error>)
        /// 응답 필요 섹션으로 스크롤
        case scrollToNeedResponse
        /// 안 읽은 알림 개수 조회
        case fetchUnreadNotificationCount
        /// 안 읽은 알림 개수 응답
        case unreadNotificationCountResponse(Result<Int, Error>)
        /// 날씨 정보 조회
        case fetchWeather
        /// 날씨 정보 응답 (scheduleId → WeatherInfo)
        case weatherResponse(String, Result<WeatherInfo, Error>)
      }

      @CasePathable
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
            // Firestore에서 직접 쿼리 (약속 + 개인 일정 병렬)
            return .merge(
              .send(.internal(.fetchPromises)),
              .send(.internal(.fetchPersonalEvents))
            )

          case .refreshTriggered:
            // Pull-to-refresh도 동일하게 쿼리
            return .merge(
              .send(.internal(.fetchPromises)),
              .send(.internal(.fetchPersonalEvents))
            )

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

          case .refreshNotificationBadge:
            return .send(.internal(.fetchUnreadNotificationCount))

          case .personalEventTapped(let event):
            state.path.append(.personalEventDetail(.init(event: event)))
            return .none

          case .toastDismissed:
            state.toastMessage = nil
            return .none

          case .calendarOverlayOpened:
            state.overlayCalendarMonth = Date()
            state.overlaySelectedDate = Date()
            state.overlayDotsVisible = false
            state.showCalendarOverlay = true
            return .run { send in
              try await Task.sleep(nanoseconds: 350_000_000)
              await send(.view(.overlayDotsAppeared))
            }
            .cancellable(id: CancelID.overlayDotsAnimation)

          case .calendarOverlayClosed:
            state.showCalendarOverlay = false
            state.overlayDotsVisible = false
            state.isCalendarDismissing = false
            return .cancel(id: CancelID.overlayDotsAnimation)

          case .overlayDateSelected(let date):
            state.overlaySelectedDate = date
            return .none

          case .overlayPreviousMonth:
            if let prev = Calendar.current.date(byAdding: .month, value: -1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = prev
            }
            return .none

          case .overlayNextMonth:
            if let next = Calendar.current.date(byAdding: .month, value: 1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = next
            }
            return .none

          case .overlayDotsAppeared:
            state.overlayDotsVisible = true
            return .none

          case .overlayDismissCompleted:
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
              // 그룹 정보 매핑 (UserGroupInfo → GroupModel 변환)
              let groupsDict = Dictionary(
                uniqueKeysWithValues: state.currentUser.groups.map { ($0.id, $0) }
              )
              let promisesWithGroup = promises.map { promise in
                var mutablePromise = promise
                if let groupInfo = groupsDict[promise.groupId] {
                  mutablePromise.group = GroupModel(
                    id: groupInfo.id,
                    name: groupInfo.name,
                    imageUrl: groupInfo.imageUrl,
                    maxMembers: 0,
                    inviteCode: "",
                    createdBy: ""
                  )
                }
                return mutablePromise
              }
              state.promisesState = .loaded(promisesWithGroup)

              // 위젯 캐시 업데이트 (확정된 약속만)
              WidgetDataManager.savePromises(
                promisesWithGroup.filter(\.isConfirmed).toWidgetData()
              )
              WidgetDataManager.reloadWidgets()

              // 약속 로드 성공 시 알림 개수 + 날씨 조회
              return .merge(
                .send(.internal(.fetchUnreadNotificationCount)),
                .send(.internal(.fetchWeather))
              )

            case .failure(let error):
              state.promisesState = .failed(error)
            }
            return .none

          case .fetchPersonalEvents:
            return .run { [personalEventClient] send in
              do {
                let events = try await personalEventClient.getActiveEvents(20)
                await send(.internal(.personalEventsResponse(.success(events))))
              } catch {
                await send(.internal(.personalEventsResponse(.failure(error))))
              }
            }

          case .personalEventsResponse(let result):
            switch result {
            case .success(let events):
              state.personalEventsState = .loaded(events)
              WidgetDataManager.savePersonalEvents(events.toWidgetData())
              WidgetDataManager.reloadWidgets()
            case .failure:
              // 개인 일정 실패 시 빈 배열로 처리 (그룹 약속은 정상 표시)
              state.personalEventsState = .loaded([])
            }
            return .none

          case .scrollToNeedResponse:
            return .none

          case .fetchUnreadNotificationCount:
            let userId = state.currentUser.userId
            guard !userId.isEmpty else { return .none }
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

          case .fetchWeather:
            let promises = state.allPromises.filter { promise in
              let hasLat = promise.location?.latitude != nil
              let hasLng = promise.location?.longitude != nil
              let notPast = !promise.isPast
              return hasLat && hasLng && notPast
            }
            let events = (state.personalEventsState.value ?? []).filter { event in
              event.location?.latitude != nil &&
              event.location?.longitude != nil
            }

            // 예보 범위(10일) 밖 필터링 (단기 5일 + 중기 10일)
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)

            struct LocationKey: Hashable {
              let lat: Double
              let lng: Double
              let hour: Int
            }

            var seen = Set<LocationKey>()
            var effects: [Effect<Action>] = []

            for promise in promises where promise.startAt < maxDate {
              guard let lat = promise.location?.latitude,
                    let lng = promise.location?.longitude else { continue }
              let hour = Calendar.current.component(.hour, from: promise.startAt)
              let key = LocationKey(
                lat: (lat * 100).rounded() / 100,
                lng: (lng * 100).rounded() / 100,
                hour: hour
              )
              guard seen.insert(key).inserted else { continue }

              let id = promise.id
              let date = promise.startAt
              effects.append(.run { [weatherClient] send in
                do {
                  let info = try await weatherClient.getWeather(lat, lng, date)
                  await send(.internal(.weatherResponse(id, .success(info))))
                } catch {
                  await send(.internal(.weatherResponse(id, .failure(error))))
                }
              })
            }

            for event in events where event.startAt < maxDate {
              guard let lat = event.location?.latitude,
                    let lng = event.location?.longitude else { continue }
              let hour = Calendar.current.component(.hour, from: event.startAt)
              let key = LocationKey(
                lat: (lat * 100).rounded() / 100,
                lng: (lng * 100).rounded() / 100,
                hour: hour
              )
              guard seen.insert(key).inserted else { continue }

              let id = event.id
              let date = event.startAt
              effects.append(.run { [weatherClient] send in
                do {
                  let info = try await weatherClient.getWeather(lat, lng, date)
                  await send(.internal(.weatherResponse(id, .success(info))))
                } catch {
                  await send(.internal(.weatherResponse(id, .failure(error))))
                }
              })
            }

            return effects.isEmpty ? .none : .merge(effects)

          case .weatherResponse(let scheduleId, let result):
            if case .success(let info) = result {
              state.$weatherCache.withLock { $0[scheduleId] = info }
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

        // MARK: - PersonalEventDetail Path Actions

        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventDeleted)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchPersonalEvents))

        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventUpdated)))):
          return .send(.internal(.fetchPersonalEvents))

        // MARK: - NotificationCenter Path Actions

        case .path(.element(id: _, action: .notificationCenter(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchUnreadNotificationCount))

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
  var allPromises: [PromiseModel] {
    promisesState.value ?? []
  }

  /// 전체 개인 일정 (nil이면 빈 배열)
  private var allPersonalEvents: [PersonalEventModel] {
    personalEventsState.value ?? []
  }

  /// 오늘 날짜 범위 (KST 기준)
  private var todayRange: (start: Date, end: Date) {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    return (startOfDay, endOfDay)
  }

  /// 오늘의 확정 약속 (오늘 + 확정) - criticalZoneData 등에서 사용
  var todayPromises: [PromiseModel] {
    let (startOfDay, endOfDay) = todayRange
    return allPromises
      .filter { $0.startAt >= startOfDay && $0.startAt < endOfDay && $0.isConfirmed }
  }

  /// 오늘의 통합 일정 (그룹 약속 + 개인 일정, startAt 정렬)
  var todayScheduleItems: [HomeModels.ScheduleItem] {
    let (startOfDay, endOfDay) = todayRange
    let promiseItems = allPromises
      .filter { $0.startAt >= startOfDay && $0.startAt < endOfDay && $0.isConfirmed }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = allPersonalEvents
      .filter { $0.startAt >= startOfDay && $0.startAt < endOfDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems).sorted { $0.startAt < $1.startAt }
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

  /// 다가오는 확정 약속 (내일 이후 + 확정 + 내가 수락, 최대 10개)
  var upcomingPromises: [PromiseModel] {
    let (_, endOfDay) = todayRange
    let userId = currentUser.userId
    return allPromises
      .filter {
        $0.startAt >= endOfDay &&
        $0.isConfirmed &&
        $0.myVoteStatus(userId: userId) == .accepted
      }
      .prefix(10)
      .map { $0 }
  }

  /// 다가오는 통합 일정 (그룹 약속 + 개인 일정, startAt 정렬, 최대 10개)
  var upcomingScheduleItems: [HomeModels.ScheduleItem] {
    let (_, endOfDay) = todayRange
    let userId = currentUser.userId
    let promiseItems = allPromises
      .filter {
        $0.startAt >= endOfDay &&
        $0.isConfirmed &&
        $0.myVoteStatus(userId: userId) == .accepted
      }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = allPersonalEvents
      .filter { $0.startAt >= endOfDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems)
      .sorted { $0.startAt < $1.startAt }
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
      todayCount: todayScheduleItems.count,
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

  // MARK: - Calendar Overlay Computed

  /// 오버레이 캘린더에 표시할 날짜 셀 배열
  var overlayCalendarDays: [OverlayCalendarModels.DayItem] {
    OverlayCalendarModels.generateMonthDays(
      for: overlayCalendarMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate
    )
  }

  /// 날짜별 일정 개수 (약속 + 개인 일정)
  private var overlayScheduleCountsByDate: [Date: Int] {
    let calendar = Calendar.current
    var counts: [Date: Int] = [:]

    // 약속
    for promise in allPromises {
      let dateKey = calendar.startOfDay(for: promise.startAt)
      counts[dateKey, default: 0] += 1
    }

    // 개인 일정
    for event in (personalEventsState.value ?? []) {
      let dateKey = calendar.startOfDay(for: event.startAt)
      counts[dateKey, default: 0] += 1
    }

    return counts
  }

  /// 오버레이에서 선택된 날짜의 일정 아이템
  var overlaySelectedDateItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.current
    let promiseItems = allPromises
      .filter { calendar.isDate($0.startAt, inSameDayAs: overlaySelectedDate) }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = (personalEventsState.value ?? [])
      .filter { calendar.isDate($0.startAt, inSameDayAs: overlaySelectedDate) }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems).sorted { $0.startAt < $1.startAt }
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
        homeContent
          .auroraBackground()
          .toast(Binding(
            get: { store.toastMessage },
            set: { _ in store.send(.view(.toastDismissed)) }
          ))
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              // 캘린더 오버레이 토글 버튼
              Button {
                store.send(.view(.calendarOverlayOpened))
              } label: {
                Image(systemName: "calendar")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 36, height: 36)
                  .adaptiveGlassBackground(cornerRadius: 18)
              }
            }

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
          .background(
            CalendarOverlayPresenter(
              isPresented: store.showCalendarOverlay,
              currentMonth: store.overlayCalendarMonth,
              days: store.overlayCalendarDays,
              todayScheduleItems: store.overlaySelectedDateItems,
              selectedDate: store.overlaySelectedDate,
              onClose: {
                store.send(.view(.calendarOverlayClosed))
              },
              onDateSelected: { date in
                store.send(.view(.overlayDateSelected(date)))
              },
              onPreviousMonth: {
                store.send(.view(.overlayPreviousMonth))
              },
              onNextMonth: {
                store.send(.view(.overlayNextMonth))
              }
            )
            .frame(width: 0, height: 0)
          )
      } destination: { store in
        switch store.case {
        case .promiseDetail(let detailStore):
          PromiseDetail.RootView(store: detailStore)
        case .personalEventDetail(let personalEventDetailStore):
          PersonalEventDetail.RootView(store: personalEventDetailStore)
        case .notificationCenter(let notificationStore):
          NotificationCenterFeature.NotificationCenter.RootView(store: notificationStore)
        }
      }
    }

    // MARK: - Home Content

    private var homeContent: some View {
      ScrollView {
        LazyVStack(spacing: 20) {
          if store.isLoading && !store.hasLoadedOnce {
            loadingView
          } else if let error = store.promisesState.error {
            errorView(error: error)
          } else {
            // 오늘의 일정 카드
            TodayScheduleCard(
              items: store.todayScheduleItems,
              weatherCache: store.weatherCache,
              onItemTap: { item in
                switch item {
                case .promise(let p):
                  store.send(.view(.todayPromiseTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
                }
              }
            )
            .padding(.horizontal, 16)

            // 응답 필요 섹션 (있을 때만 표시)
            if !store.pendingPromises.isEmpty {
              PendingSection(
                promises: store.pendingPromises,
                groupMembersCache: store.groupMembersCache,
                onPromiseTap: { promise in
                  store.send(.view(.pendingPromiseTapped(promise)))
                }
              )
              .padding(.horizontal, 16)
            }

            // 다가오는 일정 섹션
            UpcomingSection(
              items: store.upcomingScheduleItems,
              weatherCache: store.weatherCache,
              onItemTap: { item in
                switch item {
                case .promise(let p):
                  store.send(.view(.upcomingPromiseTapped(p)))
                case .personalEvent(let e):
                  store.send(.view(.personalEventTapped(e)))
                }
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

        Text(LocalizedStrings.Error.unknownError)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button(LocalizedStrings.Common.retry) {
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
