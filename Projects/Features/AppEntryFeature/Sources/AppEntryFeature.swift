// MARK: - AppEntryFeature.swift
import AuthFeature
import Clients
import ExternalDependency
import FirebaseMessaging
import PromisoShared
import RootTabFeature
import ResourceKit
import SharedFeature
import SwiftUI

// MARK: - Feature Namespace

public enum AppEntry {}
extension AppEntry.Feature.Destination.State: Equatable {}

// MARK: - Feature Implementation

extension AppEntry {
  
  // MARK: - Reducer
  
  @Reducer
  public struct Feature {
    @Dependency(\.authClient) var authClient
    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.deeplinkClient) var deeplinkClient
    @Dependency(\.appConfigClient) var appConfigClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.clarityClient) var clarityClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.personalEventClient) var personalEventClient

    public init() {}
    
    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public enum SplashState: Equatable {
        case visible
        case animatingOut
        case hidden
      }

      var splash: SplashState = .visible

      @Presents public var destination: Destination.State?

      /// 알림 권한 온보딩 (프로필 설정 완료 후 표시)
      @Presents var notificationPermission: NotificationPermission.Feature.State?

      /// 프로필 설정 완료 후 메인으로 이동할 사용자 정보
      var pendingUserForMain: UserPrivateModel?

      /// 앱이 준비되기 전 수신된 딥링크 (메인 화면 전환 후 처리)
      var pendingDeeplink: DeeplinkDestination?

      /// Provider에서 제공한 프로필 이미지 URL (Google 로그인 시)
      var providerProfileImageURL: URL?

      /// 온보딩 인트로를 거친 신규 유저인지 (Screen 10 표시 여부 결정)
      var isFullOnboarding: Bool = false

      /// 업데이트 알림 타입
      @Presents var updateAlert: UpdateAlertState?

      public init() {
        self.destination = .auth(AuthFeature.Auth.Feature.State())
      }
    }

    /// 업데이트 알림 상태
    public enum UpdateAlertState: Equatable {
      case forceUpdate(currentVersion: String, requiredVersion: String)
      case recommendUpdate(currentVersion: String, recommendedVersion: String)
    }
    

    // MARK: - Action

    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case destination(PresentationAction<Destination.Action>)
      case notificationPermission(PresentationAction<NotificationPermission.Feature.Action>)
      case updateAlert(UpdateAlertAction)
    }

    public enum UpdateAlertAction: Equatable {
      case updateTapped
      case laterTapped
    }
    
    public enum ViewAction {
      case onAppear
      case splashAnimationCompleted
      case handleDeeplink(URL)
      case scenePhaseChanged(ScenePhase)
    }

    private enum SubscriptionCancelID {
      case fcmToken
      case pushNotificationTap
    }
    
    @CasePathable
    public enum InternalAction {
      case checkVersion
      case versionCheckCompleted(VersionCheckResult)
      case recheckVersionAfterAppStore
      case continueAppFlow
      case startSessionCheck
      case sessionCheckResponse(isAuthenticated: Bool)
      case startProfileCheck
      case profileCheckResponse(user: FirebaseUserSnapshot, profile: UserPrivateModel?)
      case checkNotificationPermission(UserPrivateModel)
      case notificationPermissionChecked(isAuthorized: Bool, user: UserPrivateModel)
      case subscribeFCMToken
      case fcmTokenReceived(String)
      case fcmTokenSaved
      case subscribePushNotificationTap
      case pushNotificationTapped(DeeplinkDestination)
      case cancelSubscriptions
      case transitionToMain(UserPrivateModel, isSignup: Bool)
      case requestFCMToken
      case fcmTokenFetched(String)
      case personalEventsCheckCompleted(hasEvents: Bool)
    }

    // MARK: - Destination Reducer

    @Reducer
    public enum Destination {
      case onboardingIntro(AppEntry.OnboardingIntro)
      case auth(AuthFeature.Auth.Feature)
      case profile(ProfileSetup)
      case calendarImport(AppEntry.CalendarImport)
      case main(RootTab.Feature)
    }

    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .send(.internal(.checkVersion))

          case .splashAnimationCompleted:
            state.splash = .hidden
            return .none

          case .handleDeeplink(let url):
            guard let destination = deeplinkClient.parseURL(url) else { return .none }
            return routeOrPendDeeplink(destination, state: &state)

          case .scenePhaseChanged(let phase):
            // 앱스토어에서 돌아왔을 때 버전 재체크
            if phase == .active && state.updateAlert != nil {
              return .send(.internal(.recheckVersionAfterAppStore))
            }
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {

          case .checkVersion:
            return .run { [appConfigClient] send in
              let result = await appConfigClient.checkVersion()
              await send(.internal(.versionCheckCompleted(result)))
            }

          case .versionCheckCompleted(let result):
            switch result {
            case .upToDate:
              // 업데이트 알림이 있었다면 닫기 (앱스토어에서 업데이트 후 복귀)
              if state.updateAlert != nil {
                state.updateAlert = nil
              }
              return .send(.internal(.continueAppFlow))

            case .forceUpdate(let current, let required):
              state.updateAlert = .forceUpdate(currentVersion: current, requiredVersion: required)
              return .none

            case .recommendUpdate(let current, let recommended):
              state.updateAlert = .recommendUpdate(currentVersion: current, recommendedVersion: recommended)
              return .none
            }

          case .recheckVersionAfterAppStore:
            // 앱스토어에서 복귀 시 버전 재체크 (캐시 초기화 후 새로 조회)
            return .run { [appConfigClient] send in
              let result = await appConfigClient.checkVersionForced()
              await send(.internal(.versionCheckCompleted(result)))
            }

          case .continueAppFlow:
            return .merge(
              .send(.internal(.startSessionCheck)),
              .send(.internal(.subscribeFCMToken)),
              .send(.internal(.subscribePushNotificationTap))
            )

          case .startSessionCheck:
            return .run { send in
              let isAuthenticated = await authClient.isAuthenticated()
              await send(.internal(.sessionCheckResponse(isAuthenticated: isAuthenticated)))
            }
            
          case .sessionCheckResponse(let isAuthenticated):
            if isAuthenticated {
              return .send(.internal(.startProfileCheck))
            } else {
              state.isFullOnboarding = true
              state.destination = .onboardingIntro(OnboardingIntro.State())
              if state.splash == .visible {
                state.splash = .animatingOut
              }
              return .none
            }
            
          case .startProfileCheck:
            return .run { send in
              guard let user = await authClient.currentUser() else { return }
              let privateProfile = try? await userProfileClient.getPrivateProfile(target: .me)
              await send(.internal(.profileCheckResponse(user: user, profile: privateProfile)))
            }
            
          case .profileCheckResponse(let user, let profile):
            if let userModel = profile {
              // 기존 사용자 → 바로 메인으로
              if state.splash == .visible {
                state.splash = .animatingOut
              }
              return .send(.internal(.transitionToMain(userModel, isSignup: false)))
            } else {
              // 신규 사용자 → 프로필 설정으로
              var profileState = ProfileSetup.State()
              profileState.inject(user: user, providerProfileImageURL: state.providerProfileImageURL)
              state.destination = .profile(profileState)
              if state.splash == .visible {
                state.splash = .animatingOut
              }
            }
            return .none

          case .checkNotificationPermission(let userModel):
            return .run { [analyticsClient] send in
              let status = await notificationClient.getAuthorizationStatus()
              analyticsClient.setNotificationPermissionStatus(status)
              let isAuthorized = status == .authorized
              await send(.internal(.notificationPermissionChecked(isAuthorized: isAuthorized, user: userModel)))
            }

          case .notificationPermissionChecked(let isAuthorized, let userModel):
            if isAuthorized {
              // 이미 권한 허용됨 → 바로 메인으로
              return .send(.internal(.transitionToMain(userModel, isSignup: true)))
            } else {
              // 권한 미허용 → 알림 권한 온보딩 표시
              state.pendingUserForMain = userModel
              state.notificationPermission = NotificationPermission.Feature.State()
            }
            return .none

          case .subscribeFCMToken:
            return .publisher {
              NotificationCenter.default
                .publisher(for: AppConstants.Notifications.fcmTokenDidReceive)
                .compactMap { notification -> String? in
                  notification.userInfo?["token"] as? String
                }
                .map { Action.internal(.fcmTokenReceived($0)) }
            }
            .cancellable(id: SubscriptionCancelID.fcmToken, cancelInFlight: true)

          case .fcmTokenReceived(let token):
            return .run { [notificationClient] send in
              // 로그인된 사용자만 토큰 저장
              let isAuthenticated = await authClient.isAuthenticated()
              guard isAuthenticated else {
                return
              }

              do {
                try await notificationClient.saveFCMToken(token)
                await send(.internal(.fcmTokenSaved))
              } catch {
                AppLogger.notification.error("FCM 토큰 저장 실패: \(error.localizedDescription)")
              }
            }

          case .fcmTokenSaved:
            AppLogger.notification.debug("FCM Token saved to Firestore")
            return .none

          case .subscribePushNotificationTap:
            return .run { send in
              for await destination in deeplinkClient.pushNotificationTapStream() {
                await send(.internal(.pushNotificationTapped(destination)))
              }
            }
            .cancellable(id: SubscriptionCancelID.pushNotificationTap, cancelInFlight: true)

          case .pushNotificationTapped(let destination):
            return routeOrPendDeeplink(destination, state: &state)

          case .cancelSubscriptions:
            return .merge(
              .cancel(id: SubscriptionCancelID.fcmToken),
              .cancel(id: SubscriptionCancelID.pushNotificationTap)
            )

          case .transitionToMain(let userModel, let isSignup):
            WidgetDataManager.saveUserId(userModel.id)
            clarityClient.setUser(userModel.id, userModel.nickname)
            let providerIdentifier = userModel.provider.providerTypeIdentifier
            let personalCalendarSyncEnabled = UserDefaults.standard.bool(
              forKey: AppConstants.UserDefaults.personalCalendarSync
            )
            analyticsClient.setUserID(userModel.id)
            analyticsClient.setUserProperty(userModel.nickname, .nickname)
            analyticsClient.setUserProperty(providerIdentifier, .authProvider)
            analyticsClient.setGroupMembershipProperties(userModel.groups)
            analyticsClient.setCalendarSyncEnabled(
              personalEnabled: personalCalendarSyncEnabled,
              groups: userModel.groups
            )
            analyticsClient.log(
              isSignup
                ? .userSignup(loginMethod: providerIdentifier)
                : .userLogin(loginMethod: providerIdentifier)
            )

            state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))

            // 그룹 멤버 캐시 초기화 (백그라운드)
            let groupIds = userModel.groups.map(\.id)
            let cacheEffect: Effect<Action> = .run { [groupClient] _ in
              @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
              var groupMembersCache: [String: [UserPublicModel]] = [:]
              await withTaskGroup(of: (String, [UserPublicModel]?).self) { group in
                for groupId in groupIds {
                  group.addTask {
                    (groupId, try? await groupClient.fetchGroupMembers(groupId))
                  }
                }
                for await (groupId, members) in group {
                  if let members {
                    $groupMembersCache.withLock { $0[groupId] = members }
                  }
                }
              }
            }

            var effects: [Effect<Action>] = [cacheEffect, .send(.internal(.requestFCMToken))]

            // 캘린더 임포트 결과 → Home으로 전달 (결과는 CalendarImport 화면에서 표시됨)
            if isSignup {
              effects.append(.send(.destination(.presented(
                .main(.showCalendarImportResult)
              ))))
            }

            if let deeplink = state.pendingDeeplink {
              state.pendingDeeplink = nil
              effects.append(routeDeeplink(deeplink))
            }

            return .merge(effects)

          case .requestFCMToken:
            return .run { send in
              do {
                let token = try await Messaging.messaging().token()
                await send(.internal(.fcmTokenFetched(token)))
              } catch {
                // 토큰 요청 실패는 조용히 무시 (앱 동작에 치명적이지 않음)
              }
            }

          case .fcmTokenFetched(let token):
            return .send(.internal(.fcmTokenReceived(token)))

          case .personalEventsCheckCompleted(let hasEvents):
            guard let userModel = state.pendingUserForMain else { return .none }
            if hasEvents {
              state.pendingUserForMain = nil
              return .send(.internal(.transitionToMain(userModel, isSignup: true)))
            } else {
              state.destination = .calendarImport(
                AppEntry.CalendarImport.State(nickname: userModel.nickname)
              )
            }
            return .none
          }

        case .destination(.presented(.onboardingIntro(.delegate(.introCompleted)))):
          // 온보딩 완료 플래그 저장
          userDefaultsClient.setBool(true, AppConstants.UserDefaults.hasCompletedOnboarding)
          state.isFullOnboarding = true
          state.destination = .auth(Auth.Feature.State())
          return .none

        case .destination(.presented(.calendarImport(.delegate(.completed)))):
          if let userModel = state.pendingUserForMain {
            state.pendingUserForMain = nil
            return .send(.internal(.transitionToMain(userModel, isSignup: true)))
          }
          return .none

        case .destination(.presented(.auth(.delegate(.loggedIn(let providerProfileImageURL))))):
          state.providerProfileImageURL = providerProfileImageURL
          return .send(.internal(.startProfileCheck))

        case .destination(.presented(.profile(.delegate(.completed(let userModel))))):
          analyticsClient.log(.profileSetupCompleted)
          if state.isFullOnboarding {
            state.pendingUserForMain = userModel
            // 서버에서 기존 PersonalEvent 존재 확인 (중복 임포트 방지)
            return .run { [personalEventClient] send in
              let existingEvents = try? await personalEventClient.getActiveEvents(1)
              let hasEvents = !(existingEvents?.isEmpty ?? true)
              await send(.internal(.personalEventsCheckCompleted(hasEvents: hasEvents)))
            }
          } else {
            // 재로그인 후 프로필 설정 (엣지 케이스) → 알림 권한 확인
            return .send(.internal(.checkNotificationPermission(userModel)))
          }

        case .notificationPermission(.presented(.delegate(.dismissed))),
             .notificationPermission(.presented(.delegate(.permissionChanged))):
          state.notificationPermission = nil
          if let userModel = state.pendingUserForMain {
            // 프로필 설정 후 알림 권한 → 메인 전환
            state.pendingUserForMain = nil
            return .send(.internal(.transitionToMain(userModel, isSignup: true)))
          } else {
            // 비-온보딩 경로에서 알림 권한 → 로그인 화면
            state.destination = .auth(Auth.Feature.State())
          }
          return .none

        case .notificationPermission:
          return .none

        case .destination(.presented(.main(.delegate(.logoutRequested)))):
          state.destination = .auth(Auth.Feature.State())
          return .run { [notificationClient, authClient, clarityClient, analyticsClient] _ in
            LiveActivityImageStore.clearCache()
            WidgetDataManager.clearAll()
            authClient.clearWidgetAuthToken()
            WidgetDataManager.reloadWidgets()

            // Clarity 유저 정보 제거
            clarityClient.clearUser()

            // Analytics 유저 정보 제거
            analyticsClient.setUserID(nil)
            analyticsClient.setUserProperty(nil, .nickname)
            analyticsClient.setUserProperty(nil, .authProvider)
            analyticsClient.setUserProperty(nil, .subscriptionTier)
            analyticsClient.setUserProperty(nil, .notificationPermissionStatus)
            analyticsClient.setUserProperty(nil, .hasGroup)
            analyticsClient.setUserProperty(nil, .groupCountBucket)
            analyticsClient.setUserProperty(nil, .calendarSyncEnabled)

            do {
              try await notificationClient.deleteFCMToken()
            } catch {
              AppLogger.notification.error("FCM 토큰 삭제 실패: \(error.localizedDescription)")
            }

            do {
              try await authClient.logout()
            } catch {
              AppLogger.auth.error("로그아웃 실패: \(error.localizedDescription)")
            }
          }

        case .destination:
          return .none

        case .updateAlert(let alertAction):
          switch alertAction {
          case .updateTapped:
            // App Store로 이동
            return .run { [openURL] _ in
              await openURL(AppConstants.App.appStoreURL)
            }

          case .laterTapped:
            // 선택 업데이트만 닫기 가능 (강제 업데이트는 닫기 불가)
            if case .recommendUpdate = state.updateAlert {
              state.updateAlert = nil
              return .send(.internal(.continueAppFlow))
            }
            return .none
          }
        }
      }
      .ifLet(\.$destination, action: \.destination)
      .ifLet(\.$notificationPermission, action: \.notificationPermission) {
        NotificationPermission.Feature()
      }
    }
  }
  
  // MARK: - Root View
  
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Alert Strings

    private enum AlertStrings {
      static let forceUpdateTitle = LocalizedStrings.AppEntry.forceUpdateTitle
      static let recommendUpdateTitle = LocalizedStrings.AppEntry.recommendUpdateTitle

      static func forceUpdateMessage(current: String, required: String) -> String {
        LocalizedStrings.AppEntry.forceUpdateMessage(current, required)
      }

      static func recommendUpdateMessage(current: String, recommended: String) -> String {
        LocalizedStrings.AppEntry.recommendUpdateMessage(current, recommended)
      }
    }

    public var body: some View {
      ZStack {
        contentView
        splashView
      }
      .animation(.easeInOut, value: store.destinationType)
      .animation(.easeInOut, value: store.splash)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        store.send(.view(.scenePhaseChanged(newPhase)))
      }
      .fullScreenCover(
        item: $store.scope(
          state: \.notificationPermission,
          action: \.notificationPermission
        )
      ) { store in
        NotificationPermission.View(store: store)
      }
      .alert(
        updateAlertTitle,
        isPresented: .init(
          get: { store.updateAlert != nil },
          set: { _ in }
        ),
        presenting: store.updateAlert
      ) { alertState in
        Button(LocalizedStrings.AppEntry.updateAction) {
          store.send(.updateAlert(.updateTapped))
        }
        if case .recommendUpdate = alertState {
          Button(LocalizedStrings.AppEntry.updateLater, role: .cancel) {
            store.send(.updateAlert(.laterTapped))
          }
        }
      } message: { alertState in
        Text(updateAlertMessage(for: alertState))
      }
    }

    private var updateAlertTitle: String {
      switch store.updateAlert {
      case .forceUpdate:
        return AlertStrings.forceUpdateTitle
      case .recommendUpdate:
        return AlertStrings.recommendUpdateTitle
      case .none:
        return ""
      }
    }

    private func updateAlertMessage(for state: Feature.UpdateAlertState) -> String {
      switch state {
      case .forceUpdate(let current, let required):
        return AlertStrings.forceUpdateMessage(current: current, required: required)
      case .recommendUpdate(let current, let recommended):
        return AlertStrings.recommendUpdateMessage(current: current, recommended: recommended)
      }
    }

    @ViewBuilder
    private var contentView: some View {
      switch store.destination {
      case .onboardingIntro:
        if let store = store.scope(state: \.destination?.onboardingIntro, action: \.destination.onboardingIntro) {
          AppEntry.OnboardingIntro.View(store: store)
        }

      case .auth:
        if let store = store.scope(state: \.destination?.auth, action: \.destination.auth) {
          Auth.RootView(store: store)
        }

      case .profile:
        if let store = store.scope(state: \.destination?.profile, action: \.destination.profile) {
          NavigationStack {
            AppEntry.ProfileSetup.View(store: store)
          }
        }

      case .calendarImport:
        if let store = store.scope(state: \.destination?.calendarImport, action: \.destination.calendarImport) {
          AppEntry.CalendarImport.View(store: store)
        }

      case .main:
        if let store = store.scope(state: \.destination?.main, action: \.destination.main) {
          RootTab.RootView(store: store)
        }

      case .none:
        EmptyView()
      }
    }

    @ViewBuilder
    private var splashView: some View {
      if store.splash != .hidden {
        SplashView(
          config: .init(forceHideLogo: false),
          logo: { ResourceKitAsset.fingerSchedule.swiftUIImage },
          animateOut: store.splash == .animatingOut,
          isCompleted: {
            store.send(.view(.splashAnimationCompleted))
          }
        )
        .transition(.opacity)
      }
    }
  }
}

