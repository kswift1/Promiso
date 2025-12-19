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

import Domain

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
      public var currentUser: UserModel?
      public var main: RootTab.Feature.State?
      
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
      case profileCheckResponse(user: FirebaseUserSnapshot, profile: UserModel?)  // Clean Architecture: Domain Model
    }
    
    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Scope(state: \.auth, action: \.auth) {
        Auth.Feature()
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
              let profile = try? await userProfileClient.hasProfile(user.uid)
              await send(.internal(.profileCheckResponse(user: user, profile: profile)))
            }
            
          case .profileCheckResponse(let user, let profile):
            if let userModel = profile {
              state.currentUser = userModel
              state.main = RootTab.Feature.State(currentUser: userModel)
              state.route = .main
            } else {
              state.profile.inject(user: user)
              state.route = .profile
            }
            return .none
          }
          
        case .auth(.delegate(.loggedIn)):
          return .send(.internal(.startProfileCheck))
        
        case .profile(.delegate(.completed(let userModel))):
          // Clean Architecture: ProfileSetup이 Domain Model 전달
          state.currentUser = userModel
          state.main = RootTab.Feature.State(currentUser: userModel)
          state.route = .main
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
      .ifLet(\.main, action: \.main) {
        RootTab.Feature()
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
          if let mainStore = store.scope(state: \.main, action: \.main) {
            RootTab.RootView(store: mainStore)
          }
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
    self.profileInfo = nil
  }
}
