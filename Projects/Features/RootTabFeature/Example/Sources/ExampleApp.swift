// MARK: - RootTabFeatureExampleApp.swift
// RootTab Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import RootTabFeature

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
      Section("RootTab Feature") {
        NavigationLink("RootTab with Promise") {
          defaultExample
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
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: RootTab.Feature.State()) {
    RootTab.Feature()
  }

  return RootTab.RootView(store: store)
}