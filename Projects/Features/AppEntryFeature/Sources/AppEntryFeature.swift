// MARK: - AppEntryFeature.swift
// TCA 1.22.2를 사용한 AppEntry Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import AuthFeature
import Clients
import ComposableArchitecture
import Dependencies
import RootTabFeature
import ResourceKit
import SwiftUI

// MARK: - Feature Namespace

public enum AppEntry {}

// MARK: - Core Feature Implementation

extension AppEntry {
  
  // MARK: - Reducer
  
  @Reducer
  public struct Feature {
    @Dependency(\.authClient) var authClient
    @Dependency(\.userProfileClient) var userProfileClient

    public init() {}
    
    // MARK: - State
    
    @ObservableState
    public struct State {
      public enum Route: Equatable {
        case auth
        case profile
        case main
      }
      
      public var route: Route = .auth
      var showSplash: Bool = true
      var shouldAnimateOut: Bool = false
      public var auth: Auth.Feature.State = .init()
      public var profile: ProfileSetup.State = .init()
      public var main: RootTab.Feature.State = .init()
      
      public init() {}
    }
    
    // MARK: - Action
    
    public enum Action {
      case view(View)
      case `internal`(Internal)
      case auth(Auth.Feature.Action)
      case profile(ProfileSetup.Action)
      case main(RootTab.Feature.Action)
    }
    
    public enum View {
      case onAppear
      case splashAnimationCompleted
    }
    
    public enum Internal {
      case startSessionCheck
      case sessionCheckResponse(isAuthenticated: Bool)
      case startProfileCheck
      case profileCheckResponse(user: FirebaseUserSnapshot, hasProfile: Bool)
    }
    
    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Scope(state: \.auth, action: \.auth) {
        Auth.Feature()
      }
      
      Scope(state: \.main, action: \.main) {
        RootTab.Feature()
      }
      
      Scope(state: \.profile, action: \.profile) {
        ProfileSetup()
      }
      
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .send(.internal(.startSessionCheck))
            
          case .splashAnimationCompleted:
            state.shouldAnimateOut = false
            state.showSplash = false
            return .none
          }
          
        case .internal(let internalAction):
          switch internalAction {
            
          case .startSessionCheck:
            return .run { send in
              let isAuthenticated = await authClient.isAuthenticated()
              await send(.internal(.sessionCheckResponse(isAuthenticated: isAuthenticated)))
            }
            
          case .sessionCheckResponse(let isAuthenticated):
            state.shouldAnimateOut = true
            state.showSplash = true
            
            if isAuthenticated {
              return .send(.internal(.startProfileCheck))
            } else {
              state.route = .auth
              return .none
            }
            
          case .startProfileCheck:
            return .run { send in
              guard let user = await authClient.currentUser() else { return }
              // TODO:  Firestore에서 프로필 존재 여부 - 에러 대응 추가
              let hasProfile = (try? await userProfileClient.hasProfile(user.uid)) ?? false
              await send(.internal(.profileCheckResponse(user: user, hasProfile: hasProfile)))
            }
            
          case .profileCheckResponse(let user, let hasProfile):
            if hasProfile {
              state.route = .main
              state.main = RootTab.Feature.State()
            } else {
              state.profile.inject(user: user)
              state.route = .profile
            }
            return .none
          }
          
        case .auth(.delegate(.loggedIn)):
          return .send(.internal(.startProfileCheck))
        
        case .profile(.delegate(.completed)):
          state.route = .main
          state.main = RootTab.Feature.State()
          return .none
          
        case .main(.delegate(.logoutRequested)):
          state.route = .auth
          state.auth = Auth.Feature.State()
          return .run { _ in
            try? await authClient.logout()
          }
          
        case .auth, .profile, .main:
          return .none
        }
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
        switch store.route {
        case .auth:
          Auth.RootView(store: store.scope(state: \.auth, action: \.auth))
          
        case .profile:
          NavigationStack {
            AppEntry.ProfileSetup.View(
              store: store.scope(state: \.profile, action: \.profile)
            )
          }
        case .main:
          RootTab.RootView(store: store.scope(state: \.main, action: \.main))
        }
        
        // 스플래시 오버레이
        if store.showSplash {
          SplashView(
            config: .init(forceHideLogo: false),
            logo: { Image("fingerPromise") },
            animateOut: store.shouldAnimateOut,
            isCompleted: {
              store.send(.view(.splashAnimationCompleted))
            }
          )
          .transition(.opacity)
        }
      }
      .animation(.easeInOut, value: store.route)
      .animation(.easeInOut, value: store.showSplash)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}

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
  }
}
