// MARK: - RootTabEntry+Live.swift
// RootTab Feature entry point의 Live implementation
// 이 파일은 Interface layer와 구체적인 Implementation layer를 연결

import SwiftUI
import ComposableArchitecture
import RootTabFeatureInterface

// MARK: - Live Implementation

public extension RootTabEntry {
  
  /// RootTab Feature entry의 live instance를 생성
  /// 메인 애플리케이션에서 사용해야 하는 production implementation
  /// 
  /// Live implementation:
  /// - 기본 initial state로 TCA store를 생성
  /// - production dependency로 reducer를 구성
  /// - 적절히 구성된 SwiftUI view를 반환
  /// 
  /// - Returns: production 사용을 위해 구성된 RootTabEntry
  static func live() -> Self {
    .init { config in
      // initial state로 TCA store 생성
      let store = Store(
        initialState: RootTab.Feature.State()
      ) {
        RootTab.Feature()
          // Feature가 성장함에 따라 dependency를 여기에 추가
          // 예시: ._printChanges() for debugging
      }
      
      // 주의: 이 메서드는 App에서 직접 RootView를 생성하므로 사용되지 않습니다
      // placeholder로만 유지
      fatalError("RootTabEntry.live()는 사용되지 않습니다. App에서 직접 RootView를 생성하세요.")
    }
  }
  
  /// SwiftUI preview와 testing을 위한 preview instance를 생성함
  /// 이 버전은 mock data와 간소화된 configuration을 사용함
  /// 
  /// - Parameter state: preview 시나리오를 위한 선택적 initial state
  /// - Returns: preview 사용을 위해 구성된 RootTabEntry
  static func preview(
    state: RootTab.Feature.State = .init()
  ) -> Self {
    .init { _ in
      let store = Store(initialState: state) {
        RootTab.Feature()
          ._printChanges()
      }
      
      // Preview에서도 App 방식과 동일하게 처리
      fatalError("RootTabEntry.preview()는 사용되지 않습니다. App에서 직접 RootView를 생성하세요.")
    }
  }
  
  /// unit testing을 위한 mock instance를 생성함
  /// 특정 시나리오 테스트를 위한 커스텀 store injection을 허용함
  /// 
  /// - Parameter store: testing을 위해 미리 구성된 store
  /// - Returns: testing을 위해 구성된 RootTabEntry
  static func mock(
    store: StoreOf<RootTab.Feature>
  ) -> Self {
    .init { _ in
      // Mock에서도 App 방식과 동일하게 처리
      fatalError("RootTabEntry.mock()는 사용되지 않습니다. App에서 직접 RootView를 생성하세요.")
    }
  }
}