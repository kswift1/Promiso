// MARK: - OnboardingIntroFeature.swift

import ComposableArchitecture
import Clients

extension AppEntry {

  // MARK: - Onboarding Intro (Screens 1-6)

  @Reducer
  public struct OnboardingIntro {
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      var currentScreen: Screen = .cinematicHero
      var interestedPremiumFeatures: Set<String> = []
      var isAnimationComplete: Bool = false
      var isNextButtonEnabled: Bool = true

      public init() {}

      enum Screen: Int, CaseIterable, Equatable {
        case cinematicHero = 0
        case problemEmpathy = 1
        case benefitVote = 2
        case benefitHome = 3
        case benefitLive = 4
        case premiumTeaser = 5
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
        case premiumInterestToggled(String)
      }

      public enum DelegateAction: Sendable {
        case completed
      }
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .nextTapped:
            state.isAnimationComplete = false
            state.isNextButtonEnabled = true
            state.isGoingBack = false
            if state.isLastScreen {
              logPremiumInterests(state.interestedPremiumFeatures)
              return .send(.delegate(.completed))
            } else {
              let nextIndex = state.currentScreen.rawValue + 1
              if let nextScreen = State.Screen(rawValue: nextIndex) {
                state.currentScreen = nextScreen
              }
              return .none
            }

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
            logPremiumInterests(state.interestedPremiumFeatures)
            return .send(.delegate(.completed))

          case .screenAnimationCompleted:
            state.isAnimationComplete = true
            if state.currentScreen == .benefitLive {
              state.isNextButtonEnabled = false
            }
            return .none

          case .screenInteractionCompleted:
            state.isNextButtonEnabled = true
            return .none

          case .premiumInterestToggled(let feature):
            if state.interestedPremiumFeatures.contains(feature) {
              state.interestedPremiumFeatures.remove(feature)
            } else {
              state.interestedPremiumFeatures.insert(feature)
              analyticsClient.logEvent("premium_interest", ["feature": feature])
            }
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Helpers

    private func logPremiumInterests(_ features: Set<String>) {
      guard !features.isEmpty else { return }
      analyticsClient.logEvent(
        "onboarding_premium_interests",
        ["features": features.sorted().joined(separator: ",")]
      )
    }
  }
}
