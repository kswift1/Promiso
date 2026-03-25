// MARK: - WhatsNewFeature.swift
import Clients
import ComposableArchitecture
import PromisoShared

// MARK: - Feature Namespace

public enum WhatsNew {}

// MARK: - Feature Implementation

extension WhatsNew {

  @Reducer
  public struct Feature {
    @Dependency(\.whatsNewClient) var whatsNewClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var model: WhatsNewModel?
      var isLoading: Bool = true
      var currentIndex: Int = 0

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
    }

    @CasePathable
    public enum ViewAction: Sendable {
      case onAppear
      case nextTapped
      case previousTapped
      case dismissTapped
    }

    @CasePathable
    public enum InternalAction: Sendable {
      case whatsNewLoaded(WhatsNewModel?)
    }

    public enum DelegateAction: Sendable {
      case dismissed
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            let version = AppConstants.App.version
            return .run { send in
              let model = try? await whatsNewClient.fetchWhatsNew(version)
              await send(.internal(.whatsNewLoaded(model)))
            }

          case .nextTapped:
            guard let model = state.model else { return .none }
            if state.currentIndex < model.items.count - 1 {
              state.currentIndex += 1
            } else {
              // 마지막 → 닫기
              return dismissAndMark(state: &state)
            }
            return .none

          case .previousTapped:
            if state.currentIndex > 0 {
              state.currentIndex -= 1
            }
            return .none

          case .dismissTapped:
            return dismissAndMark(state: &state)
          }

        case .internal(let internalAction):
          switch internalAction {
          case .whatsNewLoaded(let model):
            state.isLoading = false
            if let model, !model.items.isEmpty {
              state.model = model
            } else {
              // 데이터가 없으면 바로 닫기
              return .send(.delegate(.dismissed))
            }
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    private func dismissAndMark(state: inout State) -> Effect<Action> {
      if let version = state.model?.version {
        userDefaultsClient.markWhatsNewSeen(version: version)
      }
      return .send(.delegate(.dismissed))
    }
  }
}
