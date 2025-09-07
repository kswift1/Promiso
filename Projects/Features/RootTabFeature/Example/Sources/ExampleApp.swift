// MARK: - RootTabFeatureExampleApp.swift
// RootTab Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import RootTabFeatureImplement
import RootTabFeatureInterface

// MARK: - Example Application

/// RootTab Feature를 위한 독립 실행형 example 앱
/// 다양한 테스트 시나리오와 함께 격리된 개발 환경을 제공
@main
struct RootTabFeatureExampleApp: App {
  
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("RootTab Examples")
          .navigationBarTitleDisplayMode(.large)
      }
    }
  }
}

// MARK: - Content View

/// 다양한 Feature 시나리오를 보여주는 Main content view
private struct ExampleContentView: View {
  
  var body: some View {
    List {
      // Default State Section
      Section("기본 상태") {
        NavigationLink("기본 RootTab") {
          defaultExample
        }
      }
      
      // Loading State Section
      Section("로딩 상태") {
        NavigationLink("로딩 상태") {
          loadingExample
        }
      }
      
      // Error State Section
      Section("에러 상태") {
        NavigationLink("네트워크 에러") {
          errorExample(RootTabError.networkError)
        }
        
        NavigationLink("데이터 에러") {
          errorExample(RootTabError.dataError)
        }
        
        NavigationLink("커스텀 에러") {
          errorExample(RootTabError.custom("문제가 발생했습니다!"))
        }
      }
      
      // Entry Point Section
      Section("Entry Point Integration") {
        NavigationLink("Live Entry") {
          entryExample
        }
      }
    }
  }
  
  // MARK: - Example Views
  
  /// Default feature state example
  @ViewBuilder
  private var defaultExample: some View {
    let store = Store(initialState: RootTab.Feature.State()) {
      RootTab.Feature()
        ._printChanges()
    }
    
    RootTab.RootView(store: store)
  }
  
  /// Loading state example
  @ViewBuilder
  private var loadingExample: some View {
    let store = Store(
      initialState: RootTab.Feature.State(isLoading: true)
    ) {
      RootTab.Feature()
        ._printChanges()
    }
    
    RootTab.RootView(store: store)
  }
  
  /// Error state example
  /// - Parameter error: The error to display
  @ViewBuilder
  private func errorExample(_ error: RootTabError) -> some View {
    let store = Store(
      initialState: RootTab.Feature.State(error: error)
    ) {
      RootTab.Feature()
        ._printChanges()
    }
    
    RootTab.RootView(store: store)
  }
  
  /// Entry point integration example
  @ViewBuilder
  private var entryExample: some View {
    let entry = RootTabEntry.live()
    entry.makeView(.init())
  }
}

// MARK: - SwiftUI Previews

/// SwiftUI previews for different feature states
#Preview("Default State") {
  let store = Store(initialState: RootTab.Feature.State()) {
    RootTab.Feature()
  }
  
  return NavigationStack {
    RootTab.RootView(store: store)
  }
}

#Preview("Loading State") {
  let store = Store(
    initialState: RootTab.Feature.State(isLoading: true)
  ) {
    RootTab.Feature()
  }
  
  return NavigationStack {
    RootTab.RootView(store: store)
  }
}

#Preview("Error State") {
  let store = Store(
    initialState: RootTab.Feature.State(error: .networkError)
  ) {
    RootTab.Feature()
  }
  
  return NavigationStack {
    RootTab.RootView(store: store)
  }
}

#Preview("Entry Point") {
  let entry = RootTabEntry.preview()
  return entry.makeView(.init())
}