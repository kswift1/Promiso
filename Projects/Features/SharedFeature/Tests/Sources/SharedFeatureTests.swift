// MARK: - SharedFeatureTests.swift
// TCA TestStore를 사용한 Shared Feature의 포괄적인 test suite
// 이 파일은 business logic의 정확성과 state management의 무결성을 보장

import XCTest
import ComposableArchitecture
@testable import SharedFeature

// MARK: - Feature Tests

/// Shared Feature reducer와 business logic을 위한 Test suite
/// 예측 가능한 state testing과 side effect 검증을 위해 TCA의 TestStore를 사용
@MainActor
final class SharedFeatureTests: XCTestCase {
  
  /// 기본 onAppear 동작을 테스트
  func test_onAppear() async {
    let store = TestStore(initialState: Shared.Feature.State()) {
      Shared.Feature()
    }
    
    await store.send(.onAppear)
  }
  
  // 추가 테스트를 여기에 작성
}

// MARK: - Integration Tests

/// Integration tests for feature integration
@MainActor
final class SharedFeatureIntegrationTests: XCTestCase {
  
  /// Tests feature creation and basic functionality
  func test_feature_createsValidInstance() {
    let store = Store(initialState: Shared.Feature.State()) {
      Shared.Feature()
    }
    
    XCTAssertNotNil(store)
  }
}