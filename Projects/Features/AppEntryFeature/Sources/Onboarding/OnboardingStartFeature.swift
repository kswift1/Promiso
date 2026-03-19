// MARK: - OnboardingStartFeature.swift
// 온보딩 완료 → 시작하기

import ComposableArchitecture

extension AppEntry {

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
        case startTapped
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
          case .startTapped:
            return .send(.delegate(.completed))
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
