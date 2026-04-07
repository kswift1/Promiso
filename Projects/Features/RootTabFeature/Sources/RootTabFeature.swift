// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer

import Combine
import ExternalDependency
@preconcurrency import StoreKit
import SwiftUI

// StoreKit import로 인한 SubscriptionStatus 이름 충돌 해소
public typealias SubscriptionStatus = Clients.SubscriptionStatus

import Clients
import PromisoShared
import CalendarFeature
import PersonalFeature
import SettingsFeature
import ResourceKit
import SharedFeature

// MARK: - Notifications
// ⚠️ TCA 상태 관찰(onChange, task)로 @State를 동기화하면 zoom transition이 깨짐
// NotificationCenter를 사용하여 TCA Reducer → SwiftUI View로 이벤트 전달

extension Notification.Name {
  /// 딥링크로 LiveScheduleDetail 열기 요청 (TCA Reducer → View)
  /// - 탭으로 열 때: @State 직접 토글 → zoom transition 동작
  /// - 딥링크로 열 때: Notification 수신 → @State 토글 → zoom transition 보존
  static let openLiveScheduleDetailFromDeeplink = Notification.Name("openLiveScheduleDetailFromDeeplink")
}

public enum Tab: Equatable, Hashable {
  case home
  case schedule(ScheduleTabMode = .group)
  case calendar
  case settings

  public enum ScheduleTabMode: String, Equatable, Hashable, Sendable {
    case group = "group"
    case own = "own"

    var displayTitle: String {
      switch self {
      case .group: return LocalizedStrings.RootTab.tabModeGroup
      case .own: return LocalizedStrings.RootTab.tabModePersonal
      }
    }
  }

  var isSchedule: Bool {
    if case .schedule = self { return true }
    return false
  }

  var scheduleMode: ScheduleTabMode? {
    if case .schedule(let mode) = self { return mode }
    return nil
  }

  var label: String {
    switch self {
    case .home: return LocalizedStrings.TabBar.home
    case .schedule(let mode): return mode.displayTitle
    case .calendar: return LocalizedStrings.TabBar.calendar
    case .settings: return LocalizedStrings.TabBar.settings
    }
  }

  var iconName: String {
    switch self {
    case .home: return "house.fill"
    case .schedule(.group): return "person.3.fill"
    case .schedule(.own): return "person.fill"
    case .calendar: return "calendar"
    case .settings: return "gearshape.fill"
    }
  }

  /// 탭 선택 시 적용할 Symbol Effects
  var symbolEffects: [any DiscreteSymbolEffect & SymbolEffect] {
    switch self {
    case .home, .settings:
      return [.bounce]
    case .schedule, .calendar:
      // Schedule 모드 토글 시 회전 + 바운스
      return [.wiggle.up]
    }
  }
}

// MARK: - Cache Keys

private enum CacheKeys {
  static let lastPushToStartToken = "lastPushToStartToken"
}

// MARK: - Feature Namespace

/// RootTab Feature 컴포넌트를 위한 Namespace
public enum RootTab {}

// MARK: - Reducer

