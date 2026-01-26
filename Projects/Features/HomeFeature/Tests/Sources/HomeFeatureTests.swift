// MARK: - HomeFeatureTests.swift
// TCA TestStore를 사용한 Home Feature의 test suite

import XCTest
import ComposableArchitecture
@testable import HomeFeature
@testable import Clients

// MARK: - Feature Tests

@MainActor
final class HomeFeatureTests: XCTestCase {

//  private var mockUser: UserPrivateModel {
//    UserPrivateModel(
//      userId: "test-user-123",
//      name: "테스트",
//      nickname: "테스트유저",
//      email: "test@example.com",
//      provider: "apple",
//      profile: nil,
//      metadata: Metadata(createdAt: Date(), updatedAt: Date()),
//      groups: []
//    )
//  }
//
//  /// 기본 onAppear 동작을 테스트
//  func test_onAppear_triggersFetchAllData() async {
//    let store = TestStore(initialState: Home.Feature.State(currentUser: mockUser)) {
//      Home.Feature()
//    } withDependencies: {
//      $0.promiseClient = .previewValue
//    }
//
//    await store.send(.view(.onAppear)) {
//      $0.hasLoadedOnce = true
//    }
//
//    await store.receive(.internal(.fetchAllData)) {
//      $0.todaysPromisesState = .loading
//      $0.pendingResponsesState = .loading
//      $0.upcomingPromisesState = .loading
//    }
//  }
//
//  /// 두 번째 onAppear에서는 데이터를 다시 로드하지 않음
//  func test_onAppear_doesNotReloadIfAlreadyLoaded() async {
//    var state = Home.Feature.State(currentUser: mockUser)
//    state.hasLoadedOnce = true
//
//    let store = TestStore(initialState: state) {
//      Home.Feature()
//    }
//
//    await store.send(.view(.onAppear))
//    // No effect expected
//  }
}
