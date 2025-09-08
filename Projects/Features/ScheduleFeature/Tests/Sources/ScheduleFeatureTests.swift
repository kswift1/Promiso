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
  
  /// 기본 onAppear 동작을 테스트
  func test_onAppear() async {
    let store = TestStore(initialState: Schedule.Feature.State()) {
      Schedule.Feature()
    }
    
    await store.send(.onAppear)
  }
  
  // 추가 테스트를 여기에 작성
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
}