extension RootTab {
  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.liveActivityClient) var liveActivityClient
    @Dependency(\.voteLiveActivityClient) var voteLiveActivityClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.scheduleClient) var scheduleClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.appReviewClient) var appReviewClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient

    private enum CancelID: Hashable {
      case subscriptionStatus
    }

    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 탭
      var selectedTab: Tab = .home

      /// Schedule 탭의 현재 모드 (탭 전환 시에도 유지)
      var scheduleMode: Tab.ScheduleTabMode

      /// 최초 onAppear에서 캘린더 동기화가 예약되었는지 추적
      var hasInitialCalendarSyncBeenScheduled: Bool = false

      /// 캘린더 동기화 실행 중 상태
      var isCalendarSyncInFlight: Bool = false

      /// Home Main State
      var home: Home.Feature.State

      /// Calendar State
      var calendar: CalendarFeature.Feature.State

      /// Group Main State
      var groupMain: GroupMain.Feature.State

      /// Settings State
      var settings: Settings.Feature.State

      /// Personal Mode State
      var personalMode: PersonalMode.Feature.State

      /// 현재 사용자 정보 (모든 탭에서 참조 공유)
      @Shared var currentUser: UserPrivateModel

      /// 테마 모드 (system/light/dark) — 설정 변경 시 preferredColorScheme 자동 갱신
      @Shared(.appStorage(AppConstants.UserDefaults.preferredThemeMode)) var themeMode: String = AppConstants.ThemeMode.system.rawValue

      /// 선호 언어 — 변경 시 뷰 트리 재구성 트리거
      @Shared(.appStorage(AppConstants.UserDefaults.preferredLanguage)) var preferredLanguage: String = ""

      /// 24시간 형식 — 변경 시 뷰 트리 재구성 트리거
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) var use24HourFormat: Bool = false

      /// LiveSchedule State (일정 추적 바) - nil이면 숨김
      var liveSchedule: LiveSchedule.Feature.State?

      /// LiveSchedule 상세 뷰 Presentation
      @Presents var liveScheduleDetail: LiveSchedule.Detail.State?

      /// Widget "직접 입력" 딥링크 pending 플래그
      /// Cold start 시 Activity 구독보다 딥링크가 먼저 도착하면 true로 설정,
      /// activityUpdateReceived에서 liveSchedule 생성 후 ETA 시트를 열기 위해 사용
      var pendingETASheetRequest: Bool = false

      /// 현재 구독 상태 (앱 레벨 모니터링)
      var subscriptionStatus: SubscriptionStatus = .none
      /// LiveSchedule 상세 딥링크 pending 플래그
      /// Cold start 시 Activity 구독보다 딥링크가 먼저 도착하면 true로 설정
      var pendingLiveScheduleDetailRequest: Bool = false

      /// 일정 탭 기본 모드 (Settings에서 설정)
      @Shared(.appStorage(AppConstants.UserDefaults.defaultScheduleTabMode)) var defaultScheduleTabMode: String = "group"

      /// 캘린더 기본 표시 모드 (Settings에서 설정)
      @Shared(.appStorage(AppConstants.UserDefaults.defaultCalendarDisplayMode)) var defaultCalendarDisplayMode: String = "month"

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
        // @Shared appStorage에서 일정 탭 기본 모드 읽기
        self.scheduleMode = _defaultScheduleTabMode.wrappedValue == "own" ? .own : .group
        self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
        self.home = Home.Feature.State(currentUser: currentUser)
        let savedCalendarMode = CalendarDisplayMode(rawValue: _defaultCalendarDisplayMode.wrappedValue) ?? .month
        self.calendar = CalendarFeature.Feature.State(currentUser: currentUser, displayMode: savedCalendarMode)
        self.settings = Settings.Feature.State(currentUser: currentUser)
        self.personalMode = PersonalMode.Feature.State(currentUser: currentUser)
      }
    }

    @CasePathable
    public enum Action {
      /// 앱이 나타날 때 호출
      case onAppear
      /// 탭이 선택되었을 때 호출
      case tabSelected(Tab)
      /// Home Main 액션
      case home(Home.Feature.Action)
      /// Calendar 액션
      case calendar(CalendarFeature.Feature.Action)
      /// Group Main 액션
      case groupMain(GroupMain.Feature.Action)
      /// Settings 액션
      case settings(Settings.Feature.Action)
      /// Personal Mode 액션
      case personalMode(PersonalMode.Feature.Action)
      /// LiveSchedule 액션
      case liveSchedule(LiveSchedule.Feature.Action)
      /// LiveSchedule 상세 뷰 액션
      case liveScheduleDetail(PresentationAction<LiveSchedule.Detail.Action>)
      /// 상위로 전달되는 델리게이트 액션
      case delegate(Delegate)
      /// 딥링크로 그룹 참여 열기
      case openJoinGroupWithCode(String)
      /// 그룹 탭 딥링크 처리
      case handleGroupDeeplink(GroupMain.Deeplink)
      /// Widget "직접 입력" 버튼 → LiveScheduleExpandedView + ETA 시트 열기
      case openLiveActivityETASheet
      /// LiveActivity 탭 → LiveScheduleExpandedView 열기 (ETA 시트 없이)
      case openLiveScheduleDetail
      /// Widget "일정 만들기" 버튼 → 그룹 탭 이동 + 일정 생성 (그룹 있을 때만)
      case openCreateScheduleIfPossible
      /// Widget 개인 일정 탭 → 홈 탭 이동 + 개인 일정 상세 열기
      case openPersonalEventDetail(eventId: String)
      /// 온보딩에서 그룹 생성 열기
      case openCreateGroup
      /// 딥링크에서 ProPlan 화면 열기
      case openProPlan
      /// Share Extension 텍스트 일정 추출 → 개인 탭 + CreatePersonalEvent 폼 열기
      case openExtractSchedule
      /// Scene phase 변경 (포그라운드 복귀 시 구독 상태 갱신)
      case scenePhaseChanged(ScenePhase)
      /// 내부 액션
      case `internal`(Internal)
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      /// Push to Start 토큰 구독 시작
      case observePushToStartToken
      /// Push to Start 토큰 수신
      case pushToStartTokenReceived(String)
      /// Widget용 Auth 토큰 갱신 (Firebase ID Token - 1시간)
      case refreshWidgetAuthToken
      /// Widget 전용 Long-lived Token 발급 요청 (30일)
      case requestWidgetToken
      /// LiveActivity 변화 구독 시작
      case observeActivityUpdates
      /// LiveActivity 변화 감지됨
      case activityUpdateReceived(ActivityUpdate)
      /// Vote LiveActivity 변화 구독 시작
      case observeVoteActivityUpdates
      /// Vote LiveActivity 변화 감지됨
      case voteActivityUpdateReceived(VoteActivityUpdate)
      /// 특정 Activity 상태 변화 구독 시작
      case observeActivityState(activityId: String)
      /// Activity 상태 변화 감지됨 (dismissed/ended)
      case activityStateChanged(ActivityStateValue)
      /// ETA 시트 열기 (딜레이 후)
      case openETASheetAfterDelay
      /// 캘린더 동기화 (백그라운드)
      case syncCalendar
      /// 구독 상태 모니터링 시작 (StoreKit + Firestore 통합)
      case observeSubscriptionStatus
      /// 구독 상태 변경 수신
      case subscriptionStatusChanged(SubscriptionStatus)
      /// 포그라운드 복귀 시 구독 상태 1회 갱신
      case refreshSubscriptionStatus
      /// 캘린더 동기화 완료 처리
      case syncCalendarFinished(success: Bool)
    }

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case logoutRequested
      case openJoinGroup(inviteCode: String)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: \.groupMain, action: \.groupMain) {
        GroupMain.Feature()
      }

      Scope(state: \.personalMode, action: \.personalMode) {
        PersonalMode.Feature()
      }

      Scope(state: \.home, action: \.home) {
        Home.Feature()
      }

      Scope(state: \.calendar, action: \.calendar) {
        CalendarFeature.Feature()
      }

      Scope(state: \.settings, action: \.settings) {
        Settings.Feature()
      }

      Reduce { state, action in
        switch action {
        case .onAppear:
          var effects: [Effect<Action>] = [
            .send(.internal(.refreshWidgetAuthToken)),
            .send(.internal(.requestWidgetToken)),
            .send(.internal(.observePushToStartToken)),
            .send(.internal(.observeActivityUpdates)),
            .send(.internal(.observeVoteActivityUpdates)),
            .send(.internal(.syncCalendar)),
            .send(.internal(.observeSubscriptionStatus))
          ]

          effects.append(
            .run { [appReviewClient] _ in
              appReviewClient.recordFirstLaunchIfNeeded()
              appReviewClient.incrementSessionCount()
            }
          )

          if !state.hasInitialCalendarSyncBeenScheduled {
            effects.append(.send(.internal(.syncCalendar)))
          }

          return .merge(effects)

        case .tabSelected(let tab):
          let previousTab = state.selectedTab
          state.selectedTab = tab

          let hapticEffect: Effect<Action> = .run { _ in await hapticFeedback.buttonTap() }

          guard tab != previousTab else {
            // Schedule 탭 재선택 시 모드 토글
            if case .schedule = tab {
              let newMode: Tab.ScheduleTabMode = state.scheduleMode == .group ? .own : .group
              state.scheduleMode = newMode
              state.selectedTab = .schedule(newMode)
              if newMode == .own {
                return .merge(hapticEffect, .send(.personalMode(.view(.onAppear))))
              }
            }
            // Calendar 탭 재선택 시 모드 순환
            if case .calendar = tab {
              return .merge(hapticEffect, .send(.calendar(.view(.toggleDisplayMode))))
            }
            return hapticEffect
          }

          var effects: [Effect<Action>] = [hapticEffect]

          // 탭 전환 시 각 Feature에 알림
          switch tab {
          case .home:
            effects.append(.send(.home(.view(.refreshNotificationBadge))))
          case .calendar:
            effects.append(.send(.calendar(.view(.refresh))))
          case .settings:
            // Analytics 이벤트 로깅
            analyticsClient.log(.settingsOpened)
          case .schedule:
            if state.scheduleMode == .group {
              effects.append(.send(.groupMain(.view(.tabReturned))))
            }
          }

          return .merge(effects)

        case .home(.delegate(.navigateToGroupWithSchedule(let groupId, let scheduleId))):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          // 그룹 선택 후 응답 필요 필터로 해당 일정 하이라이트
          return .send(.groupMain(.view(.handleDeeplink(
            .scheduleInList(scheduleId: scheduleId, groupId: groupId, filter: .needResponse)
          ))))

        case .home(.delegate(.navigateToSchedule(_, let groupId))):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          if let groupInfo = state.groupMain.allGroupSummaries?.first(where: { $0.id == groupId }) {
            return .send(.groupMain(.view(.groupChanged(groupInfo))))
          }
          return .none

        case .home(.delegate(.navigateToCreateSchedule)):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.openCreateScheduleIfPossible)))

        case .home(.delegate(.proPlanRequested)):
          state.selectedTab = .settings
          return .send(.settings(.view(.proPlanTapped)))

        case .home:
          return .none

        case .calendar:
          return .none

        case .groupMain(.view(.switchToPersonalMode)):
          state.scheduleMode = .own
          state.selectedTab = .schedule(.own)
          return .send(.personalMode(.view(.onAppear)))

        case .groupMain:
          return .none

        case .personalMode(.view(.switchToGroupMode)):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.tabReturned)))

        case .personalMode:
          return .none

        case .settings(.delegate(.didLogout)):
          return .send(.delegate(.logoutRequested))

        case .settings(.delegate(.subscriptionStatusChanged(let status))):
          return applySubscriptionStatus(status, state: &state)

        case .settings:
          return .none

        case .liveSchedule(.delegate(.showDetail)):
          // CompactView 탭 → 상세 뷰 표시 (같은 @Shared 전달)
          guard let liveSchedule = state.liveSchedule else { return .none }
          state.liveScheduleDetail = LiveSchedule.Detail.State(data: liveSchedule.$data)
          return .none

        case .liveSchedule:
          return .none

        case .liveScheduleDetail(.presented(.delegate(.updateETA(let minutes)))):
          // ExpandedView 시트에서 ETA 변경 → 서버 API 호출 → APNs Broadcast
          guard let attributes = liveActivityClient.currentAttributes(),
                let currentState = liveActivityClient.currentState() else {
            AppLogger.liveActivity.error("ETA 업데이트 실패: 활성 LiveActivity 없음")
            return .none
          }

          let channelId = attributes.channelId
          let scheduleId = attributes.scheduleId
          let trackingDurationMinutes = attributes.trackingDurationMinutes
          let userId = attributes.currentUserId

          // 현재 사용자의 ETA를 업데이트한 participants 생성
          let updatedParticipants = currentState.participants.map { participant in
            if participant.id == userId {
              return ParticipantState(
                id: participant.id,
                name: participant.name,
                estimatedArrivalMinutes: minutes
              )
            }
            return participant
          }

          AppLogger.liveActivity.info("ETA 업데이트 요청: channelId=\(channelId), minutes=\(minutes)")

          // 서버 API 호출 → APNs Broadcast로 모든 참가자(나 포함) 업데이트
          return .run { [scheduleClient] _ in
            do {
              try await scheduleClient.updateETA(
                scheduleId,
                channelId,
                updatedParticipants,
                trackingDurationMinutes
              )
              AppLogger.liveActivity.info("ETA 업데이트 성공: \(minutes)분")
            } catch {
              AppLogger.liveActivity.error("ETA 업데이트 실패: \(error.localizedDescription)")
            }
          }

        case .liveScheduleDetail:
          return .none

        case .openJoinGroupWithCode(let inviteCode):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.joinGroupWithCode(inviteCode))))

        case .handleGroupDeeplink(let deeplink):
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.handleDeeplink(deeplink))))

        case .openLiveActivityETASheet:
          guard let liveSchedule = state.liveSchedule else {
            // Cold start: Activity 구독보다 딥링크가 먼저 도착 → pending 처리
            state.pendingETASheetRequest = true
            return .none
          }
          state.liveScheduleDetail = LiveSchedule.Detail.State(data: liveSchedule.$data)
          // 딜레이 후 ETA 시트 열기 (fullScreenCover 애니메이션 완료 대기)
          return .run { send in
            // View에 presentation 요청
            NotificationCenter.default.post(name: .openLiveScheduleDetailFromDeeplink, object: nil)
            try? await Task.sleep(for: .milliseconds(400))
            await send(.internal(.openETASheetAfterDelay))
          }

        case .openLiveScheduleDetail:
          guard let liveSchedule = state.liveSchedule else {
            // Cold start: Activity 구독보다 딥링크가 먼저 도착 → pending 처리
            state.pendingLiveScheduleDetailRequest = true
            return .none
          }
          state.liveScheduleDetail = LiveSchedule.Detail.State(data: liveSchedule.$data)
          // View에 presentation 요청
          return .run { _ in
            NotificationCenter.default.post(name: .openLiveScheduleDetailFromDeeplink, object: nil)
          }

        case .openCreateScheduleIfPossible:
          // 그룹 탭으로 이동 후 그룹 유무에 따라 CreateSchedule 열기
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.openCreateScheduleIfPossible)))

        case .openPersonalEventDetail(let eventId):
          state.scheduleMode = .own
          state.selectedTab = .schedule(.own)
          return .send(.personalMode(.view(.openEventFromDeeplink(eventId: eventId))))

        case .openCreateGroup:
          // 그룹 탭으로 이동 후 그룹 생성 열기
          state.scheduleMode = .group
          state.selectedTab = .schedule(.group)
          return .send(.groupMain(.view(.createGroup)))

        case .openProPlan:
          state.selectedTab = .settings
          return .send(.settings(.view(.proPlanTapped)))

        case .openExtractSchedule:
          state.scheduleMode = .own
          state.selectedTab = .schedule(.own)
          return .send(.personalMode(.view(.openCreateEventWithExtraction)))

        case .internal(let internalAction):
          switch internalAction {
          case .refreshWidgetAuthToken:
            // Widget/LiveActivity Extension용 Auth 토큰 갱신 (Firebase ID Token - 1시간)
            return .run { [authClient] _ in
              await authClient.refreshWidgetAuthToken()
            }

          case .requestWidgetToken:
            // Widget 전용 Long-lived Token 발급 요청 (30일 유효)
            return .run { [authClient] _ in
              await authClient.requestWidgetToken()
            }

          case .observePushToStartToken:
            // Push to Start 토큰 스트림 구독
            let stream = liveActivityClient.observePushToStartTokenUpdates()
            return .run { send in
              for await token in stream {
                await send(.internal(.pushToStartTokenReceived(token)))
              }
            }

          case .pushToStartTokenReceived(let token):
            // Push to Start 토큰을 백엔드에 등록 (캐싱으로 중복 호출 방지)
            let cacheKey = CacheKeys.lastPushToStartToken
            let lastToken = userDefaultsClient.stringForKey(cacheKey)
            guard token != lastToken else { return .none }

            return .run { [userDefaultsClient] _ in
              do {
                try await notificationClient.saveLiveActivityPushToStartToken(token)
                userDefaultsClient.setString(token, cacheKey)
              } catch {
                AppLogger.liveActivity.error("Push to Start 토큰 등록 실패: \(error.localizedDescription)")
              }
            }

          case .observeVoteActivityUpdates:
            return .run { [voteLiveActivityClient] send in
              for await update in voteLiveActivityClient.observeActivityUpdates() {
                await send(.internal(.voteActivityUpdateReceived(update)))
              }
            }

          case .voteActivityUpdateReceived(let update):
            // 투표 LiveActivity가 시작되었을 때 처리
            if update.isActive, let attributes = update.attributes {
              // 투표 상세 화면으로 이동하거나 상태 업데이트
              AppLogger.liveActivity.debug("Vote Activity started: \(attributes.scheduleId)")
            }
            return .none

          case .observeActivityUpdates:
            let stream = liveActivityClient.observeActivityUpdates()
            return .run { send in
              for await update in stream {
                await send(.internal(.activityUpdateReceived(update)))
              }
            }

          case .activityUpdateReceived(let update):
            if update.isActive, let attributes = update.attributes {
              let data = LiveSchedule.Data(
                emoji: attributes.emoji,
                title: attributes.title,
                location: attributes.location,
                scheduledTime: attributes.scheduledTime,
                participants: update.contentState?.participants ?? [],
                currentUserId: attributes.currentUserId,
                trackingDurationMinutes: attributes.trackingDurationMinutes,
                hostId: attributes.hostId,
                hostName: attributes.hostName,
                groupName: attributes.groupName,
                groupImageUrl: attributes.groupImageUrl
              )
              state.liveSchedule = LiveSchedule.Feature.State(data: Shared(value: data))

              // pending ETA 시트 요청 처리 (Cold start 시 딥링크가 먼저 도착한 경우)
              var effects: [Effect<Action>] = [
                .send(.groupMain(.internal(.liveActivityChanged(scheduleId: attributes.scheduleId))))
              ]
              if state.pendingETASheetRequest {
                state.pendingETASheetRequest = false
                effects.append(.send(.openLiveActivityETASheet))
              } else if state.pendingLiveScheduleDetailRequest {
                state.pendingLiveScheduleDetailRequest = false
                effects.append(.send(.openLiveScheduleDetail))
              }

              // Activity 상태 변화 구독 시작 (dismissed/ended 감지용)
              if let activityId = liveActivityClient.activeActivityId() {
                effects.append(.send(.internal(.observeActivityState(activityId: activityId))))
              }

              return .merge(effects)
            } else if !update.isActive {
              if state.liveSchedule != nil {
                state.liveSchedule = nil
                return .send(.groupMain(.internal(.liveActivityChanged(scheduleId: nil))))
              }
            }
            return .none

          case .observeActivityState(let activityId):
            guard let stream = liveActivityClient.observeActivityStateUpdates(activityId) else {
              return .none
            }
            return .run { send in
              for await stateValue in stream {
                await send(.internal(.activityStateChanged(stateValue)))
              }
            }

          case .activityStateChanged(let stateValue):
            if stateValue == .dismissed || stateValue == .ended {
              state.liveSchedule = nil
              return .send(.groupMain(.internal(.liveActivityChanged(scheduleId: nil))))
            }
            return .none

          case .openETASheetAfterDelay:
            state.liveScheduleDetail?.isETASheetPresented = true
            return .none

          case .syncCalendar:
            guard !state.isCalendarSyncInFlight else { return .none }
            state.isCalendarSyncInFlight = true

            // 앱 시작 시 캘린더 동기화 (백그라운드)
            let enabledGroupIds = Set(
              state.currentUser.groups
                .filter { $0.notifications?.calendarSync ?? false }
                .map { $0.id }
            )
            let personalSyncEnabled = userDefaultsClient.boolForKey(AppConstants.UserDefaults.personalCalendarSync)
            return .run(priority: .utility) { [calendarSyncClient] send in
              let allSucceeded = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
                group.addTask {
                  do {
                    let result = try await calendarSyncClient.sync(enabledGroupIds)
                    AppLogger.calendar.info("📅 [RootTab] syncCalendar 완료 - \(result.description)")
                    return true
                  } catch {
                    AppLogger.calendar.error("📅 [RootTab] syncCalendar 실패 - \(error.localizedDescription)")
                    return false
                  }
                }

                group.addTask {
                  do {
                    let personalResult = try await calendarSyncClient.syncPersonalEvents(personalSyncEnabled)
                    AppLogger.calendar.info("📅 [RootTab] personalSync 완료 - \(personalResult.description)")
                    return true
                  } catch {
                    AppLogger.calendar.error("📅 [RootTab] personalSync 실패 - \(error.localizedDescription)")
                    return false
                  }
                }

                return await group.reduce(true) { $0 && $1 }
              }
              await send(.internal(.syncCalendarFinished(success: allSucceeded)))
            }

          case .syncCalendarFinished(let success):
            state.isCalendarSyncInFlight = false
            if success {
              state.hasInitialCalendarSyncBeenScheduled = true
            }
            return .none

          case .observeSubscriptionStatus:
            return .run { [subscriptionClient] send in
              if let status = try? await subscriptionClient.fetchStatus() {
                await send(.internal(.subscriptionStatusChanged(status)))
              }
              for await status in subscriptionClient.unifiedStatusStream() {
                await send(.internal(.subscriptionStatusChanged(status)))
              }
            }
            .cancellable(id: CancelID.subscriptionStatus, cancelInFlight: true)

          case .subscriptionStatusChanged(let status):
            return applySubscriptionStatus(status, state: &state)

          case .refreshSubscriptionStatus:
            return .run { [subscriptionClient] send in
              if let status = try? await subscriptionClient.fetchStatus() {
                // 서버 상태가 subscribed인데 만료일이 지났으면 로컬 StoreKit으로 검증
                // (AppStore.sync() 없이 — Apple ID 로그인 팝업 방지)
                if case .subscribed(_, let expirationDate) = status,
                   let expDate = expirationDate,
                   expDate < Date() {
                  do {
                    let localStatus = try await subscriptionClient.fetchLocalStatus()
                    if localStatus.isPro {
                      // 로컬 StoreKit에서 활성 구독 확인됨 → 로컬 상태 우선 반영
                      // (서버는 unifiedStatusStream으로 곧 동기화됨)
                      await send(.internal(.subscriptionStatusChanged(localStatus)))
                    } else {
                      // 로컬에도 활성 구독 없음 → expired 처리
                      await send(.internal(.subscriptionStatusChanged(.expired(expirationDate: expDate))))
                    }
                  } catch {
                    // 로컬 조회 실패 시 서버 상태 그대로 사용
                    AppLogger.subscription.error("[RootTab] Local status check failed: \(error)")
                    await send(.internal(.subscriptionStatusChanged(status)))
                  }
                } else {
                  await send(.internal(.subscriptionStatusChanged(status)))
                }
              }
            }

          }

        case .scenePhaseChanged(let phase):
          if phase == .active {
            return .send(.internal(.refreshSubscriptionStatus))
          }
          return .none

        case .delegate:
          return .none
        }
      }
      .ifLet(\.liveSchedule, action: \.liveSchedule) {
        LiveSchedule.Feature()
      }
      .ifLet(\.$liveScheduleDetail, action: \.liveScheduleDetail) {
        LiveSchedule.Detail()
      }
    }

    private func applySubscriptionStatus(
      _ status: SubscriptionStatus,
      state: inout State
    ) -> Effect<Action> {
      state.subscriptionStatus = status
      state.settings.subscriptionStatus = status
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro = false
      $isPro.withLock { $0 = status.isPro }
      analyticsClient.setSubscriptionTier(status)
      return .none
    }
  }
}