// MARK: - State Extensions

extension AppEntry.Feature.State {
  enum DestinationType: Equatable {
    case onboardingIntro, auth, profile, calendarImport, main
  }

  var destinationType: DestinationType? {
    switch destination {
    case .onboardingIntro: return .onboardingIntro
    case .auth: return .auth
    case .profile: return .profile
    case .calendarImport: return .calendarImport
    case .main: return .main
    case nil: return nil
    }
  }
}

// MARK: - ProfileSetup State Extension

extension AppEntry.ProfileSetup.State {
  mutating func inject(user: FirebaseUserSnapshot, providerProfileImageURL: URL? = nil) {
    // Firebase User의 photoURL 우선, 없으면 Provider의 profileImageURL 사용
    if let profileImageURL = user.photoURL ?? providerProfileImageURL {
      self.profileImage = .url(profileImageURL)
    } else {
      self.profileImage = .none
    }
    self.email = user.email
    self.uid = user.uid
    self.fullName = user.displayName ?? ""
    self.nickname = user.displayName ?? ""
    self.providerId = user.providerId
    self.providerUid = user.providerUid
    self.providerType = user.providerId?.providerTypeIdentifier
  }
}

// MARK: - Deeplink Routing

extension AppEntry.Feature {
  /// DeeplinkDestination을 RootTab으로 라우팅하는 Effect 생성
  private func routeDeeplink(_ destination: DeeplinkDestination) -> Effect<Action> {
    switch destination {
    case .schedule(let scheduleId, let groupId):
      let groupDeeplink = GroupMain.Deeplink.schedule(scheduleId: scheduleId, groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .group(let groupId):
      let groupDeeplink = GroupMain.Deeplink.group(groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .joinGroup(let inviteCode):
      return .send(.destination(.presented(.main(.openJoinGroupWithCode(inviteCode)))))

    case .liveActivityETA:
      // Widget "직접 입력" 버튼 → LiveScheduleExpandedView + ETA 시트 열기
      return .send(.destination(.presented(.main(.openLiveActivityETASheet))))

    case .liveSchedule:
      // LiveActivity 탭 → LiveScheduleExpandedView 열기 (ETA 시트 없이)
      return .send(.destination(.presented(.main(.openLiveScheduleDetail))))

    case .create:
      // Widget "일정 만들기" 버튼 → 그룹 탭 이동 + 일정 생성 (그룹 있을 때만)
      return .send(.destination(.presented(.main(.openCreateScheduleIfPossible))))

    case .personalEvent(let eventId):
      // Widget 개인 일정 탭 → 홈 탭 이동 + 개인 일정 상세 열기
      return .send(.destination(.presented(.main(.openPersonalEventDetail(eventId: eventId)))))

    case .proPlan:
      return .send(.destination(.presented(.main(.openProPlan))))
    }
  }

  /// 메인 화면이 준비되어 있으면 라우팅, 아니면 pending으로 저장
  private func routeOrPendDeeplink(_ destination: DeeplinkDestination, state: inout State) -> Effect<Action> {
    if case .main = state.destination {
      return routeDeeplink(destination)
    } else {
      state.pendingDeeplink = destination
      return .none
    }
  }
}
 

private extension AppEntry.Feature.State {
  mutating func reset() {
    self.splash = .visible
    self.destination = nil
    self.pendingDeeplink = nil
    self.pendingUserForMain = nil
    self.providerProfileImageURL = nil
    self.notificationPermission = nil
    self.isFullOnboarding = false
  }
}
