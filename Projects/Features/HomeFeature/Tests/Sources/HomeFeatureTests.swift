import XCTest
import ComposableArchitecture
@testable import HomeFeatureImplement

final class HomeFeatureTests: XCTestCase {
  func test_placeholder() async {
    let store = TestStore(initialState: Home.Feature.State()) {
      Home.Feature()
    }
    await store.send(.didTap)
  }
}