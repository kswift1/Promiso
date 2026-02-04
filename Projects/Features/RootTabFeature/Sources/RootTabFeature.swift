// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer

import Combine
import ComposableArchitecture
import SwiftUI

import Clients
import PromisoShared
import CalendarFeature
import SettingsFeature
import ResourceKit
import SharedFeature

// MARK: - Notifications
// ⚠️ TCA 상태 관찰(onChange, task)로 @State를 동기화하면 zoom transition이 깨짐
// NotificationCenter를 사용하여 TCA Reducer → SwiftUI View로 이벤트 전달

extension Notification.Name {
  /// 딥링크로 LivePromiseDetail 열기 요청 (TCA Reducer → View)
  /// - 탭으로 열 때: @State 직접 토글 → zoom transition 동작
  /// - 딥링크로 열 때: Notification 수신 → @State 토글 → zoom transition 보존
  static let openLivePromiseDetailFromDeeplink = Notification.Name("openLivePromiseDetailFromDeeplink")
}

public enum Tab: String, CaseIterable {
  case home = "홈"
  case group = "그룹"
  case calendar = "캘린더"
  case settings = "설정"

  var iconName: String {
    switch self {
    case .home: return "house.fill"
    case .group: return "person.3.fill"
    case .calendar: return "calendar"
    case .settings: return "gearshape.fill"
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
    @Dependency(\.authClient) var authClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 탭
      var selectedTab: Tab = .home

      /// Home Main State
      var home: Home.Feature.State

      /// Calendar State
      var calendar: CalendarFeature.Feature.State

      /// Group Main State
      var groupMain: GroupMain.Feature.State

      /// Settings State
      var settings: Settings.Feature.State

      /// 현재 사용자 정보 (모든 탭에서 참조 공유)
      @Shared var currentUser: UserPrivateModel

      /// LivePromise State (약속 추적 바) - nil이면 숨김
      var livePromise: LivePromise.Feature.State?

      /// LivePromise 상세 뷰 Presentation
      @Presents var livePromiseDetail: LivePromise.Detail.State?

      /// Widget "직접 입력" 딥링크 pending 플래그
      /// Cold start 시 Activity 구독보다 딥링크가 먼저 도착하면 true로 설정,
      /// activityUpdateReceived에서 livePromise 생성 후 ETA 시트를 열기 위해 사용
      var pendingETASheetRequest: Bool = false

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
        self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
        self.home = Home.Feature.State(currentUser: currentUser)
        self.calendar = CalendarFeature.Feature.State(currentUser: currentUser)
        self.settings = Settings.Feature.State(currentUser: currentUser)
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
      /// LivePromise 액션
      case livePromise(LivePromise.Feature.Action)
      /// LivePromise 상세 뷰 액션
      case livePromiseDetail(PresentationAction<LivePromise.Detail.Action>)
      /// 상위로 전달되는 델리게이트 액션
      case delegate(Delegate)
      /// 딥링크로 그룹 참여 열기
      case openJoinGroupWithCode(String)
      /// 그룹 탭 딥링크 처리
      case handleGroupDeeplink(GroupMain.Deeplink)
      /// Widget "직접 입력" 버튼 → LivePromiseExpandedView + ETA 시트 열기
      case openLiveActivityETASheet
      /// LiveActivity 탭 → LivePromiseExpandedView 열기 (ETA 시트 없이)
      case openLivePromiseDetail
      /// Widget "약속 만들기" 버튼 → 그룹 탭 이동 + 약속 생성 (그룹 있을 때만)
      case openCreatePromiseIfPossible
      /// 내부 액션
      case `internal`(Internal)
    }

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
      /// 특정 Activity 상태 변화 구독 시작
      case observeActivityState(activityId: String)
      /// Activity 상태 변화 감지됨 (dismissed/ended)
      case activityStateChanged(ActivityStateValue)
      /// ETA 시트 열기 (딜레이 후)
      case openETASheetAfterDelay
      /// 캘린더 동기화 (백그라운드)
      case syncCalendar
    }

