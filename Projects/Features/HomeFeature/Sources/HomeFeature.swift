// MARK: - HomeFeature.swift
// TCA 1.22.2를 사용한 Home Feature의 Implementation layer

import Clients
import CreateScheduleFeature
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
    @Dependency(\.scheduleClient) var scheduleClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.weatherClient) var weatherClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.holidayClient) var holidayClient
    @Dependency(\.briefingClient) var briefingClient
    @Dependency(\.recurringPersonalEventClient) var recurringPersonalEventClient
    @Dependency(\.transportationClient) var transportationClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    public init() {}

    // MARK: - CancelID

    private enum CancelID {
      case weatherFetch
      case overlayWeatherFetch
      case overlayScheduleFetch
      case briefingFetch
      case transportationFetch
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
      /// 홈 일정 데이터 (Firestore 직접 쿼리)
      var schedulesState: LoadingState<[ScheduleModel]> = .idle

      /// 개인 일정 데이터
      var personalEventsState: LoadingState<[PersonalEventModel]> = .idle

      /// 반복 개인 일정 데이터
      var recurringEventsState: LoadingState<[RecurringPersonalEventModel]> = .idle

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
      /// 오버레이 월별 일정 캐시 (키: 월 시작일)
      var overlaySchedulesByMonth: [Date: [ScheduleModel]] = [:]
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
      /// 반복 개인 일정 생성 모달
      @Presents var createRecurringEvent: CreateRecurringPersonalEvent.Feature.State?
      /// 그룹 일정 생성 모달
      @Presents var createSchedule: CreateSchedule.Feature.State?

      /// 오버레이 내 일정 상세 (일정 + 개인 일정 통합)
      var overlayScheduleDetail: OverlayScheduleDetail.Feature.State?
      /// 오버레이 내 일정 생성
      var overlayCreateSchedule: CreateSchedule.Feature.State?

      // MARK: Notification
      /// 안 읽은 알림 개수
      var unreadNotificationCount: Int = 0

      // MARK: Departure Alert
      /// 출발 알림 설정 시트 대상 일정 (일정 또는 개인 일정)
      var departureAlertItem: HomeModels.ScheduleItem? = nil
      /// 교통 데이터 로딩 상태
      var departureTransportData: LoadingState<HomeModels.DepartureTransportData> = .idle
      /// 출발 알림 설정된 일정 (ScheduleItem.id → 알림 정보)
      var departureAlerts: [String: HomeModels.DepartureAlertInfo] = [:]
      /// 역지오코딩된 출발지명
      var departureLocationName: String? = nil
      /// 직전 일정 장소 정보 (출발지 선택 제안용)
      var previousScheduleLocation: HomeModels.PreviousScheduleLocation? = nil
      /// 현재 선택된 출발지
      var departureOrigin: HomeModels.DepartureOrigin = .currentLocation
      /// 현재 위치 좌표 (출발지 변경 시 재사용)
      var currentLocationCoordinate: Coordinate? = nil

      // MARK: Navigation
      /// 네비게이션 경로 (일정 상세)
      var path = StackState<Path.State>()

      /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷
      struct HomeContentSnapshot: Equatable {
        let todaySchedules: [ScheduleModel]
        let todayScheduleItems: [HomeModels.ScheduleItem]
        let pendingSchedules: [ScheduleModel]
        let upcomingSchedules: [ScheduleModel]
        let upcomingScheduleItems: [HomeModels.ScheduleItem]
        let upcomingRecurringSummaries: [HomeModels.RecurringEventSummary]

        static let empty = Self(
          todaySchedules: [],
          todayScheduleItems: [],
          pendingSchedules: [],
          upcomingSchedules: [],
          upcomingScheduleItems: [],
          upcomingRecurringSummaries: []
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
      case scheduleDetail(ScheduleDetail.Feature)
      case personalEventDetail(PersonalEventDetail.Feature)
      case recurringPersonalEventDetail(RecurringPersonalEventDetail.Feature)
      case notificationCenter(NotificationCenterFeature.NotificationCenter.Feature)
      case transportDetail(TransportDetail.Feature)
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case path(StackActionOf<Path>)
      case createPersonalEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case createRecurringEvent(PresentationAction<CreateRecurringPersonalEvent.Feature.Action>)
      case createSchedule(PresentationAction<CreateSchedule.Feature.Action>)
      case overlayScheduleDetail(OverlayScheduleDetail.Feature.Action)
      case overlayCreateSchedule(CreateSchedule.Feature.Action)
      @CasePathable
      public enum View: Sendable {
        /// 화면 나타남
        case onAppear
        /// Pull to refresh
        case refreshTriggered
        /// 오늘 일정 일정 카드 탭
        case todayScheduleTapped(ScheduleModel)
        /// 응답 필요 일정 카드 탭 (그룹 탭으로 이동)
        case pendingScheduleTapped(ScheduleModel)
        /// 다가오는 일정 카드 탭
        case upcomingScheduleTapped(ScheduleModel)
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
        /// 반복 개인 일정 인스턴스 카드 탭
        case recurringPersonalEventTapped(ExpandedEventInstance)
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
        /// 오버레이 일정 만들기 (context menu)
        case overlayCreateScheduleTapped
        /// 오버레이 일정 상세에서 뒤로가기
        case overlayScheduleDetailBackTapped
        /// 오버레이 일정 생성에서 뒤로가기
        case overlayCreateScheduleBackTapped
        /// 출발 알림 버튼 탭
        case departureAlertTapped(HomeModels.ScheduleItem)
        /// 출발 알림 시트 닫기
        case departureAlertSheetDismissed
        /// 교통수단 선택 확정 (알림 설정): selection + bufferMinutes
        case departureAlertConfirmed(HomeModels.TransportSelection, Int)
        /// 출발 알림 상세 화면 탭
        case departureAlertDetailTapped
        /// 출발 알림 취소
        case departureAlertCancelTapped(String)
        /// 출발 알림 재시도
        case departureAlertRetryTapped
        /// 출발지 변경 (현재 위치 ↔ 직전 일정 장소)
        case departureOriginChanged(HomeModels.DepartureOrigin)
        /// 출발 알림 시트에서 설정으로 이동
        case departureAlertOpenSettingsTapped
        /// 다가오는 일정 빈 상태에서 개인 일정 생성 탭
        case emptyCreatePersonalEventTapped
        /// 다가오는 일정 빈 상태에서 그룹 일정 생성 탭
        case emptyCreateScheduleTapped
        /// 반복 일정 빈 상태에서 반복 일정 생성 탭
        case emptyCreateRecurringEventTapped
      }

      @CasePathable
      public enum Internal: Sendable {
        /// 홈 일정 조회 (Firestore 직접 쿼리)
        case fetchSchedules
        /// 홈 일정 응답
        case schedulesResponse(Result<[ScheduleModel], Error>)
        /// 개인 일정 조회
        case fetchPersonalEvents
        /// 개인 일정 응답
        case personalEventsResponse(Result<[PersonalEventModel], Error>)
        /// 반복 개인 일정 조회
        case fetchRecurringEvents
        /// 반복 개인 일정 응답
        case recurringEventsResponse(Result<[RecurringPersonalEventModel], Error>)
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
        /// 오버레이 월별 일정 조회
        case fetchOverlaySchedules(month: Date)
        /// 오버레이 월별 일정 응답
        case overlaySchedulesResponse(month: Date, Result<[ScheduleModel], Error>)
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
        /// 교통 정보 응답
        case transportationResponse(String, Result<TransportationResult, Error>, Set<AvailableTransport> = [.transit, .car])
        /// 출발 알림 스케줄 완료
        case departureAlertScheduled(HomeModels.DepartureAlertInfo)
        /// 출발 알림 설정 실행 (TransportSelection → DepartureAlertInfo 변환 후 스케줄)
        case scheduleAlertForSelection(HomeModels.TransportSelection, Int)
        /// 출발지 역지오코딩 결과
        case departureLocationResolved(String?)
        /// 현재 위치 좌표 저장
        case currentLocationStored(Coordinate)
      }

      @CasePathable
      public enum Delegate: Sendable {
        /// 일정 상세로 네비게이션 (legacy - 그룹 탭 이동용)
        case navigateToSchedule(scheduleId: String, groupId: String)
        /// 그룹 탭의 특정 일정으로 네비게이션 (응답 필요 카드에서)
        case navigateToGroupWithSchedule(groupId: String, scheduleId: String)
        /// 모든 일정 보기 화면으로 네비게이션
        case navigateToAllSchedules
        /// 오버레이에서 일정 만들기 요청 (→ RootTab → GroupMain)
        case navigateToCreateSchedule
        /// 빠른 일정 생성 요청 (추출 정보 → CreateSchedule pre-fill)
        case createScheduleWithExtractedInfo(ScheduleExtractedInfo)
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
            // 첫 로드: 출발 알림 복원
            if !state.hasLoadedOnce {
              state.departureAlerts = Self.loadDepartureAlerts(userDefaultsClient: userDefaultsClient)
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

            // Firestore에서 직접 쿼리 (일정 + 개인 일정 + 반복 개인 일정 병렬)
            return .merge(
              weatherEffect,
              .send(.internal(.fetchSchedules)),
              .send(.internal(.fetchPersonalEvents)),
              .send(.internal(.fetchRecurringEvents)),
              .send(.internal(.checkPermissions))
            )

          case .refreshTriggered:
            // Pull-to-refresh도 동일하게 쿼리
            return .merge(
              .send(.internal(.fetchSchedules)),
              .send(.internal(.fetchPersonalEvents)),
              .send(.internal(.fetchRecurringEvents))
            )

          case .todayScheduleTapped(let schedule):
            // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
            let groupMembers = state.groupMembersCache[schedule.groupId]
            state.path.append(.scheduleDetail(.init(
              schedule: schedule,
              currentUserId: state.currentUser.userId,
              groupMembers: groupMembers
            )))
            return .none

          case .pendingScheduleTapped(let schedule):
            return .send(.delegate(.navigateToGroupWithSchedule(
              groupId: schedule.groupId,
              scheduleId: schedule.id
            )))

          case .upcomingScheduleTapped(let schedule):
            // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
            let groupMembers = state.groupMembersCache[schedule.groupId]
            state.path.append(.scheduleDetail(.init(
              schedule: schedule,
              currentUserId: state.currentUser.userId,
              groupMembers: groupMembers
            )))
            return .none

          case .seeAllUpcomingTapped:
            return .send(.delegate(.navigateToAllSchedules))

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

          case .recurringPersonalEventTapped(let instance):
            if let events = state.recurringEventsState.value,
               let recurring = events.first(where: { $0.id == instance.recurringEventId }) {
              state.path.append(.recurringPersonalEventDetail(.init(
                recurringEvent: recurring,
                selectedInstance: instance
              )))
            }
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
                let placeholder = "-"
                let generatedAtText = generatedDate?.formatted(date: .abbreviated, time: .shortened) ?? placeholder
                let summaryText = {
                  guard let summary = briefing?.summary, !summary.isEmpty else { return placeholder }
                  return summary
                }()
                let detailText = {
                  guard let detail = briefing?.detail, !detail.isEmpty else { return placeholder }
                  return detail
                }()
                let subject = LocalizedStrings.Home.briefingReportMailSubject
                let body = LocalizedStrings.Home.briefingReportMailBody(
                  userId,
                  generatedAtText,
                  summaryText,
                  detailText,
                  notificationDenied ? "false" : "true",
                  locationDenied ? "false" : "true",
                  TimeZone.current.identifier,
                  LocaleManager.appLocale.identifier
                )

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
            state.overlaySchedulesByMonth.removeAll()
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
            state.overlayCreateSchedule = nil
            state.overlaySchedulesByMonth.removeAll()
            state.overlayLoadedMonths.removeAll()
            state.overlayPersonalEventsByMonth.removeAll()
            state.overlayLoadedPersonalEventMonths.removeAll()
            state.overlayHolidaysByDate.removeAll()
            state.overlayLoadedHolidayYears.removeAll()
            return .cancel(id: CancelID.overlayWeatherFetch)

          case .overlayDateSelected(let date):
            state.overlaySelectedDate = date
            let calendar = Calendar.scheduleDisplay
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
            if let prev = Calendar.scheduleDisplay.date(byAdding: .month, value: -1, to: state.overlayCalendarMonth) {
              state.overlayCalendarMonth = prev
            }
            return .merge(
              .send(.internal(.fetchOverlaySchedules(month: state.overlayCalendarMonth))),
              .send(.internal(.fetchOverlayPersonalEvents(month: state.overlayCalendarMonth)))
            )

          case .overlayNextMonth:
            if let next = Calendar.scheduleDisplay.date(byAdding: .month, value: 1, to: state.overlayCalendarMonth) {
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
            case .schedule(let schedule):
              let groupMembers = state.groupMembersCache[schedule.groupId]
              state.overlayScheduleDetail = OverlayScheduleDetail.Feature.State(
                item: item,
                currentUserId: state.currentUser.userId,
                groupMembers: groupMembers
              )
              state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
              state.overlayCalendarMode = .scheduleDetail
              return .none
            case .personalEvent:
              // 개인 일정도 오버레이 내에서 인라인 표시
              state.overlayScheduleDetail = OverlayScheduleDetail.Feature.State(
                item: item,
                currentUserId: state.currentUser.userId
              )
              state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
              state.overlayCalendarMode = .scheduleDetail
              return .none
            case .recurringPersonalEvent:
              state.overlayScheduleDetail = OverlayScheduleDetail.Feature.State(
                item: item,
                currentUserId: state.currentUser.userId
              )
              state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
              state.overlayCalendarMode = .scheduleDetail
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
            let calendar = Calendar.scheduleDisplay
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

          case .overlayCreateScheduleTapped:
            // 오버레이 내에서 일정 생성 인라인 표시
            state.overlayCreateSchedule = CreateSchedule.Feature.State(
              groupSummaries: state.currentUser.groups.isEmpty ? nil : Array(state.currentUser.groups),
              currentUserId: state.currentUser.userId
            )
            state.overlayCalendarModeBeforeFeature = state.overlayCalendarMode
            state.overlayCalendarMode = .scheduleCreate
            return .none

          case .overlayScheduleDetailBackTapped:
            // 모드만 먼저 전환 (전환 애니메이션 동안 콘텐츠 유지)
            state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
            state.overlayCalendarModeBeforeFeature = nil
            return .run { send in
              try await Task.sleep(for: .milliseconds(500))
              await send(.internal(.clearOverlayScheduleDetail))
            }

          case .overlayCreateScheduleBackTapped:
            state.overlayCreateSchedule = nil
            state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
            state.overlayCalendarModeBeforeFeature = nil
            return .none

          case .departureAlertTapped(let item):
            guard state.isPro else {
              return .none
            }
            guard let location = item.location,
                  let lat = location.latitude,
                  let lng = location.longitude else {
              return .none
            }
            state.departureAlertItem = item
            state.departureTransportData = .loading

            // 직전 일정 찾기 (같은 날, 대상보다 이른 것 중 가장 가까운 것)
            let todayItems = state.homeContentSnapshot.todayScheduleItems
            let previousItem = todayItems
              .filter { $0.startAt < item.startAt && $0.id != item.id }
              .last(where: { schedule in
                guard let loc = schedule.location,
                      loc.latitude != nil,
                      loc.longitude != nil else { return false }
                return true
              })
            if let prev = previousItem,
               let prevLoc = prev.location,
               let prevLat = prevLoc.latitude,
               let prevLng = prevLoc.longitude {
              let prevInfo = HomeModels.PreviousScheduleLocation(
                name: prev.title,
                locationName: prevLoc.name,
                latitude: prevLat,
                longitude: prevLng
              )
              state.previousScheduleLocation = prevInfo
              // 직전 일정이 있으면 디폴트 출발지로 설정
              state.departureOrigin = .previousSchedule(
                name: prevLoc.name,
                latitude: prevLat,
                longitude: prevLng
              )
            } else {
              state.previousScheduleLocation = nil
              state.departureOrigin = .currentLocation
            }

            let scheduleItemId = item.id
            let userId = state.currentUser.userId
            let usePreviousOrigin = state.previousScheduleLocation
            return .run { [locationClient, transportationClient, userSettingsClient] send in
              // 현재 위치와 설정을 병렬로 조회
              async let locationTask: Coordinate = {
                do {
                  // 권한 거부 시 liveUpdates() 스트림이 멈추므로 타임아웃 + 권한 재체크
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
                  return location
                } catch {
                  // 직전 일정이 있으면 현재 위치 실패해도 진행 가능
                  if usePreviousOrigin == nil {
                    throw error
                  }
                  // 현재 위치 없이 진행
                  return Coordinate(latitude: 0, longitude: 0)
                }
              }()

              async let settingsTask: Set<AvailableTransport> = {
                do {
                  let settings = try await userSettingsClient.fetchSettings(userId)
                  return settings.availableTransports
                } catch {
                  return [.transit, .car]
                }
              }()

              let currentLocation: Coordinate
              do {
                currentLocation = try await locationTask
                AppLogger.home.debug("📍 [DepartureAlert] 위치 조회 성공 — (\(currentLocation.latitude), \(currentLocation.longitude))")
              } catch {
                AppLogger.home.debug("❌ [DepartureAlert] 위치 조회 실패 — \(error)")
                await send(.internal(.transportationResponse(
                  scheduleItemId,
                  .failure(LocationClientError.denied)
                )))
                return
              }

              let availableTransports = await settingsTask

              // 현재 위치 저장 (0,0이 아닌 경우만)
              if currentLocation.latitude != 0 || currentLocation.longitude != 0 {
                let locationName = try? await locationClient.reverseGeocode(currentLocation)
                await send(.internal(.departureLocationResolved(locationName)))
                await send(.internal(.currentLocationStored(currentLocation)))
              }

              // 출발 좌표 결정: 직전 일정 있으면 그 좌표, 없으면 현재 위치
              let fromLat: Double
              let fromLng: Double
              if let prev = usePreviousOrigin {
                fromLat = prev.latitude
                fromLng = prev.longitude
              } else {
                fromLat = currentLocation.latitude
                fromLng = currentLocation.longitude
              }

              AppLogger.home.debug("📍 [DepartureAlert] 경로 조회 시작 — from: (\(fromLat), \(fromLng)) → to: (\(lat), \(lng))")
              let result = await Result {
                try await transportationClient.getTransportation(
                  fromLat, fromLng,
                  lat, lng
                )
              }
              switch result {
              case .success(let data):
                AppLogger.home.debug("✅ [DepartureAlert] 경로 조회 성공 — driving: \(data.driving != nil), transit: \(data.transitRoutes.count)개, walking: \(data.walkingMinutes)분")
              case .failure(let error):
                AppLogger.home.debug("❌ [DepartureAlert] 경로 조회 실패 — \(error)")
              }
              await send(.internal(.transportationResponse(scheduleItemId, result, availableTransports)))
            }
            .cancellable(id: CancelID.transportationFetch)

          case .departureAlertRetryTapped:
            guard let item = state.departureAlertItem else { return .none }
            // 위치 권한 거부 상태에서 출발 좌표가 없으면 재시도 의미 없음 (설정 유도)
            if state.isLocationDenied
              && state.currentLocationCoordinate == nil
              && state.previousScheduleLocation == nil {
              return .none
            }
            if state.currentLocationCoordinate != nil {
              // 좌표가 있으면 현재 origin 기준 재시도
              return .send(.view(.departureOriginChanged(state.departureOrigin)))
            } else {
              // 좌표가 없으면 전체 재시도 (위치 권한 등)
              return .send(.view(.departureAlertTapped(item)))
            }

          case .departureAlertSheetDismissed:
            state.departureAlertItem = nil
            state.departureTransportData = .idle
            state.departureLocationName = nil
            state.previousScheduleLocation = nil
            state.departureOrigin = .currentLocation
            state.currentLocationCoordinate = nil
            return .cancel(id: CancelID.transportationFetch)

          case .departureAlertConfirmed(let selection, let bufferMinutes):
            return .send(.internal(.scheduleAlertForSelection(selection, bufferMinutes)))

          case .departureAlertDetailTapped:
            guard let item = state.departureAlertItem,
                  let data = state.departureTransportData.value else {
              return .none
            }
            // 시트 닫고 NavigationStack으로 push
            state.departureAlertItem = nil
            state.departureTransportData = .idle
            // 출발지 좌표 결정
            let originCoordinate: Coordinate? = switch state.departureOrigin {
            case .currentLocation:
              state.currentLocationCoordinate
            case .previousSchedule:
              state.previousScheduleLocation.map {
                Coordinate(latitude: $0.latitude, longitude: $0.longitude)
              }
            }
            let originName: String? = switch state.departureOrigin {
            case .currentLocation:
              state.departureLocationName
            case .previousSchedule:
              state.previousScheduleLocation?.locationName
            }
            // 도착지 좌표
            guard let location = item.location,
                  let destLat = location.latitude,
                  let destLng = location.longitude else {
              return .none
            }
            let destCoord = Coordinate(latitude: destLat, longitude: destLng)
            let destName = location.name

            state.path.append(.transportDetail(.init(
              scheduleTitle: item.title,
              scheduleEmoji: item.displayEmoji,
              scheduleStartAt: item.startAt,
              transportData: data,
              originCoordinate: originCoordinate,
              originName: originName,
              destinationCoordinate: destCoord,
              destinationName: destName
            )))
            return .cancel(id: CancelID.transportationFetch)

          case .departureAlertCancelTapped(let scheduleItemId):
            state.departureAlerts[scheduleItemId] = nil
            let alertsAfterCancel = state.departureAlerts
            let notificationId = "departure_alert_\(scheduleItemId)"
            return .run { [localNotificationClient, userDefaultsClient] _ in
              Self.saveDepartureAlerts(alertsAfterCancel, userDefaultsClient: userDefaultsClient)
              await localNotificationClient.cancel(notificationId)
            }

          case .departureOriginChanged(let origin):
            guard let item = state.departureAlertItem,
                  let location = item.location,
                  let toLat = location.latitude,
                  let toLng = location.longitude else {
              return .none
            }
            state.departureOrigin = origin

            let fromLat: Double
            let fromLng: Double

            switch origin {
            case .currentLocation:
              guard let coord = state.currentLocationCoordinate else {
                // 위치 권한 없어서 좌표가 없으면 에러 표시
                state.departureTransportData = .failed(LocationClientError.denied)
                return .none
              }
              fromLat = coord.latitude
              fromLng = coord.longitude
            case .previousSchedule(_, let latitude, let longitude):
              fromLat = latitude
              fromLng = longitude
            }

            state.departureTransportData = .loading
            let scheduleItemId = item.id
            let userId = state.currentUser.userId

            return .run { [transportationClient, userSettingsClient] send in
              let availableTransports: Set<AvailableTransport>
              do {
                let settings = try await userSettingsClient.fetchSettings(userId)
                availableTransports = settings.availableTransports
              } catch {
                availableTransports = [.transit, .car]
              }

              let result = await Result {
                try await transportationClient.getTransportation(
                  fromLat, fromLng,
                  toLat, toLng
                )
              }
              await send(.internal(.transportationResponse(scheduleItemId, result, availableTransports)))
            }
            .cancellable(id: CancelID.transportationFetch)

          case .departureAlertOpenSettingsTapped:
            return .run { [openURL] _ in
              if let url = URL(string: UIApplication.openSettingsURLString) {
                await openURL(url)
              }
            }

          case .emptyCreatePersonalEventTapped:
            let startAt = Date().addingTimeInterval(3600)
            state.createPersonalEvent = CreatePersonalEvent.Feature.State(
              event: PersonalEventModel(startAt: startAt)
            )
            return .none

          case .emptyCreateScheduleTapped:
            state.createSchedule = CreateSchedule.Feature.State(
              groupSummaries: state.currentUser.groups.isEmpty ? nil : Array(state.currentUser.groups),
              currentUserId: state.currentUser.userId
            )
            return .none

          case .emptyCreateRecurringEventTapped:
            state.createRecurringEvent = CreateRecurringPersonalEvent.Feature.State()
            return .none

          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchSchedules:
            // 기존 데이터가 없을 때만 로딩 상태 표시 (깜빡임 방지)
            if state.schedulesState.value == nil {
              state.schedulesState = .loading
            }

            // 그룹이 없으면 빈 배열 반환
            var seenGroupIds = Set<String>()
            let groupIds = state.currentUser.groups.compactMap { groupInfo in
              seenGroupIds.insert(groupInfo.id).inserted ? groupInfo.id : nil
            }
            guard !groupIds.isEmpty else {
              state.schedulesState = .loaded([])
              state.refreshHomeContentSnapshot()
              return .merge(
                .send(.internal(.fetchUnreadNotificationCount)),
                .send(.internal(.fetchWeather)),
                .send(.internal(.fetchBriefing()))
              )
            }

            return .run { [scheduleClient] send in
              do {
                let schedules = try await scheduleClient.getHomeSchedules(groupIds, 10)
                await send(.internal(.schedulesResponse(.success(schedules))))
              } catch {
                await send(.internal(.schedulesResponse(.failure(error))))
              }
            }

          case .schedulesResponse(let result):
            switch result {
            case .success(let schedules):
              // 그룹 정보 매핑 (UserGroupInfo → GroupModel 변환)
              var groupsDict: [String: UserGroupInfo] = [:]
              for groupInfo in state.currentUser.groups {
                groupsDict[groupInfo.id] = groupInfo
              }
              let schedulesWithGroup = schedules.map { schedule in
                var mutableSchedule = schedule
                if let groupInfo = groupsDict[schedule.groupId] {
                  mutableSchedule.group = GroupModel(
                    id: groupInfo.id,
                    name: groupInfo.name,
                    imageUrl: groupInfo.imageUrl,
                    maxMembers: 0,
                    inviteCode: "",
                    createdBy: ""
                  )
                }
                return mutableSchedule
              }
              state.schedulesState = .loaded(schedulesWithGroup)
              state.refreshHomeContentSnapshot()

              // 위젯 캐시 업데이트 (확정된 일정만)
              WidgetDataManager.saveSchedules(
                schedulesWithGroup.filter(\.isConfirmed).toWidgetData()
              )
              WidgetDataManager.reloadWidgets()

              // 일정 로드 성공 시 알림 개수 + 날씨 + 브리핑 조회
              return .merge(
                .send(.internal(.fetchUnreadNotificationCount)),
                .send(.internal(.fetchWeather)),
                .send(.internal(.fetchBriefing()))
              )

            case .failure(let error):
              state.schedulesState = .failed(error)
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

          case .fetchRecurringEvents:
            return .run { [recurringPersonalEventClient] send in
              do {
                let events = try await recurringPersonalEventClient.getAllEvents()
                await send(.internal(.recurringEventsResponse(.success(events))))
              } catch {
                await send(.internal(.recurringEventsResponse(.failure(error))))
              }
            }

          case .recurringEventsResponse(let result):
            switch result {
            case .success(let events):
              state.recurringEventsState = .loaded(events)
              state.refreshHomeContentSnapshot()
              return .none
            case .failure:
              if !state.recurringEventsState.isLoaded {
                state.recurringEventsState = .loaded([])
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
            let schedules = state.allSchedules.filter { schedule in
              let hasLat = schedule.location?.latitude != nil
              let hasLng = schedule.location?.longitude != nil
              let notPast = !schedule.isPast
              let notCached = cachedIds[schedule.id] == nil
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
              let hour = Calendar.scheduleDisplay.component(.hour, from: date)
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

            for schedule in schedules where schedule.startAt < maxDate {
              guard let lat = schedule.location?.latitude,
                    let lng = schedule.location?.longitude else { continue }
              upsertTarget(
                scheduleId: schedule.id,
                lat: lat,
                lng: lng,
                date: schedule.startAt
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
              state.overlaySchedulesByMonth[monthStart] = []
              return .none
            }

            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

            return .merge(
              .run { [scheduleClient] send in
                do {
                  let schedules = try await scheduleClient.getSchedulesByDateRange(groupIds, monthStart, endDate)
                  await send(.internal(.overlaySchedulesResponse(month: monthStart, .success(schedules))))
                } catch {
                  await send(.internal(.overlaySchedulesResponse(month: monthStart, .failure(error))))
                }
              },
              .send(.internal(.prefetchOverlayAdjacentMonths))
            )

          case .overlaySchedulesResponse(let month, let result):
            switch result {
            case .success(let schedules):
              var groupsDict: [String: UserGroupInfo] = [:]
              for groupInfo in state.currentUser.groups {
                groupsDict[groupInfo.id] = groupInfo
              }
              let schedulesWithGroup = schedules.map { schedule in
                var mutableSchedule = schedule
                if let groupInfo = groupsDict[schedule.groupId] {
                  mutableSchedule.group = GroupModel(
                    id: groupInfo.id,
                    name: groupInfo.name,
                    imageUrl: groupInfo.imageUrl,
                    maxMembers: 0,
                    inviteCode: "",
                    createdBy: ""
                  )
                }
                return mutableSchedule
              }
              state.overlaySchedulesByMonth[month] = schedulesWithGroup
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
            // 기존 브리핑이 없거나 강제 새로고침일 때만 로딩 표시 (탭 전환 시 깜빡임 방지)
            if !state.briefingState.isLoaded || forceRefresh {
              state.briefingState = .loading
            }
            return .run { [locationClient, briefingClient, forceRefresh] send in
              let input = await Self.buildBriefingInput(
                locationClient: locationClient,
                forceRefresh: forceRefresh
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

          case .transportationResponse(let scheduleItemId, let result, let availableTransports):
            guard let item = state.departureAlertItem,
                  item.id == scheduleItemId else {
              return .none
            }
            switch result {
            case .success(let transportation):
              let itemStartAt = item.startAt

              // 자동차 (buffer=0 기준 출발시간)
              let drivingOption: HomeModels.TransportOption?
              if let driving = transportation.driving {
                let departureTime = itemStartAt.addingTimeInterval(-Double(driving.duration * 60))
                var info: String? = nil
                if driving.toll > 0 {
                  let tollAmount = Decimal(driving.toll).formatted(.currency(code: "KRW"))
                  info = LocalizedStrings.Home.transportTollAmount(tollAmount)
                }
                drivingOption = .init(
                  type: .driving,
                  durationMinutes: driving.duration,
                  departureTime: departureTime,
                  additionalInfo: info,
                  distanceMeters: driving.distance
                )
              } else {
                drivingOption = nil
              }

              // 대중교통 경로 배열 변환 (buffer=0 기준 출발시간)
              let transitRoutes: [HomeModels.TransitRouteOption] = transportation.transitRoutes.enumerated().map { index, route in
                let departureTime = itemStartAt.addingTimeInterval(-Double(route.totalTime * 60))
                let subPaths = route.subPaths.map { subPath -> HomeModels.TransportSubPath in
                  let laneName: String?
                  if let firstLane = subPath.lanes.first {
                    laneName = firstLane.name ?? firstLane.busNo
                  } else {
                    laneName = nil
                  }
                  return HomeModels.TransportSubPath(
                    trafficType: subPath.trafficType,
                    sectionTime: subPath.sectionTime,
                    distance: subPath.distance,
                    startName: subPath.startName,
                    endName: subPath.endName,
                    stationCount: subPath.stationCount,
                    laneName: laneName
                  )
                }
                return HomeModels.TransitRouteOption(
                  id: index,
                  totalTime: route.totalTime,
                  payment: route.payment,
                  busTransitCount: route.busTransitCount,
                  subwayTransitCount: route.subwayTransitCount,
                  pathType: route.pathType,
                  departureTime: departureTime,
                  subPaths: subPaths
                )
              }

              // 도보 (buffer=0 기준 출발시간)
              let walkDepartureTime = itemStartAt.addingTimeInterval(-Double(transportation.walkingMinutes * 60))
              let walkingOption = HomeModels.TransportOption(
                type: .walking,
                durationMinutes: transportation.walkingMinutes,
                departureTime: walkDepartureTime,
                distanceMeters: transportation.walkingDistanceMeters
              )

              let transportData = HomeModels.DepartureTransportData(
                driving: drivingOption,
                transitRoutes: HomeModels.DepartureTransportData.categorizeTransitRoutes(transitRoutes),
                walking: walkingOption,
                availableTransports: availableTransports
              )
              state.departureTransportData = .loaded(transportData)

            case .failure(let error):
              state.departureTransportData = .failed(error)
              // 시트가 열려 있으면 인라인 에러로 표시하므로 토스트 불필요
              if state.departureAlertItem == nil {
                if error is LocationClientError {
                  state.toastMessage = ToastMessage(type: .error, title: LocalizedStrings.Home.departureLocationPermissionRequired)
                } else {
                  state.toastMessage = ToastMessage(type: .error, title: LocalizedStrings.Home.departureTransportLoadFailed)
                }
              }
            }
            return .none

          case .scheduleAlertForSelection(let selection, let bufferMinutes):
            guard let item = state.departureAlertItem,
                  let data = state.departureTransportData.value else {
              return .none
            }
            let scheduleItemId = item.id
            let durationMinutes: Int
            let rawDepartureTime: Date
            let transportType: HomeModels.TransportType
            switch selection {
            case .driving:
              guard let opt = data.driving else { return .none }
              durationMinutes = opt.durationMinutes
              rawDepartureTime = opt.departureTime
              transportType = .driving
            case .transit(let index):
              guard let route = data.transitRoutes.first(where: { $0.id == index }) else { return .none }
              durationMinutes = route.totalTime
              rawDepartureTime = route.departureTime
              transportType = .transit
            case .walking:
              durationMinutes = data.walking.durationMinutes
              rawDepartureTime = data.walking.departureTime
              transportType = .walking
            }
            // buffer 적용한 실제 알림 트리거 시간
            let departureTime = rawDepartureTime.addingTimeInterval(-Double(bufferMinutes * 60))
            let alertInfo = HomeModels.DepartureAlertInfo(
              scheduleItemId: scheduleItemId,
              selectedTransport: transportType,
              durationMinutes: durationMinutes,
              departureTime: departureTime
            )
            state.departureAlerts[scheduleItemId] = alertInfo
            let alertsAfterSchedule = state.departureAlerts
            state.departureAlertItem = nil
            state.departureTransportData = .idle
            let notificationId = "departure_alert_\(scheduleItemId)"
            let timeText = item.startAt.formattedTime
            let transport = transportType.displayName

            typealias NotificationTemplate = (
              title: (String) -> String,
              body: (String, String, Int, Int) -> String
            )

            let templates: [NotificationTemplate] = [
              (
                title: { LocalizedStrings.Home.departureNotificationTitleSoon($0) },
                body: { time, trans, duration, buffer in
                  buffer > 0
                    ? LocalizedStrings.Home.departureNotificationBodySoonWithBuffer(time, trans, duration, buffer)
                    : LocalizedStrings.Home.departureNotificationBodySoon(time, trans, duration)
                }
              ),
              (
                title: { LocalizedStrings.Home.departureNotificationTitleNow($0) },
                body: { time, trans, duration, buffer in
                  buffer > 0
                    ? LocalizedStrings.Home.departureNotificationBodyNowWithBuffer(time, trans, duration, buffer)
                    : LocalizedStrings.Home.departureNotificationBodyNow(time, trans, duration)
                }
              ),
              (
                title: { LocalizedStrings.Home.departureNotificationTitleReady($0) },
                body: { time, trans, duration, buffer in
                  buffer > 0
                    ? LocalizedStrings.Home.departureNotificationBodyReadyWithBuffer(time, trans, duration, buffer)
                    : LocalizedStrings.Home.departureNotificationBodyReady(time, trans, duration)
                }
              ),
            ]

            // swiftlint:disable:next force_unwrapping
            let template = templates.randomElement()!
            let title = template.title(item.title)
            let body = template.body(timeText, transport, durationMinutes, bufferMinutes)
            let triggerDate = departureTime
            return .run { [localNotificationClient, userDefaultsClient] send in
              Self.saveDepartureAlerts(alertsAfterSchedule, userDefaultsClient: userDefaultsClient)
              do {
                try await localNotificationClient.schedule(
                  notificationId, title, body, triggerDate,
                  ["type": "departure_alert", "scheduleItemId": scheduleItemId]
                )
              } catch {
                // 알림 스케줄 실패해도 출발시간 표시를 위해 상태는 유지
              }
              await send(.internal(.departureAlertScheduled(alertInfo)))
            }

          case .departureAlertScheduled:
            state.toastMessage = ToastMessage(type: .success, title: LocalizedStrings.Home.departureAlertScheduled)
            return .none

          case .departureLocationResolved(let name):
            state.departureLocationName = name
            return .none

          case .currentLocationStored(let coordinate):
            state.currentLocationCoordinate = coordinate
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

        // MARK: - CreateRecurringEvent Delegate

        case .createRecurringEvent(.presented(.delegate(.eventCreated))),
             .createRecurringEvent(.presented(.delegate(.eventUpdated(_)))):
          state.createRecurringEvent = nil
          return .send(.internal(.fetchRecurringEvents))

        case .createRecurringEvent(.presented(.delegate(.dismiss))):
          state.createRecurringEvent = nil
          return .none

        case .createRecurringEvent:
          return .none

        // MARK: - CreateSchedule (Sheet) Delegate

        case .createSchedule(.presented(.delegate(.scheduleCreated(_)))):
          state.createSchedule = nil
          return .send(.internal(.fetchSchedules))

        case .createSchedule(.presented(.delegate(.dismiss))):
          state.createSchedule = nil
          return .none

        case .createSchedule(.presented(.delegate(.createGroupRequested))):
          state.createSchedule = nil
          return .send(.delegate(.navigateToCreateSchedule))

        case .createSchedule:
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
          case .schedule(let schedule):
            let groupMembers = state.groupMembersCache[schedule.groupId]
            state.path.append(.scheduleDetail(.init(
              schedule: schedule,
              currentUserId: state.currentUser.userId,
              groupMembers: groupMembers
            )))
          case .personalEvent(let event):
            state.path.append(.personalEventDetail(.init(event: event)))
          case .recurringPersonalEvent(let instance):
            if let events = state.recurringEventsState.value,
               let recurring = events.first(where: { $0.id == instance.recurringEventId }) {
              state.path.append(.recurringPersonalEventDetail(.init(
                recurringEvent: recurring,
                selectedInstance: instance
              )))
            }
          }
          return .cancel(id: CancelID.overlayWeatherFetch)

        case .overlayScheduleDetail(.delegate(.scheduleResponseUpdated(let schedule))):
          // 오버레이 캐시 업데이트
          let monthKey = schedule.startAt.startOfMonth
          if let index = state.overlaySchedulesByMonth[monthKey]?.firstIndex(where: { $0.id == schedule.id }) {
            state.overlaySchedulesByMonth[monthKey]?[index] = schedule
          }
          // 홈 일정 목록도 업데이트
          if case .loaded(var schedules) = state.schedulesState,
             let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            state.schedulesState = .loaded(schedules)
            state.refreshHomeContentSnapshot()
          }
          return .none

        case .overlayScheduleDetail:
          return .none

        // MARK: - Overlay Create Schedule Actions

        case .overlayCreateSchedule(.delegate(.scheduleCreated)):
          state.overlayCreateSchedule = nil
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          // 일정이 어느 월에 생성되었을지 모르므로 전체 캐시 무효화
          state.overlayLoadedMonths.removeAll()
          state.overlaySchedulesByMonth.removeAll()
          let month = state.overlaySelectedDate.startOfMonth
          return .merge(
            .send(.internal(.fetchSchedules)),
            .send(.internal(.fetchOverlaySchedules(month: month)))
          )

        case .overlayCreateSchedule(.delegate(.dismiss)):
          state.overlayCreateSchedule = nil
          state.overlayCalendarMode = state.overlayCalendarModeBeforeFeature ?? .weekly
          state.overlayCalendarModeBeforeFeature = nil
          return .none

        case .overlayCreateSchedule(.delegate(.createGroupRequested)):
          // 그룹 생성은 오버레이에서 불가 → 오버레이 닫고 기존 플로우로 위임
          state.overlayCreateSchedule = nil
          state.overlayCalendarModeBeforeFeature = nil
          state.showCalendarOverlay = false
          state.overlayCalendarMode = .monthly
          return .merge(
            .cancel(id: CancelID.overlayWeatherFetch),
            .send(.delegate(.navigateToCreateSchedule))
          )

        case .overlayCreateSchedule:
          return .none

        case .delegate:
          return .none

        // MARK: - Path Actions

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.scheduleDeleted)))):
          _ = state.path.popLast()
          // 오버레이 캐시 무효화
          let deletedMonth = state.overlaySelectedDate.startOfMonth
          state.overlayLoadedMonths.remove(deletedMonth)
          state.overlaySchedulesByMonth.removeValue(forKey: deletedMonth)
          return .merge(
            .send(.internal(.fetchSchedules)),
            state.showCalendarOverlay ? .send(.internal(.fetchOverlaySchedules(month: deletedMonth))) : .none
          )

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.scheduleUpdated)))):
          // 오버레이 캐시 무효화
          let updatedMonth = state.overlaySelectedDate.startOfMonth
          state.overlayLoadedMonths.remove(updatedMonth)
          state.overlaySchedulesByMonth.removeValue(forKey: updatedMonth)
          return .merge(
            .send(.internal(.fetchSchedules)),
            state.showCalendarOverlay ? .send(.internal(.fetchOverlaySchedules(month: updatedMonth))) : .none
          )

        // MARK: - PersonalEventDetail Path Actions

        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventDeleted)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchPersonalEvents))

        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventUpdated)))):
          return .send(.internal(.fetchPersonalEvents))

        // MARK: - RecurringPersonalEventDetail Path Actions

        case .path(.element(id: _, action: .recurringPersonalEventDetail(.delegate(.eventDeleted)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchRecurringEvents))

        case .path(.element(id: _, action: .recurringPersonalEventDetail(.delegate(.eventUpdated)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchRecurringEvents))

        // MARK: - NotificationCenter Path Actions

        case .path(.element(id: _, action: .notificationCenter(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .send(.internal(.fetchUnreadNotificationCount))

        case .path(.element(id: _, action: .notificationCenter(.delegate(.navigateToSchedule(let scheduleId, let groupId))))):
          _ = state.path.popLast()
          return .send(.delegate(.navigateToSchedule(scheduleId: scheduleId, groupId: groupId)))

        case .path(.element(id: _, action: .notificationCenter(.delegate(.navigateToGroup(let groupId))))):
          _ = state.path.popLast()
          return .send(.delegate(.navigateToGroupWithSchedule(groupId: groupId, scheduleId: "")))

        case .path(.element(id: _, action: .notificationCenter(.delegate(.refreshBadgeCount)))):
          return .send(.internal(.fetchUnreadNotificationCount))

        // MARK: - TransportDetail Path Actions

        case .path(.element(id: _, action: .transportDetail(.delegate(.alertRequested(let selection, let bufferMinutes))))):
          return .send(.internal(.scheduleAlertForSelection(selection, bufferMinutes)))

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
      .ifLet(\.$createPersonalEvent, action: \.createPersonalEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.$createRecurringEvent, action: \.createRecurringEvent) {
        CreateRecurringPersonalEvent.Feature()
      }
      .ifLet(\.$createSchedule, action: \.createSchedule) {
        CreateSchedule.Feature()
      }
      .ifLet(\.overlayScheduleDetail, action: \.overlayScheduleDetail) {
        OverlayScheduleDetail.Feature()
      }
      .ifLet(\.overlayCreateSchedule, action: \.overlayCreateSchedule) {
        CreateSchedule.Feature()
      }

    }

    // MARK: - Departure Alert Persistence

    private static let departureAlertsKey = "departure_alerts_v1"

    /// 출발 알림 만료 유지 시간 (초)
    private static let departureAlertRetentionInterval: TimeInterval = 3600

    private static func saveDepartureAlerts(
      _ alerts: [String: HomeModels.DepartureAlertInfo],
      userDefaultsClient: UserDefaultsClient
    ) {
      // 만료된 알림 제거 후 저장
      let activeAlerts = alerts.filter {
        $0.value.departureTime > Date().addingTimeInterval(-departureAlertRetentionInterval)
      }
      do {
        let data = try JSONEncoder().encode(activeAlerts)
        userDefaultsClient.setString(
          data.base64EncodedString(),
          departureAlertsKey
        )
      } catch {
        AppLogger.home.error("Failed to encode departure alerts for persistence: \(error)")
      }
    }

    private static func loadDepartureAlerts(
      userDefaultsClient: UserDefaultsClient
    ) -> [String: HomeModels.DepartureAlertInfo] {
      guard let base64 = userDefaultsClient.stringForKey(departureAlertsKey),
            let data = Data(base64Encoded: base64) else {
        return [:]
      }
      do {
        let alerts = try JSONDecoder().decode([String: HomeModels.DepartureAlertInfo].self, from: data)
        // 만료된 알림 제거
        return alerts.filter {
          $0.value.departureTime > Date().addingTimeInterval(-departureAlertRetentionInterval)
        }
      } catch {
        AppLogger.home.error("Failed to decode departure alerts from persistence: \(error)")
        return [:]
      }
    }

    // MARK: - Briefing Helpers

    private static func buildBriefingInput(
      locationClient: LocationClient,
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
        language: AppLanguage.resolved.rawValue,
        location: location,
        forceRefresh: forceRefresh
      )

      AppLogger.briefing.debug("📋 브리핑 요청: timezone=\(input.timezone), location=\(location?.title ?? "없음"), forceRefresh=\(forceRefresh)")

      return input
    }
  }
}
