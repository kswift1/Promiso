import XCTest
import ComposableArchitecture
@testable import MainFeatureImplement

final class MainFeatureTests: XCTestCase {
  func test_placeholder() async {
    let store = TestStore(initialState: Main.Feature.State()) {
      Main.Feature()
    }
    await store.send(.didTap)
  }
}