// MARK: - View

extension RootTab {
  public struct RootView: View {
    @Bindable var store: StoreOf<RootTab.Feature>
    @Namespace private var animation

    // MARK: - Presentation State
    // ⚠️ @State + TCA 병행 사용 이유:
    // matchedTransitionSource + navigationTransition(.zoom) 조합이 동작하려면
    // @State를 직접 토글해야 합니다. TCA의 Binding(get:set:)이나 onChange 동기화로는
    // SwiftUI transition 타이밍이 맞지 않아 zoom 애니메이션이 동작하지 않습니다.
    // 따라서 @State는 presentation 제어용, TCA는 상태/로직 관리용으로 분리합니다.
    @State private var expandLiveSchedule: Bool = false
    @State private var showManageSubscriptions: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Tab Animation State
    /// 탭 아이콘 애니메이션을 위한 UIImageView 캐시
    @State private var tabImageViews: [Tab: UIImageView] = [:]

    // MARK: - Constants

    private let liveScheduleTransitionID = "LIVE_PROMISE_TRANSITION"
    private let tabBarHeight = AppConstants.UI.tabBarHeight
    private let compactViewBottomSpacing = AppConstants.UI.compactViewBottomSpacing
    private let compactViewCornerRadius = AppConstants.UI.compactViewCornerRadius
    private let compactViewPadding = AppConstants.UI.compactViewPadding
    private let compactViewVerticalPadding = AppConstants.UI.compactViewVerticalPadding

