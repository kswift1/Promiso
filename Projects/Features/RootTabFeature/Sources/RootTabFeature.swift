// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer

import ComposableArchitecture
import SwiftUI

import Clients
import PromisoShared
import CalendarFeature
import ProfileFeature
import ResourceKit
import SharedFeature

public enum Tab: String, CaseIterable {
  case home = "홈"
  case group = "그룹"
  case calendar = "캘린더"
  case profile = "프로필"

  var iconName: String {
    switch self {
    case .home: return "house.fill"
    case .group: return "person.3.fill"
    case .calendar: return "calendar"
    case .profile: return "person.fill"
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

    public init() {}

    @ObservableState
    public struct State {
      /// 현재 선택된 탭
      var selectedTab: Tab = .home

      /// Home Main State
      var home: Home.Feature.State

      /// Calendar State
      var calendar: CalendarFeature.Feature.State

      /// Group Main State
      var groupMain: GroupMain.Feature.State

      /// Profile State
      var profile: Profile.Feature.State

      /// 현재 사용자 정보 (Profile에 전달)
      var currentUser: UserPrivateModel

      /// LivePromise State (약속 추적 바) - nil이면 숨김
      var livePromise: LivePromise.Feature.State?

      /// LivePromise 상세 뷰 Presentation
      @Presents var livePromiseDetail: LivePromise.Detail.State?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
        self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
        self.home = Home.Feature.State(currentUser: currentUser)
        self.calendar = CalendarFeature.Feature.State(currentUser: currentUser)
        self.profile = Profile.Feature.State(currentUser: currentUser)
        
        // TODO: 테스트 완료 후 mock 데이터 제거
//        self.livePromise = LivePromise.Feature.State(
//          emoji: "🎂",
//          title: "일이삼사오육칠팔구십십일십이",
//          location: "강남역 11번 출구 강남역 11번 출구 강남역 11번 출구 강남역 11번 출구",
//          scheduledTime: Date().addingTimeInterval(3600),
//          participants: [
//            ParticipantState(id: currentUser.id, name: "나", estimatedArrivalMinutes: 5),
//            ParticipantState(id: "user2", name: "친구1", estimatedArrivalMinutes: 0),
//            ParticipantState(id: "user3", name: "친구2", estimatedArrivalMinutes: 10)
//          ],
//          currentUserId: currentUser.id
//        )
      }
    }

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
      /// Profile 액션
      case profile(Profile.Feature.Action)
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
      /// 내부 액션
      case `internal`(Internal)
    }

    public enum Internal: Equatable, Sendable {
      /// Push to Start 토큰 구독 시작
      case observePushToStartToken
      /// Push to Start 토큰 수신
      case pushToStartTokenReceived(String)
      /// Widget용 Auth 토큰 갱신
      case refreshWidgetAuthToken
      /// LiveActivity 변화 구독 시작
      case observeActivityUpdates
      /// LiveActivity 변화 감지됨
      case activityUpdateReceived(ActivityUpdate)
      /// 특정 Activity 상태 변화 구독 시작
      case observeActivityState(activityId: String)
      /// Activity 상태 변화 감지됨 (dismissed/ended)
      case activityStateChanged(ActivityStateValue)
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

      Scope(state: \.profile, action: \.profile) {
        Profile.Feature()
      }

      Reduce { state, action in
        switch action {
        case .onAppear:
          // Widget용 Auth 토큰 갱신 + Push to Start 토큰 구독 시작 + Activity 변화 구독
          AppLogger.liveActivity.debug("RootTab onAppear")
          return .merge(
            .send(.internal(.refreshWidgetAuthToken)),
            .send(.internal(.observePushToStartToken)),
            .send(.internal(.observeActivityUpdates))
          )

        case .tabSelected(let tab):
          state.selectedTab = tab
          return .run { _ in
            await hapticFeedback.buttonTap()
          }

        case .home(.delegate(.navigateToGroup(let groupId))):
          state.selectedTab = .group
          if let groupInfo = state.groupMain.allGroupSummaries?.first(where: { $0.id == groupId }) {
            return .send(.groupMain(.view(.groupChanged(groupInfo))))
          }
          return .none

        case .home:
          return .none

        case .calendar:
          return .none

        case .groupMain:
          return .none

        case .profile(.delegate(.didLogout)):
          return .send(.delegate(.logoutRequested))

        case .profile:
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

        case .internal(let internalAction):
          switch internalAction {
          case .refreshWidgetAuthToken:
            // Widget/LiveActivity Extension용 Auth 토큰 갱신
            return .run { [authClient] _ in
              await authClient.refreshWidgetAuthToken()
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

            guard token != lastToken else {
              AppLogger.liveActivity.debug("Push to Start 토큰 변경 없음 - 백엔드 호출 스킵")
              return .none
            }

            let userId = state.currentUser.id
            AppLogger.liveActivity.info("Push to Start 토큰 수신: \(token.prefix(20))... (userId: \(userId))")
            return .run { _ in
              do {
                try await notificationClient.saveLiveActivityPushToStartToken(token)
                UserDefaults.standard.set(token, forKey: cacheKey)
                AppLogger.liveActivity.debug("Push to Start 토큰 캐시 저장 완료")
              } catch {
                AppLogger.liveActivity.error("Push to Start 토큰 백엔드 등록 실패: \(error.localizedDescription)")
              }
            }

          case .observeActivityUpdates:
            // LiveActivity 시작/종료 스트림 구독
            let stream = liveActivityClient.observeActivityUpdates()
            AppLogger.liveActivity.debug("observeActivityUpdates 구독 시작")
            return .run { send in
              for await update in stream {
                await send(.internal(.activityUpdateReceived(update)))
              }
            }

          case .activityUpdateReceived(let update):
            // Push-to-Start로 시작된 Activity 등 실시간 변화 감지
            AppLogger.liveActivity.debug("activityUpdateReceived: \(update.activityState.rawValue)")
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
                hostName: attributes.hostName
              )
              state.livePromise = LivePromise.Feature.State(data: Shared(value: data))
              AppLogger.liveActivity.info("Activity 시작 - livePromise 생성")

              // Activity 상태 변화 구독 시작 (dismissed/ended 감지용)
              if let activityId = liveActivityClient.activeActivityId() {
                return .send(.internal(.observeActivityState(activityId: activityId)))
              }
            } else if !update.isActive {
              if state.livePromise != nil {
                state.livePromise = nil
                AppLogger.liveActivity.info("Activity 종료 - livePromise 제거")
              }
            }
            return .none

          case .observeActivityState(let activityId):
            // 특정 Activity의 상태 변화 스트림 구독
            guard let stream = liveActivityClient.observeActivityStateUpdates(activityId) else {
              AppLogger.liveActivity.warning("observeActivityState: Activity not found")
              return .none
            }

            return .run { send in
              for await stateValue in stream {
                await send(.internal(.activityStateChanged(stateValue)))
              }
            }

          case .activityStateChanged(let stateValue):
            // Activity 상태 변화 감지 (dismissed/ended)
            AppLogger.liveActivity.debug("activityStateChanged: \(stateValue.rawValue)")
            if stateValue == .dismissed || stateValue == .ended {
              if state.livePromise != nil {
                state.livePromise = nil
                AppLogger.liveActivity.info("Activity dismissed/ended - livePromise 제거")
              }
            }
            return .none
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

    public var body: some View {
      tabViewWithLivePromise
        .tint(Color.pmbrand.primary)
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

      case .profile:
        Profile.RootView(
          store: store.scope(
            state: \.profile,
            action: \.profile
          )
        )
      }
    }
  }
}
