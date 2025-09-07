import XCTest
import ComposableArchitecture
@testable import RootTabFeatureImplement

final class RootTabFeatureTests: XCTestCase {
  func test_placeholder() async {
    let store = TestStore(initialState: RootTab.Feature.State()) {
      RootTab.Feature()
    }
    await store.send(.didTap)
  }
}