import SwiftUI
import ComposableArchitecture
import MainFeatureInterface
import DesignSystem

public enum Main {}

extension Main {
  @Reducer
  public struct Feature {
    public init() {}
    public struct State: Equatable { public init() {} }
    public enum Action: Equatable { case didTap }
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        .none
      }
    }
  }

  public struct RootView: View {
    let store: StoreOf<Feature>
    public init(store: StoreOf<Feature>) { self.store = store }
    public var body: some View {
      VStack(spacing: DS.Spacing.l) {
        Text("Main Feature")
        Button("Tap") { store.send(.didTap) }
      }
      .padding()
      .background(DS.Color.bg)
    }
  }
}

public extension MainEntry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Main.Feature.State()) { Main.Feature() }
      return AnyView(Main.RootView(store: store))
    }
  }
}