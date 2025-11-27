// MARK: - AppEntryFeature.swift
// TCA 1.22.2를 사용한 AppEntry Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import AuthFeature
import Clients
import ComposableArchitecture
import Dependencies
import RootTabFeature
import SwiftUI

// MARK: - Feature Namespace

public enum AppEntry {}

// MARK: - Core Feature Implementation

extension AppEntry {
  
  // MARK: - Reducer
  
  @Reducer
  public struct Feature {
    @Dependency(\.authClient) private var authClient: AuthClient
    
    public init() {}
    
    // MARK: - State
    
    @ObservableState
    public struct State {
      public enum Route: Equatable {
        case splash
        case onboarding
        case auth
        case main
      }
      
      public var route: Route = .splash
      public var auth: Auth.Feature.State = .init()
      public var main: RootTab.Feature.State = .init()
      
      public init() {}
    }
    
    // MARK: - Action
    
    public enum Action {
      case onAppear
      case onboardingStartTapped
      case auth(Auth.Feature.Action)
      case main(RootTab.Feature.Action)
      case _sessionCheckResponse(Bool)
    }
    
    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Scope(state: \.auth, action: \.auth) {
        Auth.Feature()
      }
      
      Scope(state: \.main, action: \.main) {
        RootTab.Feature()
      }
      
      Reduce { state, action in
        switch action {
        case .onAppear:
          return .run { send in
            let isAuthed = await authClient.isAuthenticated()
            await send(._sessionCheckResponse(isAuthed))
          }
          
        case ._sessionCheckResponse(let isAuthed):
          state.route = isAuthed ? .main : .onboarding
          state.main = RootTab.Feature.State()
          state.auth = Auth.Feature.State()
          return .none
        
        case .onboardingStartTapped:
          state.route = .auth
          state.auth = Auth.Feature.State()
          return .none
          
        case .auth(.delegate(.loggedIn)):
          state.route = .main
          state.main = RootTab.Feature.State()
          return .none
          
        case .main(.delegate(.logoutRequested)):
          state.route = .auth
          state.auth = Auth.Feature.State()
          return .run { _ in
            try? await authClient.logout()
          }
          
        case .auth, .main:
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
          ProgressView("로딩 중...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        case .auth:
          Auth.RootView(
            store: store.scope(state: \.auth, action: \.auth)
          )
          .transition(.opacity)
        
        case .onboarding:
          OnboardingView {
            store.send(.onboardingStartTapped)
          }
          .transition(.opacity)
          
        case .main:
          RootTab.RootView(
            store: store.scope(state: \.main, action: \.main)
          )
          .transition(.opacity)
        }
      }
      .animation(.easeInOut, value: store.route)
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

// MARK: - Onboarding View

private struct OnboardingView: View {
  let onStart: () -> Void
  
  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      
      VStack(spacing: 8) {
        Text("Promiso")
          .font(.largeTitle.bold())
        Text("약속을 지키는 습관을 시작해보세요.")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 24)
      
      Spacer()
      
      Button(action: onStart) {
        Text("시작하기")
          .frame(maxWidth: .infinity)
          .padding()
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
