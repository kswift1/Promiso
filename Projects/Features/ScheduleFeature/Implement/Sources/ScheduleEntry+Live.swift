import SwiftUI
import ComposableArchitecture
import ScheduleInterface

public extension ScheduleEntry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Schedule.Feature.State()) {
        Schedule.Feature()
      }
      return AnyView(Schedule.RootView(store: store))
    }
  }
}