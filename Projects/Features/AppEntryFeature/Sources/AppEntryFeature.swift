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

      public init() {
        self.destination = .auth(AuthFeature.Auth.Feature.State())
      }
    }


    // MARK: - Action

    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case destination(PresentationAction<Destination.Action>)
      case notificationPermission(PresentationAction<NotificationPermission.Feature.Action>)
    }
    
    public enum ViewAction {
      case onAppear
      case splashAnimationCompleted
      case handleDeeplink(URL)
    }
    
    public enum InternalAction {
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
    }

    // MARK: - Destination Reducer

    @Reducer
    public enum Destination {
      case auth(AuthFeature.Auth.Feature)
      case profile(ProfileSetup)
      case main(RootTab.Feature)
    }

    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .merge(
              .send(.internal(.startSessionCheck)),
              .send(.internal(.subscribeFCMToken)),
              .send(.internal(.subscribePushNotificationTap)),
              .send(.internal(.subscribeAppRestart))
            )

          case .splashAnimationCompleted:
            state.splash = .hidden
            return .none

          case .handleDeeplink(let url):
            guard let destination = deeplinkClient.parseURL(url) else { return .none }
            return routeOrPendDeeplink(destination, state: &state)
          }

        case .internal(let internalAction):
          switch internalAction {
            
          case .startSessionCheck:
            return .run { send in
              let isAuthenticated = await authClient.isAuthenticated()
              await send(.internal(.sessionCheckResponse(isAuthenticated: isAuthenticated)))
            }
            
          case .sessionCheckResponse(let isAuthenticated):
            if isAuthenticated {
              return .send(.internal(.startProfileCheck))
            } else {
              state.destination = .auth(Auth.Feature.State())
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
              // 기존 사용자 → 바로 메인으로 (알림 권한 체크 안 함)
              if state.splash == .visible {
                state.splash = .animatingOut
              }
              WidgetDataManager.saveUserId(userModel.id)
              state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))
              // pending deeplink가 있으면 처리
              if let deeplink = state.pendingDeeplink {
                state.pendingDeeplink = nil
                return routeDeeplink(deeplink)
              }
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
              WidgetDataManager.saveUserId(userModel.id)
              state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))
              // pending deeplink가 있으면 처리
              if let deeplink = state.pendingDeeplink {
                state.pendingDeeplink = nil
                return routeDeeplink(deeplink)
              }
            } else {
              // 권한 미허용 → 온보딩 표시
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
            state.splash = .visible
            state.destination = nil
            state.pendingDeeplink = nil
            state.pendingUserForMain = nil
            state.providerProfileImageURL = nil
            state.notificationPermission = nil
            // 시간 포맷 다시 로드
            KoreanDateFormatters.use24HourFormat = UserDefaults.standard.bool(
              forKey: AppConstants.UserDefaults.use24HourFormat
            )
            return .send(.internal(.startSessionCheck))

          case .checkNotificationPermission(let userModel):
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
              let isAuthorized = status == .authorized
              await send(.internal(.notificationPermissionChecked(isAuthorized: isAuthorized, user: userModel)))
            }

          case .notificationPermissionChecked(let isAuthorized, let userModel):
            if isAuthorized {
              // 이미 권한 허용됨 → 바로 메인으로
              WidgetDataManager.saveUserId(userModel.id)
              state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))
              // pending deeplink가 있으면 처리
              if let deeplink = state.pendingDeeplink {
                state.pendingDeeplink = nil
                return routeDeeplink(deeplink)
              }
            } else {
              // 권한 미허용 → 온보딩 표시
              state.pendingUserForMain = userModel
              state.notificationPermission = NotificationPermission.Feature.State()
            }
            return .none
          }

        case .destination(.presented(.auth(.delegate(.loggedIn(let providerProfileImageURL))))):
          state.providerProfileImageURL = providerProfileImageURL
          return .send(.internal(.startProfileCheck))

        case .destination(.presented(.profile(.delegate(.completed(let userModel))))):
          // 프로필 설정 완료 → 알림 권한 상태 확인
          return .send(.internal(.checkNotificationPermission(userModel)))

        case .notificationPermission(.presented(.delegate(.dismissed))),
             .notificationPermission(.presented(.delegate(.permissionChanged))):
          // 알림 권한 온보딩 완료 → 메인 화면으로 이동
          state.notificationPermission = nil
          if let userModel = state.pendingUserForMain {
            state.pendingUserForMain = nil
            WidgetDataManager.saveUserId(userModel.id)
            state.destination = .main(RootTab.Feature.State(currentUser: Shared(value: userModel)))
          }
          return .none

        case .notificationPermission:
          return .none

        case .destination(.presented(.main(.delegate(.logoutRequested)))):
          state.destination = .auth(Auth.Feature.State())
          return .run { [notificationClient, authClient] _ in
            LiveActivityImageStore.clearCache()
            WidgetDataManager.clearAll()
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
    
    public init(store: StoreOf<Feature>) {
      self.store = store
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
      .fullScreenCover(
        item: $store.scope(
          state: \.notificationPermission,
          action: \.notificationPermission
        )
      ) { store in
        NotificationPermission.View(store: store)
      }
    }

    @ViewBuilder
    private var contentView: some View {
      switch store.destination {
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
    case auth, profile, main
  }

  var destinationType: DestinationType? {
    switch destination {
    case .auth: return .auth
    case .profile: return .profile
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
 
