// MARK: - ScheduleEntry+Live.swift
// Schedule Feature entry point의 Live implementation
// 이 파일은 Interface layer와 구체적인 Implementation layer를 연결

import SwiftUI
import ComposableArchitecture
import ScheduleFeatureInterface

// MARK: - Live Implementation

public extension ScheduleEntry {
  
  /// Schedule Feature entry의 live instance를 생성
  /// 메인 애플리케이션에서 사용해야 하는 production implementation
  /// 
  /// Live implementation:
  /// - 기본 initial state로 TCA store를 생성
  /// - production dependency로 reducer를 구성
  /// - 적절히 구성된 SwiftUI view를 반환
  /// 
  /// - Returns: production 사용을 위해 구성된 ScheduleEntry
  static func live() -> Self {
    .init { config in
      // initial state로 TCA store 생성
      let store = Store(
        initialState: Schedule.Feature.State()
      ) {
        Schedule.Feature()
          // Feature가 성장함에 따라 dependency를 여기에 추가
          // 예시: ._printChanges() for debugging
      }
      
      // AnyView로 감싼 root view 반환
      return AnyView(
        Schedule.RootView(store: store)
      )
    }
  }
  
  /// SwiftUI preview와 testing을 위한 preview instance를 생성함
  /// 이 버전은 mock data와 간소화된 configuration을 사용함
  /// 
  /// - Parameter state: preview 시나리오를 위한 선택적 initial state
  /// - Returns: preview 사용을 위해 구성된 ScheduleEntry
  static func preview(
    state: Schedule.Feature.State = .init()
  ) -> Self {
    .init { _ in
      let store = Store(initialState: state) {
        Schedule.Feature()
          ._printChanges()
      }
      
      return AnyView(
        Schedule.RootView(store: store)
      )
    }
  }
  
  /// unit testing을 위한 mock instance를 생성함
  /// 특정 시나리오 테스트를 위한 커스텀 store injection을 허용함
  /// 
  /// - Parameter store: testing을 위해 미리 구성된 store
  /// - Returns: testing을 위해 구성된 ScheduleEntry
  static func mock(
    store: StoreOf<Schedule.Feature>
  ) -> Self {
    .init { _ in
      AnyView(
        Schedule.RootView(store: store)
      )
    }
  }
}