    public init(store: StoreOf<RootTab.Feature>) {
      self.store = store
    }

    // MARK: - Computed Properties

    /// 현재 설정된 테마 모드를 ColorScheme으로 변환
    private var preferredColorScheme: ColorScheme? {
      switch AppConstants.ThemeMode(rawValue: store.themeMode) ?? .system {
      case .system: return nil
      case .light: return .light
      case .dark: return .dark
      }
    }

    public var body: some View {
      tabViewWithLiveSchedule
        .overlay(alignment: .top) {
          if case .gracePeriod(let expirationDate) = store.subscriptionStatus {
            gracePeriodOverlay(expirationDate: expirationDate)
          }
        }
        .tint(Color.pmbrand.primary)
        .preferredColorScheme(preferredColorScheme)
        .id("\(store.preferredLanguage)_\(store.use24HourFormat)")
        .onAppear { store.send(.onAppear) }
        .onChange(of: scenePhase) { _, newPhase in
          store.send(.scenePhaseChanged(newPhase))
        }
        .fullScreenCover(isPresented: $expandLiveSchedule, onDismiss: {
          // 스와이프로 dismiss 시 TCA 상태 정리
          store.send(.liveScheduleDetail(.dismiss))
        }) {
          if let detailStore = store.scope(state: \.liveScheduleDetail, action: \.liveScheduleDetail.presented) {
            LiveSchedule.ExpandedView(
              store: detailStore,
              animation: animation,
              transitionID: liveScheduleTransitionID
            )
          }
        }
        // 딥링크로 LiveScheduleDetail 열기 요청 수신
        // ⚠️ onChange/task(id:)로 TCA 상태를 관찰하면 zoom transition이 깨짐
        // NotificationCenter를 사용하여 TCA → View 단방향 이벤트 전달
        .onReceive(NotificationCenter.default.publisher(for: .openLiveScheduleDetailFromDeeplink)) { _ in
          if !expandLiveSchedule {
            expandLiveSchedule = true
          }
        }
    }

