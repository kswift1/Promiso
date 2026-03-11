// MARK: - OnboardingStartFeature.swift
// 온보딩 완료 → 그룹 만들기 / 초대코드 / 개인 일정

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
        case createGroupTapped
        case enterInviteCodeTapped
        case personalScheduleTapped
      }

      public enum DelegateAction: Sendable {
        case createGroup
        case enterInviteCode
        case completed
      }
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .createGroupTapped:
            return .send(.delegate(.createGroup))
          case .enterInviteCodeTapped:
            return .send(.delegate(.enterInviteCode))
          case .personalScheduleTapped:
            return .send(.delegate(.completed))
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
