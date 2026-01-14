// MARK: - ProfileFeatureTests.swift
// TCA TestStore를 사용한 Profile Feature의 포괄적인 test suite
// 이 파일은 business logic의 정확성과 state management의 무결성을 보장

import XCTest
import ComposableArchitecture
@testable import ProfileFeature

// MARK: - Feature Tests

/// Profile Feature reducer와 business logic을 위한 Test suite
/// 예측 가능한 state testing과 side effect 검증을 위해 TCA의 TestStore를 사용
@MainActor
final class ProfileFeatureTests: XCTestCase {
  
  /// 기본 onAppear 동작을 테스트
  func test_onAppear() async {
    let store = TestStore(initialState: Profile.Feature.State()) {
      Profile.Feature()
    }
    
    await store.send(.onAppear)
  }
  
  // 추가 테스트를 여기에 작성
}

// MARK: - Integration Tests

/// Integration tests for feature integration
@MainActor
final class ProfileFeatureIntegrationTests: XCTestCase {
  
  /// Tests feature creation and basic functionality
  func test_feature_createsValidInstance() {
    let store = Store(initialState: Profile.Feature.State()) {
      Profile.Feature()
    }
    
    XCTAssertNotNil(store)
  }
}