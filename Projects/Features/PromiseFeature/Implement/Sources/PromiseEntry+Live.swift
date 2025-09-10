// MARK: - PromiseEntry+Live.swift
// Promise Feature entry point의 Live implementation
// 이 파일은 Interface layer와 구체적인 Implementation layer를 연결

import SwiftUI
import ComposableArchitecture
import PromiseFeatureInterface

// MARK: - Live Implementation

public extension PromiseEntry {
  
  /// Promise Feature entry의 live instance를 생성
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Promise.Feature.State()) {
        Promise.Feature()
      }
      
      Promise.RootView(store: store)
    }
  }
  
  /// SwiftUI preview를 위한 preview instance를 생성
  static func preview() -> Self {
    .init { _ in
      let store = Store(initialState: Promise.Feature.State()) {
        Promise.Feature()
      }
      
      Promise.RootView(store: store)
    }
  }
}