    public enum Delegate: Equatable {
      case logoutRequested
      case openJoinGroup(inviteCode: String)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: \.groupMain, action: \.groupMain) {
        GroupMain.Feature()
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
          return .merge(
            .send(.internal(.refreshWidgetAuthToken)),
            .send(.internal(.requestWidgetToken)),
            .send(.internal(.observePushToStartToken)),
            .send(.internal(.observeActivityUpdates)),
            .send(.internal(.syncCalendar))
          )

        case .tabSelected(let tab):
          let previousTab = state.selectedTab
          state.selectedTab = tab

          let hapticEffect: Effect<Action> = .run { _ in await hapticFeedback.buttonTap() }

          guard tab != previousTab else {
            return hapticEffect
          }

          var effects: [Effect<Action>] = [hapticEffect]

          // 탭 전환 시 각 Feature에 알림
          switch tab {
          case .home:
            effects.append(.send(.home(.view(.refreshNotificationBadge))))
          case .calendar:
            effects.append(.send(.calendar(.view(.refresh))))
          case .group, .settings:
            break
          }

          return .merge(effects)

        case .home(.delegate(.navigateToGroupWithPromise(let groupId, let promiseId))):
          state.selectedTab = .group
          // 그룹 선택 후 응답 필요 필터로 해당 약속 하이라이트
          return .send(.groupMain(.view(.handleDeeplink(
            .promiseInList(promiseId: promiseId, groupId: groupId, filter: .needResponse)
          ))))

        case .home(.delegate(.navigateToPromise(let promiseId, let groupId))):
          state.selectedTab = .group
          if let groupInfo = state.groupMain.allGroupSummaries?.first(where: { $0.id == groupId }) {
            return .send(.groupMain(.view(.groupChanged(groupInfo))))
          }
          return .none

        case .home(.delegate(.navigateToAllPromises)):
          // TODO: 모든 약속 보기 화면으로 이동 (추후 구현)
          return .none

        case .home:
          return .none

        case .calendar:
          return .none

        case .groupMain:
          return .none

        case .settings(.delegate(.didLogout)):
          return .send(.delegate(.logoutRequested))

        case .settings:
          return .none

        case .livePromise(.delegate(.showDetail)):
          // CompactView 탭 → 상세 뷰 표시 (같은 @Shared 전달)
          guard let livePromise = state.livePromise else { return .none }
          state.livePromiseDetail = LivePromise.Detail.State(data: livePromise.$data)
          return .none

        case .livePromise:
          return .none

        case .livePromiseDetail(.presented(.delegate(.updateETA(let minutes)))):
          // ExpandedView 시트에서 ETA 변경 → 서버 API 호출 → APNs Broadcast
          guard let attributes = liveActivityClient.currentAttributes(),
                let currentState = liveActivityClient.currentState() else {
            AppLogger.liveActivity.error("ETA 업데이트 실패: 활성 LiveActivity 없음")
            return .none
          }

          let channelId = attributes.channelId
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
          return .run { [promiseClient] _ in
            do {
              try await promiseClient.updateETA(channelId, updatedParticipants, trackingDurationMinutes)
              AppLogger.liveActivity.info("ETA 업데이트 성공: \(minutes)분")
            } catch {
              AppLogger.liveActivity.error("ETA 업데이트 실패: \(error.localizedDescription)")
            }
          }

        case .livePromiseDetail:
          return .none

        case .openJoinGroupWithCode(let inviteCode):
          state.selectedTab = .group
          return .send(.groupMain(.view(.joinGroupWithCode(inviteCode))))

        case .handleGroupDeeplink(let deeplink):
          state.selectedTab = .group
          return .send(.groupMain(.view(.handleDeeplink(deeplink))))

        case .openLiveActivityETASheet:
          guard let livePromise = state.livePromise else {
            // Cold start: Activity 구독보다 딥링크가 먼저 도착 → pending 처리
            state.pendingETASheetRequest = true
            return .none
          }
          state.livePromiseDetail = LivePromise.Detail.State(data: livePromise.$data)
          // 딜레이 후 ETA 시트 열기 (fullScreenCover 애니메이션 완료 대기)
          return .run { send in
            // View에 presentation 요청
            NotificationCenter.default.post(name: .openLivePromiseDetailFromDeeplink, object: nil)
            try? await Task.sleep(for: .milliseconds(400))
            await send(.internal(.openETASheetAfterDelay))
          }

        case .openLivePromiseDetail:
          guard let livePromise = state.livePromise else {
            // Cold start: Activity 구독보다 딥링크가 먼저 도착 → pending 처리
            // ETA 시트 없이 열리므로 pendingETASheetRequest는 false 유지
            return .none
          }
          state.livePromiseDetail = LivePromise.Detail.State(data: livePromise.$data)
          // View에 presentation 요청
          return .run { _ in
            NotificationCenter.default.post(name: .openLivePromiseDetailFromDeeplink, object: nil)
          }

        case .openCreatePromiseIfPossible:
          // 그룹 탭으로 이동 후 그룹 유무에 따라 CreatePromise 열기
          state.selectedTab = .group
          return .send(.groupMain(.view(.openCreatePromiseIfPossible)))

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
            let lastToken = UserDefaults.standard.string(forKey: cacheKey)
            guard token != lastToken else { return .none }

            return .run { _ in
              do {
                try await notificationClient.saveLiveActivityPushToStartToken(token)
                UserDefaults.standard.set(token, forKey: cacheKey)
              } catch {
                AppLogger.liveActivity.error("Push to Start 토큰 등록 실패: \(error.localizedDescription)")
              }
            }

          case .observeActivityUpdates:
            let stream = liveActivityClient.observeActivityUpdates()
            return .run { send in
              for await update in stream {
                await send(.internal(.activityUpdateReceived(update)))
              }
            }

          case .activityUpdateReceived(let update):
            if update.isActive, let attributes = update.attributes {
              let data = LivePromise.Data(
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
              state.livePromise = LivePromise.Feature.State(data: Shared(value: data))

              // pending ETA 시트 요청 처리 (Cold start 시 딥링크가 먼저 도착한 경우)
              var effects: [Effect<Action>] = [
                .send(.groupMain(.internal(.liveActivityChanged(promiseId: attributes.promiseId))))
              ]
              if state.pendingETASheetRequest {
                state.pendingETASheetRequest = false
                effects.append(.send(.openLiveActivityETASheet))
              }

              // Activity 상태 변화 구독 시작 (dismissed/ended 감지용)
              if let activityId = liveActivityClient.activeActivityId() {
                effects.append(.send(.internal(.observeActivityState(activityId: activityId))))
              }

              return .merge(effects)
            } else if !update.isActive {
              if state.livePromise != nil {
                state.livePromise = nil
                return .send(.groupMain(.internal(.liveActivityChanged(promiseId: nil))))
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
              state.livePromise = nil
              return .send(.groupMain(.internal(.liveActivityChanged(promiseId: nil))))
            }
            return .none

          case .openETASheetAfterDelay:
            state.livePromiseDetail?.isETASheetPresented = true
            return .none

          case .syncCalendar:
            // 앱 시작 시 캘린더 동기화 (백그라운드)
            let enabledGroupIds = Set(
              state.currentUser.groups
                .filter { $0.notifications?.calendarSync ?? false }
                .map { $0.id }
            )
            return .run(priority: .background) { [calendarSyncClient] _ in
              AppLogger.calendar.debug("📅 [RootTab] syncCalendar 시작 - enabledGroupIds: \(enabledGroupIds)")
              do {
                let result = try await calendarSyncClient.sync(enabledGroupIds)
                AppLogger.calendar.info("📅 [RootTab] syncCalendar 완료 - \(result.description)")
              } catch {
                AppLogger.calendar.error("📅 [RootTab] syncCalendar 실패 - \(error.localizedDescription)")
              }
            }
          }

        case .delegate:
          return .none
        }
      }
      .ifLet(\.livePromise, action: \.livePromise) {
        LivePromise.Feature()
      }
      .ifLet(\.$livePromiseDetail, action: \.livePromiseDetail) {
        LivePromise.Detail()
      }
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
    @State private var expandLivePromise: Bool = false

