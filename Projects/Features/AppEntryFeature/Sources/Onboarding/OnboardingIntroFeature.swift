// MARK: - OnboardingIntroFeature.swift

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

      public init() {}

      enum Screen: Int, CaseIterable, Equatable {
        case cinematicHero = 0
        case benefitConfirm = 1
        case benefitLive = 2
        case benefitHome = 3
        case benefitPro = 4
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
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction: Sendable {
        case nextTapped
        case backTapped
        case skipTapped
        case screenAnimationCompleted
        case screenInteractionCompleted
      }

      public enum DelegateAction: Equatable, Sendable {
        case introCompleted
      }
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .nextTapped:
            guard !state.isLastScreen else {
              return .send(.delegate(.introCompleted))
            }
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
            return .send(.delegate(.introCompleted))

          case .screenAnimationCompleted:
            state.isAnimationComplete = true
            if state.currentScreen == .benefitLive {
              state.isNextButtonEnabled = false
            }
            return .none

          case .screenInteractionCompleted:
            state.isNextButtonEnabled = true
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
