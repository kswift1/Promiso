// MARK: - AppEntryFeature.swift
import AuthFeature
import Clients
import ComposableArchitecture
import Dependencies
import RootTabFeature
import ResourceKit
import SharedFeature
import SwiftUI

import PromisoShared

// MARK: - Feature Namespace

public enum AppEntry {}

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
    public struct State {
      public enum SplashState: Equatable {
        case visible
        case animatingOut
        case hidden
      }

      var splash: SplashState = .visible

      @Presents public var destination: Destination.State?

      /// 앱이 준비되기 전 수신된 딥링크 (메인 화면 전환 후 처리)
      var pendingDeeplink: DeeplinkDestination?

      public init() {
        self.destination = .auth(AuthFeature.Auth.Feature.State())
      }
    }


    // MARK: - Action

    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case destination(PresentationAction<Destination.Action>)
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
      case subscribeFCMToken
      case fcmTokenReceived(String)
      case fcmTokenSaved
      case subscribePushNotificationTap
      case pushNotificationTapped(DeeplinkDestination)
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
              .send(.internal(.subscribePushNotificationTap))
            )

          case .splashAnimationCompleted:
            state.splash = .hidden
            return .none

          case .handleDeeplink(let url):
            // DeeplinkClient를 사용하여 URL 파싱
            AppLogger.deeplink.debug("URL received: \(url.absoluteString)")
            guard let destination = deeplinkClient.parseURL(url) else {
              AppLogger.deeplink.warning("Failed to parse URL: \(url.absoluteString)")
              return .none
            }
            AppLogger.deeplink.debug("Parsed destination: \(String(describing: destination))")

            // 메인 화면이 준비되어 있으면 바로 전달, 아니면 pending으로 저장
            if case .main = state.destination {
              AppLogger.deeplink.debug("Main screen ready, forwarding deeplink")
              return routeDeeplink(destination)
            } else {
              AppLogger.deeplink.debug("Main not ready, saving as pending")
              state.pendingDeeplink = destination
              return .none
            }
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
              state.destination = .main(RootTab.Feature.State(currentUser: userModel))
              if state.splash == .visible {
                state.splash = .animatingOut
              }
              // pending deeplink가 있으면 메인 화면에 전달
              if let deeplink = state.pendingDeeplink {
                state.pendingDeeplink = nil
                return routeDeeplink(deeplink)
              }
            } else {
              var profileState = ProfileSetup.State()
              profileState.inject(user: user)
              state.destination = .profile(profileState)
              if state.splash == .visible {
                state.splash = .animatingOut
              }
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
            return .run { send in
              // 로그인된 사용자만 토큰 저장
              let isAuthenticated = await authClient.isAuthenticated()
              guard isAuthenticated else { return }

              try? await notificationClient.saveFCMToken(token)
              await send(.internal(.fcmTokenSaved))
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
            // 메인 화면이 준비되어 있으면 바로 전달, 아니면 pending으로 저장
            if case .main = state.destination {
              return routeDeeplink(destination)
            } else {
              state.pendingDeeplink = destination
              return .none
            }
          }

        case .destination(.presented(.auth(.delegate(.loggedIn)))):
          return .send(.internal(.startProfileCheck))

        case .destination(.presented(.profile(.delegate(.completed(let userModel))))):
          state.destination = .main(RootTab.Feature.State(currentUser: userModel))
          return .none

        case .destination(.presented(.main(.delegate(.logoutRequested)))):
          state.destination = .auth(Auth.Feature.State())
          return .run { _ in
            try? await authClient.logout()
          }

        case .destination:
          return .none
        }
      }
      .ifLet(\.$destination, action: \.destination)
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
          logo: { Image("fingerPromise") },
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
  mutating func inject(user: FirebaseUserSnapshot) {
    if let profileImageURL = user.photoURL {
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
  func routeDeeplink(_ destination: DeeplinkDestination) -> Effect<Action> {
    switch destination {
    case .promise(let promiseId, let groupId):
      let groupDeeplink = GroupMain.Deeplink.promise(promiseId: promiseId, groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .group(let groupId):
      let groupDeeplink = GroupMain.Deeplink.group(groupId: groupId)
      return .send(.destination(.presented(.main(.handleGroupDeeplink(groupDeeplink)))))

    case .joinGroup(let inviteCode):
      return .send(.destination(.presented(.main(.openJoinGroupWithCode(inviteCode)))))
    }
  }
}
 