    // MARK: - Constants

    private let livePromiseTransitionID = "LIVE_PROMISE_TRANSITION"
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
      let themeMode = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.preferredThemeMode) ?? AppConstants.ThemeMode.system.rawValue
      switch AppConstants.ThemeMode(rawValue: themeMode) ?? .system {
      case .system: return nil
      case .light: return .light
      case .dark: return .dark
      }
    }

    public var body: some View {
      tabViewWithLivePromise
        .tint(Color.pmbrand.primary)
        .preferredColorScheme(preferredColorScheme)
        .onAppear { store.send(.onAppear) }
        .fullScreenCover(isPresented: $expandLivePromise, onDismiss: {
          // 스와이프로 dismiss 시 TCA 상태 정리
          store.send(.livePromiseDetail(.dismiss))
        }) {
          if let detailStore = store.scope(state: \.livePromiseDetail, action: \.livePromiseDetail.presented) {
            LivePromise.ExpandedView(
              store: detailStore,
              animation: animation,
              transitionID: livePromiseTransitionID
            )
          }
        }
        // 딥링크로 LivePromiseDetail 열기 요청 수신
        // ⚠️ onChange/task(id:)로 TCA 상태를 관찰하면 zoom transition이 깨짐
        // NotificationCenter를 사용하여 TCA → View 단방향 이벤트 전달
        .onReceive(NotificationCenter.default.publisher(for: .openLivePromiseDetailFromDeeplink)) { _ in
          if !expandLivePromise {
            expandLivePromise = true
          }
        }
    }

    // MARK: - TabView

    private var tabView: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        ForEach(Tab.allCases, id: \.self) { tab in
          tabContentView(for: tab)
            .tabItem { Label(tab.rawValue, systemImage: tab.iconName) }
            .tag(tab)
        }
      }
    }

    // MARK: - TabView with LivePromise

    @ViewBuilder
    private var tabViewWithLivePromise: some View {
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
        .tabViewBottomAccessory(isEnabled: store.livePromise != nil) {
          if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
            LivePromise.CompactView(store: livePromiseStore)
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))  // TCA 상태 생성
                expandLivePromise = true  // transition용 직접 토글
              }
          }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var tabViewWithBottomAccessoryLegacy: some View {
      if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
        tabView
          .tabBarMinimizeBehavior(.onScrollDown)
          .tabViewBottomAccessory {
            LivePromise.CompactView(store: livePromiseStore)
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))
                expandLivePromise = true
              }
          }
      } else {
        tabView
      }
    }

    private var tabViewWithOverlay: some View {
      tabView
        .overlay(alignment: .bottom) {
          if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
            LivePromise.CompactView(store: livePromiseStore)
              .padding(.vertical, compactViewVerticalPadding)
              .background(.ultraThinMaterial, in: .rect(cornerRadius: compactViewCornerRadius))
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))
                expandLivePromise = true
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

      case .group:
        NavigationStack {
          GroupMain.RootView(
            store: store.scope(
              state: \.groupMain,
              action: \.groupMain
            )
          )
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
