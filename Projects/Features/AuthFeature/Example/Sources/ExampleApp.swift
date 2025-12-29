// MARK: - AuthFeatureExampleApp.swift
// Auth Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import AuthFeature
import Clients

// MARK: - Example Application

/// Auth Feature를 위한 독립 실행형 example 앱
/// 다양한 테스트 시나리오와 함께 격리된 개발 환경을 제공
@main
struct AuthFeatureExampleApp: App {
  
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Auth Examples")
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
      Section("기본 상태") {
        NavigationLink("기본 Auth") {
          defaultExample
        }
      }
    }
  }
  
  // MARK: - Example Views
  
  /// Default feature state example
  @ViewBuilder
  private var defaultExample: some View {
    let store = Store(initialState: Auth.Feature.State()) {
      Auth.Feature()
    } withDependencies: { dependencies in
      dependencies.authClient = .previewValue
    }
    
    Auth.RootView(store: store)
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: Auth.Feature.State()) {
    Auth.Feature()
  } withDependencies: { dependencies in
    dependencies.authClient = .previewValue
  }
  
  Auth.RootView(store: store)
}
