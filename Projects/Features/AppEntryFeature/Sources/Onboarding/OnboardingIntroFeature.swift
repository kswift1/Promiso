// MARK: - OnboardingIntroFeature.swift

import AuthenticationServices
import Clients
import ComposableArchitecture

extension AppEntry {

  // MARK: - Onboarding Intro (Screens 1-7)

  @Reducer
  public struct OnboardingIntro {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      var currentScreen: Screen = .cinematicHero
      var isAnimationComplete: Bool = false
      var isNextButtonEnabled: Bool = true

      var pendingAppleLoginNonce: String?
      var isAuthLoading: Bool = false
      var authError: String?

      public init() {}

      enum Screen: Int, CaseIterable, Equatable {
        case cinematicHero = 0
        case benefitConfirm = 1
        case benefitHome = 2
        case benefitPro = 3
        case benefitLive = 4
        case signIn = 5
      }

      var isFirstScreen: Bool {
        currentScreen == Screen.allCases.first
      }

      var isLastScreen: Bool {
        currentScreen == Screen.allCases.last
      }

      var isGoingBack: Bool = false

      var screenProgress: Double {
        Double(currentScreen.rawValue)
      }

      var screenCount: Int {
        Screen.allCases.count
      }

      var showBottomNavigation: Bool {
        currentScreen != .signIn
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction: Sendable {
        case nextTapped
        case backTapped
        case skipTapped
        case screenAnimationCompleted
        case screenInteractionCompleted
        case signInWithAppleTapped
        case signInWithGoogleTapped
        case appleAuthorizationResult(Result<ASAuthorization, Error>)
      }

      @CasePathable
      public enum InternalAction: Sendable {
        case authFailed(String)
      }

      public enum DelegateAction: Equatable, Sendable {
        case authCompleted(providerProfileImageURL: URL?)
      }
    }

    // MARK: - Dependencies

    @Dependency(\.authClient) var authClient

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .nextTapped:
            guard state.currentScreen != .signIn else { return .none }
            state.isAnimationComplete = false
            state.isNextButtonEnabled = true
            state.isGoingBack = false
            let nextIndex = state.currentScreen.rawValue + 1
            if let nextScreen = State.Screen(rawValue: nextIndex) {
              state.currentScreen = nextScreen
            }
            return .none

          case .backTapped:
            guard !state.isFirstScreen else { return .none }
            state.isAnimationComplete = false
            state.isNextButtonEnabled = true
            state.isGoingBack = true
            let prevIndex = state.currentScreen.rawValue - 1
            if let prevScreen = State.Screen(rawValue: prevIndex) {
              state.currentScreen = prevScreen
            }
            return .none

          case .skipTapped:
            state.currentScreen = .signIn
            state.isAnimationComplete = true
            state.isNextButtonEnabled = true
            return .none

          case .screenAnimationCompleted:
            state.isAnimationComplete = true
            if state.currentScreen == .benefitLive {
              state.isNextButtonEnabled = false
            }
            return .none

          case .screenInteractionCompleted:
            state.isNextButtonEnabled = true
            return .none

          case .signInWithAppleTapped:
            state.authError = nil
            state.isAuthLoading = true
            state.pendingAppleLoginNonce = generateNonce()
            return .none

          case .signInWithGoogleTapped:
            state.authError = nil
            state.isAuthLoading = true
            return .run { [authClient] send in
              do {
                let bundle = try await authClient.signInWithGoogle()
                await send(.delegate(.authCompleted(providerProfileImageURL: bundle.profileImageURL)))
              } catch {
                await send(.internal(.authFailed(error.localizedDescription)))
              }
            }

          case .appleAuthorizationResult(.success(let authorization)):
            guard let nonce = state.pendingAppleLoginNonce else {
              state.isAuthLoading = false
              state.authError = "로그인에 실패했습니다"
              return .none
            }
            return .run { [authClient] send in
              do {
                let bundle = try await authClient.signInWithApple(authorization, nonce)
                await send(.delegate(.authCompleted(providerProfileImageURL: bundle.profileImageURL)))
              } catch {
                await send(.internal(.authFailed(error.localizedDescription)))
              }
            }

          case .appleAuthorizationResult(.failure):
            state.isAuthLoading = false
            state.pendingAppleLoginNonce = nil
            state.authError = "로그인에 실패했습니다"
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .authFailed(let errorMessage):
            state.isAuthLoading = false
            state.pendingAppleLoginNonce = nil
            state.authError = errorMessage
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private func generateNonce(length: Int = 32) -> String {
      var randomBytes = [UInt8](repeating: 0, count: length)
      _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
      let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
  }
}
