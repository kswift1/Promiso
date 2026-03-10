// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Clients
import CreatePromiseFeature
import NotificationCenterFeature
import PromisoShared
import SharedFeature
import UIKit

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
    @Dependency(\.openURL) var openURL
    @Dependency(\.holidayClient) var holidayClient
    @Dependency(\.briefingClient) var briefingClient
    public init() {}

    // MARK: - CancelID

    private enum CancelID {
      case weatherFetch
      case overlayWeatherFetch
      case overlayScheduleFetch
      case briefingFetch
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

      /// Pro 구독 여부
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      /// 브리핑 상태
      var briefingState: LoadingState<BriefingResult> = .idle
      /// 브리핑 생성 날짜 (같은 날 중복 방지)
      var briefingGeneratedDate: Date? = nil
      /// 브리핑 상세 펼침 여부
      var isBriefingExpanded: Bool = false
      /// 브리핑이 업데이트된 상태인지 (promptKey 변경으로 재생성됨)
      var isBriefingUpdated: Bool = false
      /// 마지막 브리핑 생성에 사용된 스타일 (캐시 무효화용)
      var lastBriefingStyle: String?
      /// 브리핑 스타일 (AppStorage로 앱 전체 공유)
      @Shared(.appStorage(AppConstants.UserDefaults.briefingStyle)) var briefingStyleRaw: String = BriefingStyle.friendly.rawValue

      // MARK: Permission
      /// 알림 권한 상태
      var notificationAuthStatus: NotificationAuthorizationStatus = .notDetermined
      /// 위치 권한 상태
      var locationAuthStatus: LocationAuthorizationStatus = .notDetermined

      /// 알림 권한 거부 여부
      var isNotificationDenied: Bool { notificationAuthStatus == .denied }
      /// 위치 권한 거부 여부
      var isLocationDenied: Bool { locationAuthStatus == .denied }

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
      /// 오버레이 날씨 전체 정보 (시간별 예보 포함)
      var overlayWeatherInfo: WeatherInfo? = nil
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
      /// 오버레이 Feature 진입 전 캘린더 모드 (뒤로가기 시 복귀용)
      var overlayCalendarModeBeforeFeature: CalendarMode?
      /// 공휴일 맵 (날짜 → 공휴일 이름)
      var overlayHolidaysByDate: [Date: String] = [:]
      /// 로드된 공휴일 연도
      var overlayLoadedHolidayYears: Set<Int> = []

      /// 개인 일정 생성 모달
      @Presents var createPersonalEvent: CreatePersonalEvent.Feature.State?

      /// 오버레이 내 일정 상세 (약속 + 개인 일정 통합)
      var overlayScheduleDetail: OverlayScheduleDetail.Feature.State?
      /// 오버레이 내 약속 생성
      var overlayCreatePromise: CreatePromise.Feature.State?

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
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case path(StackActionOf<Path>)
      case createPersonalEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case overlayScheduleDetail(OverlayScheduleDetail.Feature.Action)
      case overlayCreatePromise(CreatePromise.Feature.Action)
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
        /// 브리핑 카드 탭 (expand/collapse)
        case briefingCardTapped
        /// 브리핑 새로고침
        case refreshBriefingTapped
        /// 알림 설정 열기 (권한 안내 배너에서)
        case openNotificationSettingsTapped
        /// 위치 설정 열기 (권한 안내 배너에서)
        case openLocationSettingsTapped
        /// 브리핑 오류 제보
        case reportBriefingErrorTapped
        /// 브리핑 Pro 업그레이드 CTA 탭
        case briefingProUpgradeTapped
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
        /// 오버레이 일정 상세에서 뒤로가기
        case overlayScheduleDetailBackTapped
        /// 오버레이 약속 생성에서 뒤로가기
        case overlayCreatePromiseBackTapped
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
        /// 오버레이 일정 상세 state 정리 (전환 애니메이션 완료 후)
        case clearOverlayScheduleDetail
        /// 오버레이 공휴일 조회
        case fetchOverlayHolidays(year: Int)
        /// 오버레이 공휴일 응답
        case overlayHolidaysResponse(year: Int, Result<[PublicHoliday], Error>)
        /// 브리핑 생성 트리거
        case fetchBriefing(forceRefresh: Bool = false)
        /// 브리핑 응답
        case briefingResponse(Result<BriefingResult, Error>)
        /// 권한 상태 확인
        case checkPermissions
        /// 권한 상태 확인 결과
        case permissionsChecked(notification: NotificationAuthorizationStatus, location: LocationAuthorizationStatus)
      }

      @CasePathable
      public enum Delegate: Sendable {
        /// 약속 상세로 네비게이션 (legacy - 그룹 탭 이동용)
        case navigateToPromise(promiseId: String, groupId: String)
        /// 그룹 탭의 특정 약속으로 네비게이션 (응답 필요 카드에서)
        case navigateToGroupWithPromise(groupId: String, promiseId: String)
        /// 모든 약속 보기 화면으로 네비게이션
        case navigateToAllPromises
        /// 오버레이에서 약속 만들기 요청 (→ RootTab → GroupMain)
        case navigateToCreatePromise
        /// 빠른 약속 생성 요청 (추출 정보 → CreatePromise pre-fill)
        case createPromiseWithExtractedInfo(PromiseExtractedInfo)
        /// Pro 플랜 업그레이드 요청
        case proPlanRequested
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

            // 오버레이가 열려 있고 denied/needsPermission 상태면 권한 재체크
            var weatherEffect: Effect<Action> = .none
            if state.showCalendarOverlay {
              let authStatus = locationClient.authorizationStatus()
              switch authStatus {
              case .authorized where state.overlayWeatherState == .denied
                || state.overlayWeatherState == .needsPermission:
                state.overlayWeatherState = .loading
                weatherEffect = .send(.internal(.fetchOverlayWeather))
              case .denied where state.overlayWeatherState != .denied:
                state.overlayWeatherState = .denied
              default:
                break
              }
            }

            // Firestore에서 직접 쿼리 (약속 + 개인 일정 병렬)
            return .merge(
              weatherEffect,
              .send(.internal(.fetchPromises)),
              .send(.internal(.fetchPersonalEvents)),
              .send(.internal(.checkPermissions))
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

          case .briefingCardTapped:
            state.isBriefingExpanded.toggle()
            return .none

          case .briefingProUpgradeTapped:
            return .send(.delegate(.proPlanRequested))

          case .refreshBriefingTapped:
            state.briefingState = .loading
            state.briefingGeneratedDate = nil
            state.isBriefingExpanded = false
            state.isBriefingUpdated = false
            return .send(.internal(.fetchBriefing()))

          case .openNotificationSettingsTapped:
            return .run { [notificationClient] _ in
              await notificationClient.openNotificationSettings()
            }

          case .openLocationSettingsTapped:
            return .run { [openURL] _ in
              if let url = URL(string: UIApplication.openSettingsURLString) {
                await openURL(url)
              }
            }

          case .reportBriefingErrorTapped:
            let briefing = state.briefingState.value
            let generatedDate = state.briefingGeneratedDate
            let notificationDenied = state.isNotificationDenied
            let locationDenied = state.isLocationDenied
            let userId = state.currentUser.userId

            AppLogger.briefing.info("🚨 [오류제보] uid=\(userId), summary=\(briefing?.summary ?? "nil"), detail=\(briefing?.detail ?? "nil"), generatedAt=\(generatedDate?.ISO8601Format() ?? "nil"), notifDenied=\(notificationDenied), locDenied=\(locationDenied)")

            // 강제 새로고침
            state.briefingState = .loading
            state.briefingGeneratedDate = nil
            state.isBriefingUpdated = false

            return .merge(
              .run { [openURL] _ in
                let subject = "[Promiso] 브리핑 오류 제보"
                var body = "제보해 주셔서 감사합니다! 더 나은 브리핑을 만드는 데 큰 도움이 됩니다 🙏\n\n"
                body += "상세 내용이 있다면 입력해주세요:\n\n\n"
                body += "── 자동 수집 정보 (확인용) ──\n"
                body += "UID: \(userId)\n"
                body += "생성 시각: \(generatedDate?.formatted(date: .abbreviated, time: .shortened) ?? "없음")\n"
                body += "요약: \(briefing?.summary ?? "없음")\n"
                body += "상세: \(briefing?.detail ?? "없음")\n"
                body += "알림 권한: \(!notificationDenied)\n"
                body += "위치 권한: \(!locationDenied)\n"
                body += "Timezone: \(TimeZone.current.identifier)\n"
                body += "Locale: \(Locale.current.identifier)\n"
                body += "────────────────────\n"

                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                if let mailURL = URL(string: "mailto:promiso.app@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)") {
                  await openURL(mailURL)
                }
              },
              .send(.internal(.fetchBriefing(forceRefresh: true)))
            )

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
            case .notDetermined:
              state.overlayWeatherLocationText = nil
              state.overlayWeatherState = .needsPermission
              weatherEffect = .none
            case .denied:
              state.overlayWeatherLocationText = nil
              state.overlayWeatherState = .denied
              weatherEffect = .none
            }

            // 공휴일 로드 (현재 연도 + 인접 연도)
            let today = Date()
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: today)
            var holidayEffects: [Effect<Action>] = []
            for year in [currentYear - 1, currentYear, currentYear + 1] {
              if !state.overlayLoadedHolidayYears.contains(year) {
                holidayEffects.append(.send(.internal(.fetchOverlayHolidays(year: year))))
              }
            }

            return .merge(
              [
                weatherEffect,
                .send(.internal(.fetchOverlaySchedules(month: currentMonth))),
                .send(.internal(.fetchOverlayPersonalEvents(month: currentMonth)))
              ] + holidayEffects
            )

          case .calendarOverlayClosed:
            state.showCalendarOverlay = false
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            state.overlayWeatherInfo = nil
            state.overlayCalendarMode = .monthly
            state.overlayCalendarModeBeforeFeature = nil
            state.overlayScheduleDetail = nil
            state.overlayCreatePromise = nil
            state.overlayPromisesByMonth.removeAll()
            state.overlayLoadedMonths.removeAll()
            state.overlayPersonalEventsByMonth.removeAll()
            state.overlayLoadedPersonalEventMonths.removeAll()
            state.overlayHolidaysByDate.removeAll()
            state.overlayLoadedHolidayYears.removeAll()
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
            // loaded 상태: 날씨 상세 보기
            if case .loaded = state.overlayWeatherState {
              state.overlayCalendarMode = .weatherDetail
              return .none
            }
            if state.overlayWeatherState == .denied {
              return .run { [openURL] _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  await openURL(url)
                }
              }
            }
            // needsPermission: OS 다이얼로그 표시 중에는 상태 유지, 결과에 따라 전환
            let isFirstRequest = state.overlayWeatherState == .needsPermission
            if !isFirstRequest {
              state.overlayWeatherLocationText = nil
              state.overlayWeatherState = .loading
            }
            return .send(.internal(.fetchOverlayWeather))

          case .overlayBackToMonth:
            state.overlayCalendarMode = .monthly
            return .none

          case .overlayScheduleItemTapped(let item):
            switch item {
            case .promise(let promise):
              let groupMembers = state.groupMembersCache[promise.groupId]
              state.overlayScheduleDetail = OverlayScheduleDetail.Feature.State(
                item: item,
                currentUserId: state.currentUser.userId,
                groupMembers: groupMembers
              )
              state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
              state.overlayCalendarMode = .promiseDetail
              return .none
            case .personalEvent:
              // 개인 일정도 오버레이 내에서 인라인 표시
              state.overlayScheduleDetail = OverlayScheduleDetail.Feature.State(
                item: item,
                currentUserId: state.currentUser.userId
              )
              state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
              state.overlayCalendarMode = .promiseDetail
              return .none
            }

          case .overlayCreatePersonalEventTapped(let date):
            // 오버레이 닫기
            state.showCalendarOverlay = false
            state.overlayCalendarMode = .monthly
            state.overlayWeatherState = .needsPermission
            state.overlayWeatherLocationText = nil
            state.overlayWeatherInfo = nil
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
            // 오버레이 내에서 약속 생성 인라인 표시
            state.overlayCreatePromise = CreatePromise.Feature.State(
              groupSummaries: state.currentUser.groups.isEmpty ? nil : Array(state.currentUser.groups),
              currentUserId: state.currentUser.userId
            )
            state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
            state.overlayCalendarMode = .promiseCreate
            return .none

          case .overlayScheduleDetailBackTapped:
            // 모드만 먼저 전환 (전환 애니메이션 동안 콘텐츠 유지)
            state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
            state.overlayCalendarModeBeforeFeature = nil
            return .run { send in
              try await Task.sleep(for: .milliseconds(500))
              await send(.internal(.clearOverlayScheduleDetail))
            }

          case .overlayCreatePromiseBackTapped:
            state.overlayCreatePromise = nil
            state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
            state.overlayCalendarModeBeforeFeature = nil
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

              // 약속 로드 성공 시 알림 개수 + 날씨 + 브리핑 조회
              return .merge(
                .send(.internal(.fetchUnreadNotificationCount)),
                .send(.internal(.fetchWeather)),
                .send(.internal(.fetchBriefing()))
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
              // 개인 일정 실패 시 기존 데이터 유지 (이미 로드된 데이터가 있으면 보존)
              if !state.personalEventsState.isLoaded {
                state.personalEventsState = .loaded([])
              }
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
            guard state.isPro else { return .none }
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
                // getCurrentLocation() 호출 후 권한 거부 시 스트림이 멈추므로 타임아웃 + 권한 재체크
                let location = try await withThrowingTaskGroup(of: Coordinate.self) { group in
                  group.addTask {
                    try await locationClient.getCurrentLocation()
                  }
                  group.addTask {
                    // 권한 다이얼로그 대기 후 거부 감지 (최대 10초 타임아웃)
                    try await Task.sleep(for: .seconds(1))
                    for _ in 0..<18 { // 0.5초 * 18 = 9초
                      let status = locationClient.authorizationStatus()
                      if status == .denied {
                        throw LocationClientError.denied
                      }
                      if status == .authorized {
                        // getCurrentLocation 태스크가 위치를 반환할 때까지 대기
                        try await Task.sleep(for: .seconds(10))
                        throw LocationClientError.unavailable
                      }
                      try await Task.sleep(for: .milliseconds(500))
                    }
                    // 타임아웃
                    throw LocationClientError.unavailable
                  }
                  guard let result = try await group.next() else {
                    throw LocationClientError.unavailable
                  }
                  group.cancelAll()
                  return result
                }
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
                state.overlayWeatherInfo = info
              } else {
                state.overlayWeatherState = .failed
                state.overlayWeatherLocationText = nil
                state.overlayWeatherInfo = nil
              }
            case .failure:
              let authStatus = locationClient.authorizationStatus()
              if authStatus == .denied {
                state.overlayWeatherState = .denied
              } else {
                state.overlayWeatherState = .failed
              }
              state.overlayWeatherLocationText = nil
              state.overlayWeatherInfo = nil
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

          case .clearOverlayScheduleDetail:
            state.overlayScheduleDetail = nil
            return .none

          case .fetchOverlayHolidays(let year):
            guard !state.overlayLoadedHolidayYears.contains(year) else { return .none }
            return .run { [holidayClient] send in
              do {
                let holidays = try await holidayClient.fetchHolidays(year)
                await send(.internal(.overlayHolidaysResponse(year: year, .success(holidays))))
              } catch {
                await send(.internal(.overlayHolidaysResponse(year: year, .failure(error))))
              }
            }

          case .overlayHolidaysResponse(let year, let result):
            switch result {
            case .success(let holidays):
              state.overlayLoadedHolidayYears.insert(year)
              let calendar = Calendar.current
              for holiday in holidays {
                let dateKey = calendar.startOfDay(for: holiday.date)
                state.overlayHolidaysByDate[dateKey] = holiday.localName
              }
            case .failure:
              // 공휴일 로드 실패 시 조용히 무시
              break
            }
            return .none

          case .fetchBriefing(let forceRefresh):
            let currentStyleRaw = state.briefingStyleRaw
            let styleChanged = state.lastBriefingStyle != nil && state.lastBriefingStyle != currentStyleRaw
            let needsForceRefresh = forceRefresh || styleChanged

            // 서버에서 promptKey 기반 캐시 처리하므로 항상 서버 호출
            state.briefingState = .loading
            state.lastBriefingStyle = currentStyleRaw

            let briefingStyle = BriefingStyle(rawValue: currentStyleRaw) ?? .friendly
            return .run { [locationClient, briefingClient, briefingStyle, needsForceRefresh] send in
              let input = await Self.buildBriefingInput(
                locationClient: locationClient,
                style: briefingStyle,
                forceRefresh: needsForceRefresh
              )

              do {
                let briefing = try await briefingClient.generate(input)
                AppLogger.briefing.debug("✅ 브리핑 생성 완료 - 요약: \(briefing.summary)")
                await send(.internal(.briefingResponse(.success(briefing))))
              } catch {
                AppLogger.briefing.error("❌ 브리핑 생성 실패: \(error)")
                await send(.internal(.briefingResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.briefingFetch, cancelInFlight: true)

          case .briefingResponse(let result):
            switch result {
            case .success(let briefingResult):
              state.briefingState = .loaded(briefingResult)
              state.briefingGeneratedDate = Date()
              state.isBriefingUpdated = briefingResult.isUpdated
            case .failure(let error):
              state.briefingState = .failed(error as? BriefingClientError ?? .networkError)
              state.isBriefingUpdated = false
            }
            return .none

          case .checkPermissions:
            return .run { [notificationClient, locationClient] send in
              let notificationStatus = await notificationClient.getAuthorizationStatus()
              let locationStatus = locationClient.authorizationStatus()
              await send(.internal(.permissionsChecked(
                notification: notificationStatus,
                location: locationStatus
              )))
            }

          case .permissionsChecked(let notificationStatus, let locationStatus):
            state.notificationAuthStatus = notificationStatus
            state.locationAuthStatus = locationStatus
            return .none

          }

        case .createPersonalEvent(.presented(.delegate(.eventCreated))):
          state.createPersonalEvent = nil
          return .send(.internal(.fetchPersonalEvents))

        case .createPersonalEvent(.presented(.delegate(.dismiss))):
          state.createPersonalEvent = nil
          return .none

        case .createPersonalEvent:
          return .none

        // MARK: - Overlay Schedule Detail Actions

        case .overlayScheduleDetail(.delegate(.dismiss)):
          // 모드만 먼저 전환 (전환 애니메이션 동안 콘텐츠 유지)
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          return .run { send in
            try await Task.sleep(for: .milliseconds(500))
            await send(.internal(.clearOverlayScheduleDetail))
          }

        case .overlayScheduleDetail(.delegate(.openFullDetail(let item))):
          state.overlayScheduleDetail = nil
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          state.showCalendarOverlay = false
          state.overlayWeatherState = .needsPermission
          state.overlayWeatherLocationText = nil
          state.overlayWeatherInfo = nil
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

        case .overlayScheduleDetail(.delegate(.promiseResponseUpdated(let promise))):
          // 오버레이 캐시 업데이트
          let monthKey = promise.startAt.startOfMonth
          if let index = state.overlayPromisesByMonth[monthKey]?.firstIndex(where: { $0.id == promise.id }) {
            state.overlayPromisesByMonth[monthKey]?[index] = promise
          }
          // 홈 약속 목록도 업데이트
          if case .loaded(var promises) = state.promisesState,
             let index = promises.firstIndex(where: { $0.id == promise.id }) {
            promises[index] = promise
            state.promisesState = .loaded(promises)
            state.refreshHomeContentSnapshot()
          }
          return .none

        case .overlayScheduleDetail:
          return .none

        // MARK: - Overlay Create Promise Actions

        case .overlayCreatePromise(.delegate(.promiseCreated)):
          state.overlayCreatePromise = nil
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          // 약속이 어느 월에 생성되었을지 모르므로 전체 캐시 무효화
          state.overlayLoadedMonths.removeAll()
          state.overlayPromisesByMonth.removeAll()
          let month = state.overlaySelectedDate.startOfMonth
          return .merge(
            .send(.internal(.fetchPromises)),
            .send(.internal(.fetchOverlaySchedules(month: month)))
          )

        case .overlayCreatePromise(.delegate(.dismiss)):
          state.overlayCreatePromise = nil
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          return .none

        case .overlayCreatePromise(.delegate(.createGroupRequested)):
          // 그룹 생성은 오버레이에서 불가 → 오버레이 닫고 기존 플로우로 위임
          state.overlayCreatePromise = nil
          state.overlayCalendarModeBeforeFeature = nil
          state.showCalendarOverlay = false
          state.overlayCalendarMode = .monthly
          return .merge(
            .cancel(id: CancelID.overlayWeatherFetch),
            .send(.delegate(.navigateToCreatePromise))
          )

        case .overlayCreatePromise:
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

        case .path(.element(id: _, action: .notificationCenter(.delegate(.refreshBadgeCount)))):
          return .send(.internal(.fetchUnreadNotificationCount))

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
      .ifLet(\.$createPersonalEvent, action: \.createPersonalEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.overlayScheduleDetail, action: \.overlayScheduleDetail) {
        OverlayScheduleDetail.Feature()
      }
      .ifLet(\.overlayCreatePromise, action: \.overlayCreatePromise) {
        CreatePromise.Feature()
      }

    }

    // MARK: - Briefing Helpers

    private static func buildBriefingInput(
      locationClient: LocationClient,
      style: BriefingStyle,
      forceRefresh: Bool
    ) async -> BriefingInput {
      var location: BriefingInput.BriefingLocation?

      if locationClient.authorizationStatus() == .authorized {
        do {
          let coordinate = try await locationClient.getCurrentLocation()
          let locationText = try await locationClient.reverseGeocode(coordinate)
          location = BriefingInput.BriefingLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            title: locationText
          )
        } catch {
          // 위치 실패 시 무시하고 진행
        }
      }

      let input = BriefingInput(
        timezone: TimeZone.current.identifier,
        language: (AppLanguage.current ?? .korean).rawValue,
        location: location,
        forceRefresh: forceRefresh,
        style: style
      )

      AppLogger.briefing.debug("📋 브리핑 요청: timezone=\(input.timezone), location=\(location?.title ?? "없음"), forceRefresh=\(forceRefresh), style=\(style.rawValue)")

      return input
    }
  }
}
