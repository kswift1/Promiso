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

      /// 빈 초기화 — onAppear에서 fetch 수행
      public init() {}

      /// 미리 fetch된 model로 초기화 — onAppear fetch 스킵
      public init(model: WhatsNewModel) {
        self.model = model
        self.isLoading = false
      }
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
            // 이미 AppEntryFeature에서 fetch한 model이 있으면 네트워크 호출 스킵
            if state.model != nil { return .none }
            let version = AppConstants.App.version
            return .run { send in
              do {
                let model = try await whatsNewClient.fetchWhatsNew(version)
                await send(.internal(.whatsNewLoaded(model)))
              } catch {
                await send(.internal(.whatsNewLoaded(nil)))
              }
            }

          case .nextTapped:
            guard let model = state.model else { return .none }
            // 표지(0) + items + 클로징(items.count+1) → 총 페이지 = items.count + 2
            if state.currentIndex < model.items.count + 1 {
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
              // 데이터 없음(비활성화/빈 목록): 현재 버전 마킹 후 닫기
              userDefaultsClient.markWhatsNewSeen(version: AppConstants.App.version)
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
