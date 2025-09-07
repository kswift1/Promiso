import SwiftUI
import ComposableArchitecture
import HomeInterface

public enum Home {}

extension Home {
  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      public init() {}
    }

    public enum Action: Equatable {
      case didTap
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .didTap:
          return .none
        }
      }
    }
  }

  public struct RootView: View {
    let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) { self.store = store }

    public var body: some View {
      WithPerceptionTracking {
        VStack(spacing: 16) {
          Text("Home Feature").font(.title2)
          Button("Tap") { store.send(.didTap) }
            .buttonStyle(.borderedProminent)
        }
        .padding()
      }
    }
  }
}