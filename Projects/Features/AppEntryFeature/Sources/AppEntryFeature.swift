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
        case onboarding
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
      case onboardingStartTapped
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
            
          case .onboardingStartTapped:
            state.route = .auth
            state.auth = Auth.Feature.State()
            return .none
            
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
            let next: State.Route = isAuthed ? .main : .onboarding
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
          OnboardingView { store.send(.view(.onboardingStartTapped)) }
        case .auth:
          Auth.RootView(store: store.scope(state: \.auth, action: \.auth))
        case .onboarding:
          OnboardingView { store.send(.view(.onboardingStartTapped)) }
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
          LaunchScreenView(
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

struct LaunchScreenConfig {
  var initialDelay: Double = 0.5
  var scaling: CGFloat = 4
  var forceHideLogo: Bool = false
  /// For Even More Customiaztion
  var animation: Animation = .smooth(duration: 1, extraBounce: 0)
}

fileprivate struct LaunchScreenView<Logo: View>: View {
  var config: LaunchScreenConfig
  @ViewBuilder var logo: Logo
  var animateOut: Bool
  var isCompleted: () -> ()
  /// View Properties
  @State private var scaleDown: Bool = false
  @State private var scaleUp: Bool = false
  @State private var started: Bool = false
  var body: some View {
    ZStack {
      // 1. Base Background Color
      Color(UIColor.systemGray6)
        .ignoresSafeArea()
      
      // 2. Aurora/Gradient Blobs
      CommonBackGroundView()
    }
    /// Reverse Logo Masking!
    .mask {
      GeometryReader {
        let size = $0.size.applying(.init(scaleX: config.scaling, y: config.scaling))
        
        Rectangle()
          .overlay {
            logo
              .offset(y: 14)
              .blur(radius: config.forceHideLogo ? 0 : (scaleUp ? 15 : 0))
              .blendMode(.destinationOut)
              .animation(.smooth(duration: 0.3, extraBounce: 0)) { content in
                content
                  .scaleEffect(scaleDown ? 0.8 : 1)
              }
              .visualEffect { [scaleUp] content, proxy in
                let scaleX: CGFloat = size.width / proxy.size.width
                let scaleY: CGFloat = size.height / proxy.size.height
                /// Logo Size based Scaling!
                let maxScale = Swift.max(scaleX, scaleY)
                return content
                  .scaleEffect(scaleUp ? maxScale : 1)
              }
          }
      }
    }
    .opacity(config.forceHideLogo ? 1 : (scaleUp ? 0 : 1 ))
    .background {
      Rectangle()
        .fill(.linearGradient(
          colors: [
            Color.brand.primary,
            Color.brand.secondary,
          ],
          startPoint: .leading,
          endPoint: .trailing
        ))
        .opacity(scaleUp ? 0 : 1)
    }
    .ignoresSafeArea()
    .task { await startIfNeeded(animateOut) }
    .onChange(of: animateOut, { _, newValue in
      Task { await startIfNeeded(newValue) }
    })
  }
  
  @MainActor
  private func startIfNeeded(_ shouldStart: Bool) async {
    guard shouldStart, !started else { return }
    started = true
    try? await Task.sleep(for: .seconds(config.initialDelay))
    scaleDown = true
    try? await Task.sleep(for: .seconds(0.1))
    withAnimation(config.animation, completionCriteria: .logicallyComplete) {
      scaleUp = true
    } completion: {
      isCompleted()
    }
  }
}
