// MARK: - OnboardingStartFeature.swift
// Screen 10: 첫 약속 CTA - "준비 완료!"

import ComposableArchitecture

extension AppEntry {

  // MARK: - Onboarding Start (Screen 10)

  @Reducer
  public struct OnboardingStart {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      var nickname: String

      public init(nickname: String) {
        self.nickname = nickname
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction: Sendable {
        case createFirstPromiseTapped
        case skipTapped
      }

      public enum DelegateAction: Sendable {
        case createFirstPromise
        case completed
      }
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .createFirstPromiseTapped:
            return .send(.delegate(.createFirstPromise))
          case .skipTapped:
            return .send(.delegate(.completed))
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
