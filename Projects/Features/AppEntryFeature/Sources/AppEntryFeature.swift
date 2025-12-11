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
    
    public init() {}
    
    // MARK: - State
    
    @ObservableState
    public struct State {
      public enum Route: Equatable {
        case splash
        case auth
        case profile
        case main
      }
      
      public var route: Route = .splash
      var showSplash: Bool = true
      var shouldAnimateOut: Bool = false
      var pendingRoute: Route?
      public var auth: Auth.Feature.State = .init()
      var profile: ProfileSetup.State = .init()
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
      case sessionCheckResponse(Bool)
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
            return .run { send in
              let isAuthed = await authClient.isAuthenticated()
              await send(.internal(.sessionCheckResponse(isAuthed)))
            }
            
          case .splashAnimationCompleted:
            if let next = state.pendingRoute {
              state.route = next
              state.pendingRoute = nil
              state.shouldAnimateOut = false
            }
            return .none
          }
          
        case .internal(let internalAction):
          switch internalAction {
          case .sessionCheckResponse(let isAuthed):
            let next: State.Route = isAuthed ? .main : .auth
            state.route = next
            state.pendingRoute = next
            state.main = RootTab.Feature.State()
            state.auth = Auth.Feature.State()
            state.shouldAnimateOut = true
            return .none
          }
          
        case .auth(.delegate(.loggedIn(let serviceBundle))):
          state.profile = ProfileSetup.State(
            profileImageUrl: serviceBundle?.firebaseUser?.photoURL?.absoluteString,
            email: serviceBundle?.providerTokenBundle.email ?? serviceBundle?.firebaseUser?.email ?? "",
            uid: serviceBundle?.providerTokenBundle.userIdentifier ?? serviceBundle?.firebaseUser?.uid ?? "",
            fullName: serviceBundle?.providerTokenBundle.fullName
              ?? serviceBundle?.firebaseUser?.displayName
              ?? ""
          )
          state.route = .profile
          return .none
        
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
        case .splash:
          EmptyView()
          
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


