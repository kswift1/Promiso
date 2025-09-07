import XCTest
import ComposableArchitecture
@testable import ScheduleFeatureImplement

final class ScheduleFeatureTests: XCTestCase {
  func test_placeholder() async {
    let store = TestStore(initialState: Schedule.Feature.State()) {
      Schedule.Feature()
    }
    await store.send(.didTap)
  }
}