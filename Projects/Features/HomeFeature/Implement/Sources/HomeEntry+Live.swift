// MARK: - HomeEntry+Live.swift
// Home Feature entry point의 Live implementation
// 이 파일은 Interface layer와 구체적인 Implementation layer를 연결

import SwiftUI
import ComposableArchitecture
import HomeFeatureInterface

// MARK: - Live Implementation

public extension HomeEntry {
  
  /// Home Feature entry의 live instance를 생성
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: Home.Feature.State()) {
        Home.Feature()
      }
      
      return AnyView(
        Home.RootView(store: store)
      )
    }
  }
  
  /// SwiftUI preview를 위한 preview instance를 생성
  static func preview() -> Self {
    .init { _ in
      let store = Store(initialState: Home.Feature.State()) {
        Home.Feature()
      }
      
      return AnyView(
        Home.RootView(store: store)
      )
    }
  }
}