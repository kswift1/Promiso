// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Clients
import NotificationCenterFeature
import PromisoShared
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
    @Dependency(\.locationClient) var locationClient

    public init() {}

    // MARK: - CancelID

    private enum CancelID {
      case weatherFetch
      case overlayWeatherFetch
      case overlayScheduleFetch
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
      /// 오버레이 캘린더 현재 월
      var overlayCalendarMonth: Date = Date()
      /// 오버레이 캘린더 선택 날짜
      var overlaySelectedDate: Date = Date()
      /// 오버레이 날씨 상태
      var overlayWeatherState: OverlayWeatherState = .needsPermission
      /// 오버레이 날씨 기준 위치 텍스트
      var overlayWeatherLocationText: String? = nil
      /// 오버레이 캘린더 표시 모드
      var overlayCalendarMode: CalendarMode = .monthly
      /// 오버레이 월별 약속 캐시 (키: 월 시작일)
      var overlayPromisesByMonth: [Date: [PromiseModel]] = [:]
      /// 이미 로드된 오버레이 월 (중복 요청 방지)
      var overlayLoadedMonths: Set<Date> = []
      /// 오버레이 월별 개인 일정 캐시 (키: 월 시작일)
      var overlayPersonalEventsByMonth: [Date: [PersonalEventModel]] = [:]
      /// 이미 로드된 오버레이 개인 일정 월 (중복 요청 방지)
      var overlayLoadedPersonalEventMonths: Set<Date> = []

      /// 개인 일정 생성 모달
      @Presents var createPersonalEvent: CreatePersonalEvent.Feature.State?

      // MARK: Notification
      /// 안 읽은 알림 개수
      var unreadNotificationCount: Int = 0

      // MARK: Navigation
      /// 네비게이션 경로 (약속 상세)
      var path = StackState<Path.State>()

      /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷
      struct HomeContentSnapshot: Equatable {
        let todayPromises: [PromiseModel]
        let todayScheduleItems: [HomeModels.ScheduleItem]
        let pendingPromises: [PromiseModel]
        let upcomingPromises: [PromiseModel]
        let upcomingScheduleItems: [HomeModels.ScheduleItem]

        static let empty = Self(
          todayPromises: [],
          todayScheduleItems: [],
          pendingPromises: [],
          upcomingPromises: [],
          upcomingScheduleItems: []
        )
      }

      /// 액션 처리 시점에 계산해 보관하는 홈 스냅샷
      var homeContentSnapshot: HomeContentSnapshot = .empty

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
    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case path(StackActionOf<Path>)
      case createPersonalEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)

      @CasePathable
      public enum View {
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
        /// 오버레이 날씨 카드 탭 (권한 요청)
        case overlayWeatherCardTapped
        /// 오버레이 월간 뷰로 복귀
        case overlayBackToMonth
        /// 오버레이 일간 상세에서 일정 탭
        case overlayScheduleItemTapped(HomeModels.ScheduleItem)
        /// 오버레이 개인 일정 추가 (context menu)
        case overlayCreatePersonalEventTapped(Date)
        /// 오버레이 약속 만들기 (context menu)
        case overlayCreatePromiseTapped
      }

      @CasePathable
      public enum Internal {
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
        /// 날씨 정보 배치 응답 (scheduleId → WeatherInfo)
        case weatherBatchResponse([String: WeatherInfo])
        /// 오버레이 현재 위치 날씨 조회
        case fetchOverlayWeather
        /// 오버레이 날씨 응답
        case overlayWeatherResponse(Result<WeatherInfo, Error>, String?)
        /// 오버레이 월별 약속 조회
        case fetchOverlaySchedules(month: Date)
        /// 오버레이 월별 약속 응답
        case overlaySchedulesResponse(month: Date, Result<[PromiseModel], Error>)
        /// 오버레이 인접 월 프리페치
        case prefetchOverlayAdjacentMonths
        /// 오버레이 월별 개인 일정 조회
        case fetchOverlayPersonalEvents(month: Date)
        /// 오버레이 월별 개인 일정 응답
        case overlayPersonalEventsResponse(month: Date, Result<[PersonalEventModel], Error>)
        /// 오버레이 인접 월 개인 일정 프리페치
        case prefetchOverlayAdjacentPersonalEvents
      }

      @CasePathable
      public enum Delegate {
        /// 약속 상세로 네비게이션 (legacy - 그룹 탭 이동용)
        case navigateToPromise(promiseId: String, groupId: String)
        /// 그룹 탭의 특정 약속으로 네비게이션 (응답 필요 카드에서)
        case navigateToGroupWithPromise(groupId: String, promiseId: String)
        /// 모든 약속 보기 화면으로 네비게이션
        case navigateToAllPromises
        /// 오버레이에서 약속 만들기 요청 (→ RootTab → GroupMain)
        case navigateToCreatePromise
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
            state.refreshHomeContentSnapshot()
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
            state.showCalendarOverlay = true
            // 오버레이 캐시 초기화
            state.overlayPromisesByMonth.removeAll()
            state.overlayLoadedMonths.removeAll()
            state.overlayPersonalEventsByMonth.removeAll()
            state.overlayLoadedPersonalEventMonths.removeAll()

            let currentMonth = Date().startOfMonth

            // 위치 권한 동기 체크
            let authStatus = locationClient.authorizationStatus()
            let weatherEffect: Effect<Action>
            switch authStatus {
            case .authorized:
              state.overlayWeatherLocationText = nil
              state.overlayWeatherState = .loading
              weatherEffect = .send(.internal(.fetchOverlayWeather))
            case .notDetermined, .denied:
              state.overlayWeatherLocationText = nil
              state.overlayWeatherState = .needsPermission
              weatherEffect = .none
            }

            return .merge(
              weatherEffect,
              .send(.internal(.fetchOverlaySchedules(month: currentMonth))),
              .send(.internal(.fetchOverlayPersonalEvents(month: currentMonth)))
            )

          case .calendarOverlayClosed:
            state.showCalendarOverlay = false
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            state.overlayCalendarMode = .monthly
            state.overlayPromisesByMonth.removeAll()
            state.overlayLoadedMonths.removeAll()
            state.overlayPersonalEventsByMonth.removeAll()
            state.overlayLoadedPersonalEventMonths.removeAll()
            return .cancel(id: CancelID.overlayWeatherFetch)

          case .overlayDateSelected(let date):
            state.overlaySelectedDate = date
            let calendar = Calendar.promiseDisplay
            var effects: [Effect<Action>] = []
            if !calendar.isDate(date, equalTo: state.overlayCalendarMonth, toGranularity: .month) {
              state.overlayCalendarMonth = date
              effects.append(.send(.internal(.fetchOverlaySchedules(month: date))))
              effects.append(.send(.internal(.fetchOverlayPersonalEvents(month: date))))
            }
            if state.overlayCalendarMode == .monthly {
              state.overlayCalendarMode = .weekly
            }
            return effects.isEmpty ? .none : .merge(effects)

          case .overlayPreviousMonth:
            if let prev = Calendar.promiseDisplay.date(byAdding: .month, value: -1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = prev
            }
            return .merge(
              .send(.internal(.fetchOverlaySchedules(month: state.overlayCalendarMonth))),
              .send(.internal(.fetchOverlayPersonalEvents(month: state.overlayCalendarMonth)))
            )

          case .overlayNextMonth:
            if let next = Calendar.promiseDisplay.date(byAdding: .month, value: 1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = next
            }
            return .merge(
              .send(.internal(.fetchOverlaySchedules(month: state.overlayCalendarMonth))),
              .send(.internal(.fetchOverlayPersonalEvents(month: state.overlayCalendarMonth)))
            )

          case .overlayWeatherCardTapped:
            state.overlayWeatherLocationText = nil
            state.overlayWeatherState = .loading
            return .send(.internal(.fetchOverlayWeather))

          case .overlayBackToMonth:
            state.overlayCalendarMode = .monthly
            return .none

          case .overlayScheduleItemTapped(let item):
            // 일간 상세에서 일정 아이템 탭 → 오버레이 닫고 상세로 이동
            state.showCalendarOverlay = false
            state.overlayCalendarMode = .monthly
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            switch item {
            case .promise(let promise):
              let groupMembers = state.groupMembersCache[promise.groupId]
              state.path.append(.promiseDetail(.init(
                promise: promise,
                currentUserId: state.currentUser.userId,
                groupMembers: groupMembers
              )))
            case .personalEvent(let event):
              state.path.append(.personalEventDetail(.init(event: event)))
            }
            return .cancel(id: CancelID.overlayWeatherFetch)

          case .overlayCreatePersonalEventTapped(let date):
            // 오버레이 닫기
            state.showCalendarOverlay = false
            state.overlayCalendarMode = .monthly
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            // 개인 일정 생성 모달 열기 (선택 날짜로 초기화)
            let calendar = Calendar.promiseDisplay
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let isTimePrecise = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
            let startAt: Date
            if isTimePrecise {
              startAt = date
            } else {
              startAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            }
            state.createPersonalEvent = CreatePersonalEvent.Feature.State(
              event: PersonalEventModel(startAt: startAt)
            )
            return .cancel(id: CancelID.overlayWeatherFetch)

          case .overlayCreatePromiseTapped:
            // 오버레이 닫기 + delegate로 위임
            state.showCalendarOverlay = false
            state.overlayCalendarMode = .monthly
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            return .merge(
              .cancel(id: CancelID.overlayWeatherFetch),
              .send(.delegate(.navigateToCreatePromise))
            )

          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchPromises:
            // 기존 데이터가 없을 때만 로딩 상태 표시 (깜빡임 방지)
            if state.promisesState.value == nil {
              state.promisesState = .loading
            }

            // 그룹이 없으면 빈 배열 반환
            var seenGroupIds = Set<String>()
            let groupIds = state.currentUser.groups.compactMap { groupInfo in
              seenGroupIds.insert(groupInfo.id).inserted ? groupInfo.id : nil
            }
            guard !groupIds.isEmpty else {
              state.promisesState = .loaded([])
              state.refreshHomeContentSnapshot()
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
              var groupsDict: [String: UserGroupInfo] = [:]
              for groupInfo in state.currentUser.groups {
                groupsDict[groupInfo.id] = groupInfo
              }
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
              state.refreshHomeContentSnapshot()

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
              state.refreshHomeContentSnapshot()
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
              state.refreshHomeContentSnapshot()
              WidgetDataManager.savePersonalEvents(events.toWidgetData())
              WidgetDataManager.reloadWidgets()
              // 개인 일정 날씨도 조회 (이미 캐시된 항목은 스킵)
              return .send(.internal(.fetchWeather))
            case .failure:
              // 개인 일정 실패 시 빈 배열로 처리 (그룹 약속은 정상 표시)
              state.personalEventsState = .loaded([])
              state.refreshHomeContentSnapshot()
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
            let cachedIds = state.weatherCache
            let promises = state.allPromises.filter { promise in
              let hasLat = promise.location?.latitude != nil
              let hasLng = promise.location?.longitude != nil
              let notPast = !promise.isPast
              let notCached = cachedIds[promise.id] == nil
              return hasLat && hasLng && notPast && notCached
            }
            let events = (state.personalEventsState.value ?? []).filter { event in
              event.location?.latitude != nil &&
              event.location?.longitude != nil &&
              cachedIds[event.id] == nil
            }

            // 예보 범위(10일) 밖 필터링 (단기 5일 + 중기 10일)
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)

            struct LocationKey: Hashable, Sendable {
              let lat: Double
              let lng: Double
              let hour: Int
            }

            struct WeatherFetchTarget: Sendable {
              let lat: Double
              let lng: Double
              let date: Date
              var scheduleIds: [String]
            }

            var targetsByKey: [LocationKey: WeatherFetchTarget] = [:]

            func upsertTarget(
              scheduleId: String,
              lat: Double,
              lng: Double,
              date: Date
            ) {
              let hour = Calendar.promiseDisplay.component(.hour, from: date)
              let key = LocationKey(
                lat: (lat * 100).rounded() / 100,
                lng: (lng * 100).rounded() / 100,
                hour: hour
              )

              if var existing = targetsByKey[key] {
                if !existing.scheduleIds.contains(scheduleId) {
                  existing.scheduleIds.append(scheduleId)
                  targetsByKey[key] = existing
                }
                return
              }

              targetsByKey[key] = WeatherFetchTarget(
                lat: lat,
                lng: lng,
                date: date,
                scheduleIds: [scheduleId]
              )
            }

            for promise in promises where promise.startAt < maxDate {
              guard let lat = promise.location?.latitude,
                    let lng = promise.location?.longitude else { continue }
              upsertTarget(
                scheduleId: promise.id,
                lat: lat,
                lng: lng,
                date: promise.startAt
              )
            }

            for event in events where event.startAt < maxDate {
              guard let lat = event.location?.latitude,
                    let lng = event.location?.longitude else { continue }
              upsertTarget(
                scheduleId: event.id,
                lat: lat,
                lng: lng,
                date: event.startAt
              )
            }

            let targets = Array(targetsByKey.values)
            guard !targets.isEmpty else { return .none }

            return .run { [weatherClient] send in
              var updates: [String: WeatherInfo] = [:]

              await withTaskGroup(of: (WeatherFetchTarget, WeatherInfo?).self) { group in
                for target in targets {
                  group.addTask {
                    do {
                      let info = try await weatherClient.getWeather(
                        target.lat,
                        target.lng,
                        target.date
                      )
                      return (target, info)
                    } catch {
                      return (target, nil)
                    }
                  }
                }

                for await (target, info) in group {
                  guard let info else { continue }
                  for scheduleId in target.scheduleIds {
                    updates[scheduleId] = info
                  }
                }
              }

              guard !updates.isEmpty else { return }
              await send(.internal(.weatherBatchResponse(updates)))
            }
            .cancellable(id: CancelID.weatherFetch, cancelInFlight: true)

          case .weatherBatchResponse(let updates):
            guard !updates.isEmpty else { return .none }
            state.$weatherCache.withLock { cache in
              for (scheduleId, info) in updates {
                if cache[scheduleId] != info {
                  cache[scheduleId] = info
                }
              }
            }
            return .none

          case .fetchOverlayWeather:
            return .run { [locationClient, weatherClient] send in
              do {
                let location = try await locationClient.getCurrentLocation()
                async let weather = weatherClient.getWeather(
                  location.latitude, location.longitude, Date()
                )
                async let locationText: String? = {
                  do {
                    return try await locationClient.reverseGeocode(location)
                  } catch {
                    return nil
                  }
                }()

                let info = try await weather
                let address = await locationText
                await send(.internal(.overlayWeatherResponse(.success(info), address)))
              } catch {
                await send(.internal(.overlayWeatherResponse(.failure(error), nil)))
              }
            }
            .cancellable(id: CancelID.overlayWeatherFetch)

          case .overlayWeatherResponse(let result, let locationText):
            switch result {
            case .success(let info):
              if let forecast = info.current ?? info.hourlyForecasts.first {
                state.overlayWeatherState = .loaded(forecast)
                state.overlayWeatherLocationText = locationText
              } else {
                state.overlayWeatherState = .failed
                state.overlayWeatherLocationText = nil
              }
            case .failure:
              state.overlayWeatherState = .failed
              state.overlayWeatherLocationText = nil
            }
            return .none

          case .fetchOverlaySchedules(let month):
            let monthStart = month.startOfMonth
            guard !state.overlayLoadedMonths.contains(monthStart) else { return .none }
            state.overlayLoadedMonths.insert(monthStart)

            var seenGroupIds = Set<String>()
            let groupIds = state.currentUser.groups.compactMap { groupInfo in
              seenGroupIds.insert(groupInfo.id).inserted ? groupInfo.id : nil
            }
            guard !groupIds.isEmpty else {
              state.overlayPromisesByMonth[monthStart] = []
              return .none
            }

            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

            return .merge(
              .run { [promiseClient] send in
                do {
                  let promises = try await promiseClient.getPromisesByDateRange(groupIds, monthStart, endDate)
                  await send(.internal(.overlaySchedulesResponse(month: monthStart, .success(promises))))
                } catch {
                  await send(.internal(.overlaySchedulesResponse(month: monthStart, .failure(error))))
                }
              },
              .send(.internal(.prefetchOverlayAdjacentMonths))
            )

          case .overlaySchedulesResponse(let month, let result):
            switch result {
            case .success(let promises):
              var groupsDict: [String: UserGroupInfo] = [:]
              for groupInfo in state.currentUser.groups {
                groupsDict[groupInfo.id] = groupInfo
              }
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
              state.overlayPromisesByMonth[month] = promisesWithGroup
            case .failure:
              state.overlayLoadedMonths.remove(month)
            }
            return .none

          case .prefetchOverlayAdjacentMonths:
            let calendar = Calendar.current
            let currentMonth = state.overlayCalendarMonth.startOfMonth

            var effects: [Effect<Action>] = []
            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)?.startOfMonth,
               !state.overlayLoadedMonths.contains(prevMonth) {
              effects.append(.send(.internal(.fetchOverlaySchedules(month: prevMonth))))
            }
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)?.startOfMonth,
               !state.overlayLoadedMonths.contains(nextMonth) {
              effects.append(.send(.internal(.fetchOverlaySchedules(month: nextMonth))))
            }
            return effects.isEmpty ? .none : .merge(effects)

          case .fetchOverlayPersonalEvents(let month):
            let monthStart = month.startOfMonth
            guard !state.overlayLoadedPersonalEventMonths.contains(monthStart) else { return .none }
            state.overlayLoadedPersonalEventMonths.insert(monthStart)

            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

            return .merge(
              .run { [personalEventClient] send in
                do {
                  let events = try await personalEventClient.getEventsByDateRange(monthStart, endDate)
                  await send(.internal(.overlayPersonalEventsResponse(month: monthStart, .success(events))))
                } catch {
                  await send(.internal(.overlayPersonalEventsResponse(month: monthStart, .failure(error))))
                }
              },
              .send(.internal(.prefetchOverlayAdjacentPersonalEvents))
            )

          case .overlayPersonalEventsResponse(let month, let result):
            switch result {
            case .success(let events):
              state.overlayPersonalEventsByMonth[month] = events
            case .failure:
              state.overlayLoadedPersonalEventMonths.remove(month)
            }
            return .none

          case .prefetchOverlayAdjacentPersonalEvents:
            let calendar = Calendar.current
            let currentMonth = state.overlayCalendarMonth.startOfMonth

            var effects: [Effect<Action>] = []
            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)?.startOfMonth,
               !state.overlayLoadedPersonalEventMonths.contains(prevMonth) {
              effects.append(.send(.internal(.fetchOverlayPersonalEvents(month: prevMonth))))
            }
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)?.startOfMonth,
               !state.overlayLoadedPersonalEventMonths.contains(nextMonth) {
              effects.append(.send(.internal(.fetchOverlayPersonalEvents(month: nextMonth))))
            }
            return effects.isEmpty ? .none : .merge(effects)

          }

        case .createPersonalEvent(.presented(.delegate(.eventCreated))):
          state.createPersonalEvent = nil
          return .send(.internal(.fetchPersonalEvents))

        case .createPersonalEvent(.presented(.delegate(.dismiss))):
          state.createPersonalEvent = nil
          return .none

        case .createPersonalEvent:
          return .none

        case .delegate:
          return .none

        // MARK: - Path Actions

        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          // 오버레이 캐시 무효화
          let deletedMonth = state.overlaySelectedDate.startOfMonth
          state.overlayLoadedMonths.remove(deletedMonth)
          state.overlayPromisesByMonth.removeValue(forKey: deletedMonth)
          return .merge(
            .send(.internal(.fetchPromises)),
            state.showCalendarOverlay ? .send(.internal(.fetchOverlaySchedules(month: deletedMonth))) : .none
          )

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated)))):
          // 오버레이 캐시 무효화
          let updatedMonth = state.overlaySelectedDate.startOfMonth
          state.overlayLoadedMonths.remove(updatedMonth)
          state.overlayPromisesByMonth.removeValue(forKey: updatedMonth)
          return .merge(
            .send(.internal(.fetchPromises)),
            state.showCalendarOverlay ? .send(.internal(.fetchOverlaySchedules(month: updatedMonth))) : .none
          )

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
      .ifLet(\.$createPersonalEvent, action: \.createPersonalEvent) {
        CreatePersonalEvent.Feature()
      }
    }
  }
}
