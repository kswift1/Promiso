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

      public init() {}

      enum Screen: Int, CaseIterable, Equatable {
        case cinematicHero = 0
        case problemEmpathy = 1
        case benefitVote = 2
        case benefitHome = 3
        case benefitLive = 4
        case premiumTeaser = 5
      }

      var isLastScreen: Bool {
        currentScreen == Screen.allCases.last
      }

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
        case skipTapped
        case screenAnimationCompleted
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
            if state.isLastScreen {
              // 마지막 화면에서 "다음" → 온보딩 완료
              logPremiumInterests(state.interestedPremiumFeatures)
              return .send(.delegate(.completed))
            } else {
              // 다음 화면으로 이동
              let nextIndex = state.currentScreen.rawValue + 1
              if let nextScreen = State.Screen(rawValue: nextIndex) {
                state.currentScreen = nextScreen
              }
              return .none
            }

          case .skipTapped:
            logPremiumInterests(state.interestedPremiumFeatures)
            return .send(.delegate(.completed))

          case .screenAnimationCompleted:
            state.isAnimationComplete = true
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
