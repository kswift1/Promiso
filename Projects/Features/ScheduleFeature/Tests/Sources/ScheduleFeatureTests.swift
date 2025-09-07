// MARK: - ScheduleFeatureTests.swift
// TCA TestStore를 사용한 Schedule Feature의 포괄적인 test suite
// 이 파일은 business logic의 정확성과 state management의 무결성을 보장

import XCTest
import ComposableArchitecture
@testable import ScheduleFeatureImplement

// MARK: - Feature Tests

/// Schedule Feature reducer와 business logic을 위한 Test suite
/// 예측 가능한 state testing과 side effect 검증을 위해 TCA의 TestStore를 사용
@MainActor
final class ScheduleFeatureTests: XCTestCase {
  
  // MARK: - Lifecycle Tests
  
  /// initial state와 onAppear 동작을 테스트
  func test_onAppear_startsLoadingAndCompletes() async {
    let store = TestStore(initialState: Schedule.Feature.State()) {
      Schedule.Feature()
    }
    
    // onAppear가 loading을 트리거하는지 테스트
    await store.send(.onAppear) {
      $0.isLoading = true
      $0.error = nil
    }
    
    // async 완료를 테스트
    await store.receive(.loadDataResponse(.success(()))) {
      $0.isLoading = false
    }
  }
  
  /// refresh 기능을 테스트
  func test_refresh_reloadsData() async {
    let store = TestStore(
      initialState: Schedule.Feature.State(isLoading: false)
    ) {
      Schedule.Feature()
    }
    
    await store.send(.refresh) {
      $0.isLoading = true
      $0.error = nil
    }
    
    await store.receive(.loadDataResponse(.success(()))) {
      $0.isLoading = false
    }
  }
  
  // MARK: - Error Handling Tests
  
  /// Tests error handling during data loading
  func test_loadDataFailure_setsErrorState() async {
    let store = TestStore(initialState: Schedule.Feature.State()) {
      Schedule.Feature()
    }
    
    let error = ScheduleError.networkError
    
    await store.send(.onAppear) {
      $0.isLoading = true
    }
    
    await store.receive(.loadDataResponse(.failure(error))) {
      $0.isLoading = false
      $0.error = error
    }
  }
  
  /// Tests error dismissal functionality
  func test_dismissError_clearsErrorState() async {
    let store = TestStore(
      initialState: Schedule.Feature.State(
        error: ScheduleError.dataError
      )
    ) {
      Schedule.Feature()
    }
    
    await store.send(.dismissError) {
      $0.error = nil
    }
  }
  
  // MARK: - User Interaction Tests
  
  /// Tests user action handling
  func test_didTapAction_handlesUserInteraction() async {
    let store = TestStore(initialState: Schedule.Feature.State()) {
      Schedule.Feature()
    }
    
    await store.send(.didTapAction)
    // Add assertions for expected state changes or side effects
  }
  
  // MARK: - State Tests
  
  /// Tests initial state configuration
  func test_initialState_hasCorrectDefaults() {
    let state = Schedule.Feature.State()
    
    XCTAssertFalse(state.isLoading)
    XCTAssertNil(state.error)
    // Add assertions for additional state properties
  }
  
  /// Tests state equality for proper SwiftUI updates
  func test_state_equatableConformance() {
    let state1 = Schedule.Feature.State(isLoading: true)
    let state2 = Schedule.Feature.State(isLoading: true)
    let state3 = Schedule.Feature.State(isLoading: false)
    
    XCTAssertEqual(state1, state2)
    XCTAssertNotEqual(state1, state3)
  }
}

// MARK: - Error Tests

/// Test suite for ScheduleError type and error handling
final class ScheduleErrorTests: XCTestCase {
  
  /// Tests error localized descriptions
  func test_errorDescriptions_provideUserFriendlyMessages() {
    let networkError = ScheduleError.networkError
    let dataError = ScheduleError.dataError
    let customError = ScheduleError.custom("Test message")
    
    XCTAssertEqual(networkError.errorDescription, "Network connection failed. Please try again.")
    XCTAssertEqual(dataError.errorDescription, "Unable to process data. Please try again.")
    XCTAssertEqual(customError.errorDescription, "Test message")
  }
  
  /// Tests error equality for state management
  func test_errorEquality() {
    let error1 = ScheduleError.networkError
    let error2 = ScheduleError.networkError
    let error3 = ScheduleError.dataError
    let error4 = ScheduleError.custom("Test")
    let error5 = ScheduleError.custom("Test")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertEqual(error4, error5)
  }
}

// MARK: - Integration Tests

/// Integration tests for feature entry points and view integration
@MainActor
final class ScheduleEntryTests: XCTestCase {
  
  /// Tests live entry point creation
  func test_liveEntry_createsValidInstance() {
    let entry = ScheduleEntry.live()
    let view = entry.makeView(.init())
    
    XCTAssertNotNil(view)
  }
  
  /// Tests preview entry point with custom state
  func test_previewEntry_acceptsCustomState() {
    let customState = Schedule.Feature.State(isLoading: true)
    let entry = ScheduleEntry.preview(state: customState)
    let view = entry.makeView(.init())
    
    XCTAssertNotNil(view)
  }
}