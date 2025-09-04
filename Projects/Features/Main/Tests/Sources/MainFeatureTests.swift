import XCTest
import ComposableArchitecture
@testable import MainFeatureImplement

final class MainFeatureTests: XCTestCase {
  func test_nop() {
    let store = TestStore(initialState: Main.Feature.State()) { Main.Feature() }
    // TODO: write tests
  }
}