    // MARK: - Grace Period Banner

    private func gracePeriodOverlay(expirationDate: Date) -> some View {
      let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0

      return HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.subheadline)
          .foregroundStyle(Color.pmwarning.n500)

        if days > 0 {
          Text("결제 문제가 있어요 · \(days)일 후 Pro 비활성화")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.pmtext.primary)
        } else {
          Text("결제 문제가 있어요 · 곧 Pro가 비활성화됩니다")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.pmtext.primary)
        }

        Spacer()

        Button {
          showManageSubscriptions = true
        } label: {
          Text("확인")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmwarning.n500)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.pmwarning.n500.opacity(0.12))
      .manageSubscriptionsSheet(
        isPresented: $showManageSubscriptions,
        subscriptionGroupID: "21947112"
      )
    }

    // MARK: - TabView

    private var tabView: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        tabContentView(for: .home)
          .tabItem { Label(LocalizedStrings.TabBar.home, systemImage: "house.fill") }
          .tag(Tab.home)

        tabContentView(for: .schedule(store.scheduleMode))
          .tabItem {
            Label(
              Tab.schedule(store.scheduleMode).label,
              systemImage: Tab.schedule(store.scheduleMode).iconName
            )
          }
          .tag(Tab.schedule(store.scheduleMode))

        tabContentView(for: .calendar)
          .tabItem { Label(LocalizedStrings.TabBar.calendar, systemImage: store.calendar.displayMode.iconName) }
          .tag(Tab.calendar)

        tabContentView(for: .settings)
          .tabItem { Label(LocalizedStrings.TabBar.settings, systemImage: "gearshape.fill") }
          .tag(Tab.settings)
      }
      .tabViewStyle(.tabBarOnly)
      .background(ExtractTabImageViews { tabImageViews = $0 })
      .compositingGroup()
      .onChange(of: store.selectedTab) { oldValue, newValue in
        guard let imageView = tabImageViews[newValue] else { return }
        let symbolEffects = newValue.symbolEffects

        for effect in symbolEffects {
          imageView.addSymbolEffect(effect, options: .nonRepeating)
        }
      }
    }

    // MARK: - TabView with LiveSchedule

    @ViewBuilder
    private var tabViewWithLiveSchedule: some View {
      if #available(iOS 26.1, *) {
        tabViewWithBottomAccessoryNew
      } else if #available(iOS 26.0, *) {
        tabViewWithBottomAccessoryLegacy
      } else {
        tabViewWithOverlay
      }
    }

    @available(iOS 26.1, *)
    @ViewBuilder
    private var tabViewWithBottomAccessoryNew: some View {
      tabView
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: store.liveSchedule != nil) {
          if let liveScheduleStore = store.scope(state: \.liveSchedule, action: \.liveSchedule) {
            LiveSchedule.CompactView(store: liveScheduleStore)
              .matchedTransitionSource(id: liveScheduleTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.liveSchedule(.view(.tapped)))  // TCA 상태 생성
                expandLiveSchedule = true  // transition용 직접 토글
              }
          }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var tabViewWithBottomAccessoryLegacy: some View {
      if let liveScheduleStore = store.scope(state: \.liveSchedule, action: \.liveSchedule) {
        tabView
          .tabBarMinimizeBehavior(.onScrollDown)
          .tabViewBottomAccessory {
            LiveSchedule.CompactView(store: liveScheduleStore)
              .matchedTransitionSource(id: liveScheduleTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.liveSchedule(.view(.tapped)))
                expandLiveSchedule = true
              }
          }
      } else {
        tabView
      }
    }

    private var tabViewWithOverlay: some View {
      tabView
        .overlay(alignment: .bottom) {
          if let liveScheduleStore = store.scope(state: \.liveSchedule, action: \.liveSchedule) {
            LiveSchedule.CompactView(store: liveScheduleStore)
              .padding(.vertical, compactViewVerticalPadding)
              .background(.ultraThinMaterial, in: .rect(cornerRadius: compactViewCornerRadius))
              .matchedTransitionSource(id: liveScheduleTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.liveSchedule(.view(.tapped)))
                expandLiveSchedule = true
              }
              .offset(y: -(tabBarHeight + compactViewBottomSpacing))
              .padding(.horizontal, compactViewPadding)
          }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContentView(for tab: Tab) -> some View {
      switch tab {
      case .home:
        NavigationStack {
          Home.RootView(
            store: store.scope(
              state: \.home,
              action: \.home
            )
          )
        }

      case .calendar:
        CalendarFeature.RootView(
          store: store.scope(
            state: \.calendar,
            action: \.calendar
          )
        )

      case .schedule(let mode):
        NavigationStack {
          switch mode {
          case .group:
            GroupMain.RootView(
              store: store.scope(
                state: \.groupMain,
                action: \.groupMain
              )
            )
          case .own:
            PersonalMode.RootView(
              store: store.scope(
                state: \.personalMode,
                action: \.personalMode
              )
            )
          }
        }

      case .settings:
        Settings.RootView(
          store: store.scope(
            state: \.settings,
            action: \.settings
          )
        )
      }
    }
  }
}

