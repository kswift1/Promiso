// MARK: - AppEntryFeature.swift
import AuthFeature
import Clients
import ComposableArchitecture
import Dependencies
import PromisoShared
import RootTabFeature
import ResourceKit
import SharedFeature
import SwiftUI

// MARK: - Feature Namespace

public enum AppEntry {}
extension AppEntry.Feature.State: Sendable {}
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
      case subscribeAppRestart
      case appRestartRequested
      case transitionToMain(UserPrivateModel, isSignup: Bool)
    }

    // MARK: - Destination Reducer

    @Reducer
    public enum Destination {
      case onboardingIntro(AppEntry.OnboardingIntro)
      case auth(AuthFeature.Auth.Feature)
      case profile(ProfileSetup)
      case onboardingStart(AppEntry.OnboardingStart)
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
              .send(.internal(.subscribePushNotificationTap)),
              .send(.internal(.subscribeAppRestart))
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
              // 온보딩 인트로 완료 여부에 따라 분기
              let hasCompletedOnboarding = userDefaultsClient.boolForKey(AppConstants.UserDefaults.hasCompletedOnboarding)
              if !hasCompletedOnboarding {
                state.isFullOnboarding = true
                state.destination = .onboardingIntro(OnboardingIntro.State())
              } else {
                state.destination = .auth(Auth.Feature.State())
              }
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
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
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

          case .fcmTokenReceived(let token):
            return .run { [notificationClient] send in
              // 로그인된 사용자만 토큰 저장
              let isAuthenticated = await authClient.isAuthenticated()
              guard isAuthenticated else { return }

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

          case .pushNotificationTapped(let destination):
            return routeOrPendDeeplink(destination, state: &state)

          case .subscribeAppRestart:
            return .publisher {
              NotificationCenter.default
                .publisher(for: AppConstants.Notifications.appRestartRequested)
                .map { _ in Action.internal(.appRestartRequested) }
            }

          case .appRestartRequested:
            // 앱 상태 리셋 - Splash부터 다시 시작
            state.reset()

            // 시간 포맷 다시 로드
            KoreanDateFormatters.use24HourFormat = userDefaultsClient.boolForKey(
              AppConstants.UserDefaults.use24HourFormat
            )

            // 테마 모드는 RootTab에서 preferredColorScheme으로 자동 적용됨
            // (UserDefaults.preferredThemeMode 값을 직접 읽음)

            return .send(.internal(.startSessionCheck))

          case .transitionToMain(let userModel, let isSignup):
            WidgetDataManager.saveUserId(userModel.id)
            clarityClient.setUser(userModel.id, userModel.nickname)
            analyticsClient.setUserID(userModel.id)
            analyticsClient.setUserProperty(userModel.nickname, "nickname")

            if isSignup {
              analyticsClient.logEvent(AnalyticsClient.EventName.userSignup, nil)
            } else {
              analyticsClient.logEvent(AnalyticsClient.EventName.userLogin, nil)
            }

            state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))

            // 그룹 멤버 캐시 초기화 (백그라운드)
            let groupIds = userModel.groups.map(\.id)
            let cacheEffect: Effect<Action> = .run { [groupClient] _ in
              @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
              var groupMembersCache: [String: [UserPublicModel]] = [:]
              for groupId in groupIds {
                if let members = try? await groupClient.fetchGroupMembers(groupId) {
                  $groupMembersCache.withLock { $0[groupId] = members }
                }
              }
            }

            if let deeplink = state.pendingDeeplink {
              state.pendingDeeplink = nil
              return .merge(routeDeeplink(deeplink), cacheEffect)
            }
            return cacheEffect
          }

        case .destination(.presented(.onboardingIntro(.delegate(.completed)))):
          // 인트로 완료 → 알림 권한 요청 (플래그는 알림 권한 완료 후 저장)
          state.notificationPermission = NotificationPermission.Feature.State()
          return .none

        case .destination(.presented(.onboardingStart(.delegate(.completed)))):
          // "나중에 둘러볼게요" → 메인으로
          if let userModel = state.pendingUserForMain {
            state.pendingUserForMain = nil
            return .send(.internal(.transitionToMain(userModel, isSignup: true)))
          }
          return .none

        case .destination(.presented(.onboardingStart(.delegate(.enterInviteCode)))):
          // "입력하러가기" → 메인 + 그룹 참여 열기
          if let userModel = state.pendingUserForMain {
            state.pendingUserForMain = nil
            state.pendingDeeplink = .joinGroup(inviteCode: "")
            return .send(.internal(.transitionToMain(userModel, isSignup: true)))
          }
          return .none

        case .destination(.presented(.onboardingStart(.delegate(.createGroup)))):
          // "그룹 생성하기" → 메인 + 그룹 생성 열기
          if let userModel = state.pendingUserForMain {
            state.pendingUserForMain = nil
            return .concatenate(
              .send(.internal(.transitionToMain(userModel, isSignup: true))),
              .send(.destination(.presented(.main(.openCreateGroup))))
            )
          }
          return .none

        case .destination(.presented(.auth(.delegate(.loggedIn(let providerProfileImageURL))))):
          state.providerProfileImageURL = providerProfileImageURL
          return .send(.internal(.startProfileCheck))

        case .destination(.presented(.profile(.delegate(.completed(let userModel))))):
          analyticsClient.logEvent(AnalyticsClient.EventName.profileSetupCompleted, nil)
          if state.isFullOnboarding {
            // 풀 온보딩 플로우 → OnboardingStart (시작 CTA)
            state.pendingUserForMain = userModel
            state.destination = .onboardingStart(OnboardingStart.State(nickname: userModel.nickname))
            return .none
          } else {
            // 재로그인 후 프로필 설정 (엣지 케이스) → 알림 권한 확인
            return .send(.internal(.checkNotificationPermission(userModel)))
          }

        case .notificationPermission(.presented(.delegate(.dismissed))),
             .notificationPermission(.presented(.delegate(.permissionChanged))):
          state.notificationPermission = nil
          // 온보딩 완료 플래그 저장 (인트로 + 알림 권한까지 완료)
          userDefaultsClient.setBool(true, AppConstants.UserDefaults.hasCompletedOnboarding)
          if let userModel = state.pendingUserForMain {
            // 기존 플로우: 프로필 설정 후 알림 권한 → 메인 전환
            state.pendingUserForMain = nil
            return .send(.internal(.transitionToMain(userModel, isSignup: true)))
          } else {
            // 풀 온보딩 플로우: 인트로 후 알림 권한 → 로그인 화면
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
      static let forceUpdateTitle = "업데이트 필요"
      static let recommendUpdateTitle = "새 버전 안내"

      static func forceUpdateMessage(current: String, required: String) -> String {
        "앱을 계속 사용하려면 최신 버전으로 업데이트해주세요.\n\n현재 버전: \(current)\n필요 버전: \(required)"
      }

      static func recommendUpdateMessage(current: String, recommended: String) -> String {
        "더 나은 경험을 위해 최신 버전으로 업데이트하세요.\n\n현재 버전: \(current)\n최신 버전: \(recommended)"
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
        Button("업데이트") {
          store.send(.updateAlert(.updateTapped))
        }
        if case .recommendUpdate = alertState {
          Button("나중에", role: .cancel) {
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

      case .onboardingStart:
        if let store = store.scope(state: \.destination?.onboardingStart, action: \.destination.onboardingStart) {
          AppEntry.OnboardingStart.View(store: store)
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
          logo: { ResourceKitAsset.fingerPromise.swiftUIImage },
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
    case onboardingIntro, auth, profile, onboardingStart, main
  }

  var destinationType: DestinationType? {
    switch destination {
    case .onboardingIntro: return .onboardingIntro
    case .auth: return .auth
    case .profile: return .profile
    case .onboardingStart: return .onboardingStart
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
    case .promise(let promiseId, let groupId):
      let groupDeeplink = GroupMain.Deeplink.promise(promiseId: promiseId, groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .group(let groupId):
      let groupDeeplink = GroupMain.Deeplink.group(groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .joinGroup(let inviteCode):
      return .send(.destination(.presented(.main(.openJoinGroupWithCode(inviteCode)))))

    case .liveActivityETA:
      // Widget "직접 입력" 버튼 → LivePromiseExpandedView + ETA 시트 열기
      return .send(.destination(.presented(.main(.openLiveActivityETASheet))))

    case .livePromise:
      // LiveActivity 탭 → LivePromiseExpandedView 열기 (ETA 시트 없이)
      return .send(.destination(.presented(.main(.openLivePromiseDetail))))

    case .create:
      // Widget "약속 만들기" 버튼 → 그룹 탭 이동 + 약속 생성 (그룹 있을 때만)
      return .send(.destination(.presented(.main(.openCreatePromiseIfPossible))))
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
