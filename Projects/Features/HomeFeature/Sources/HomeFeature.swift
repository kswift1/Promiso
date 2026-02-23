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
      case overlayWeatherFetch
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
      /// 오버레이 일간 상세 모드
      var overlayDetailMode: Bool = false

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
        /// 날씨 정보 응답 (scheduleId → WeatherInfo)
        case weatherResponse(String, Result<WeatherInfo, Error>)
        /// 오버레이 현재 위치 날씨 조회
        case fetchOverlayWeather
        /// 오버레이 날씨 응답
        case overlayWeatherResponse(Result<WeatherInfo, Error>)
      }

      @CasePathable
      public enum Delegate {
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

            // 위치 권한 동기 체크
            let authStatus = locationClient.authorizationStatus()
            switch authStatus {
            case .authorized:
              state.overlayWeatherState = .loading
              return .send(.internal(.fetchOverlayWeather))
            case .notDetermined, .denied:
              state.overlayWeatherState = .needsPermission
              return .none
            }

          case .calendarOverlayClosed:
            state.showCalendarOverlay = false
            state.overlayWeatherState = .needsPermission
            state.overlayDetailMode = false
            return .cancel(id: CancelID.overlayWeatherFetch)

          case .overlayDateSelected(let date):
            state.overlaySelectedDate = date
            if !state.overlayDetailMode {
              state.overlayDetailMode = true
            }
            return .none

          case .overlayPreviousMonth:
            if let prev = Calendar.promiseDisplay.date(byAdding: .month, value: -1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = prev
            }
            return .none

          case .overlayNextMonth:
            if let next = Calendar.promiseDisplay.date(byAdding: .month, value: 1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = next
            }
            return .none

          case .overlayWeatherCardTapped:
            state.overlayWeatherState = .loading
            return .send(.internal(.fetchOverlayWeather))

          case .overlayBackToMonth:
            state.overlayDetailMode = false
            return .none

          case .overlayScheduleItemTapped(let item):
            // 일간 상세에서 일정 아이템 탭 → 오버레이 닫고 상세로 이동
            state.showCalendarOverlay = false
            state.overlayDetailMode = false
            state.overlayWeatherState = .needsPermission
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
              let hour = Calendar.promiseDisplay.component(.hour, from: promise.startAt)
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
              let hour = Calendar.promiseDisplay.component(.hour, from: event.startAt)
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

          case .fetchOverlayWeather:
            return .run { [locationClient, weatherClient] send in
              do {
                let location = try await locationClient.getCurrentLocation()
                let weather = try await weatherClient.getWeather(
                  location.latitude, location.longitude, Date()
                )
                await send(.internal(.overlayWeatherResponse(.success(weather))))
              } catch {
                await send(.internal(.overlayWeatherResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.overlayWeatherFetch)

          case .overlayWeatherResponse(let result):
            switch result {
            case .success(let info):
              if let forecast = info.current ?? info.hourlyForecasts.first {
                state.overlayWeatherState = .loaded(forecast)
              } else {
                state.overlayWeatherState = .failed
              }
            case .failure:
              state.overlayWeatherState = .failed
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