// MARK: - Tab Image Extractor

/// UITabBarController에서 탭 아이콘 UIImageView를 추출하는 헬퍼
fileprivate struct ExtractTabImageViews: UIViewRepresentable {
  var result: ([Tab: UIImageView]) -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false

    DispatchQueue.main.async {
      if let compositingGroup = view.superview?.superview {
        guard let tabHostingController = compositingGroup.subviews.last else { return }
        guard let tabController = tabHostingController.subviews.first?.next as? UITabBarController else { return }

        extractImageViews(tabController.tabBar)
      }
    }

    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  private func extractImageViews(_ tabBar: UITabBar) {
    // 1단계: 모든 UIImageView 추출
    let allImageViews = tabBar.allSubviews(ofType: UIImageView.self)

    // 2단계: Symbol 이미지만 필터링
    let symbolImageViews = allImageViews.filter { imageView in
      imageView.image?.isSymbolImage ?? false
    }

    // 3단계: iOS 26 필터링 (tintColor 매칭)
    let imageViews: [UIImageView]
    if isiOS26 {
      imageViews = symbolImageViews.filter { imageView in
        imageView.tintColor == tabBar.tintColor
      }
    } else {
      imageViews = symbolImageViews
    }

    var dict: [Tab: UIImageView] = [:]

    // 탭 순서에 맞춰 이미지뷰 매핑 (schedule 탭은 인덱스 1)
    let tabs: [Tab] = [.home, .schedule(.group), .calendar, .settings]

    for (index, tab) in tabs.enumerated() {
      if index < imageViews.count {
        // iconName으로 매칭
        let matchedView = imageViews.first { imageView in
          imageView.description.contains(tab.iconName)
        }

        if let imageView = matchedView {
          dict[tab] = imageView
          // schedule 탭은 group과 own 모두 같은 이미지뷰 사용
          if case .schedule = tab {
            dict[.schedule(.own)] = imageView
          }
        } else if index < imageViews.count {
          // fallback: 순서로 매칭
          let imageView = imageViews[index]
          dict[tab] = imageView
          // schedule 탭은 group과 own 모두 같은 이미지뷰 사용
          if case .schedule = tab {
            dict[.schedule(.own)] = imageView
          }
        }
      }
    }

    result(dict)
  }

  private var isiOS26: Bool {
    if #available(iOS 26, *) {
      return true
    } else {
      return false
    }
  }
}
