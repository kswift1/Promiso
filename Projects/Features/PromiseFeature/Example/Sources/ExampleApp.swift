// MARK: - PromiseFeatureExampleApp.swift
// Promise Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import PromiseFeature

// MARK: - Example Application

/// Promise Feature를 위한 독립 실행형 example 앱
/// 다양한 테스트 시나리오와 함께 격리된 개발 환경을 제공
@main
struct PromiseFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Promise Examples")
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
      Section("약속 메인") {
        NavigationLink("PromiseMain Feature") {
          promiseMainExample
        }
      }

      Section("약속 생성") {
        NavigationLink("CreatePromise Feature") {
          createPromiseExample
        }
      }
    }
  }

  // MARK: - Example Views

  /// PromiseMain feature example with preview data
  @ViewBuilder
  private var promiseMainExample: some View {
    let store = Store(initialState: PromiseMain.Feature.State.preview) {
      PromiseMain.Feature()
    }

    PromiseMain.RootView(store: store)
  }

  /// CreatePromise feature example
  @ViewBuilder
  private var createPromiseExample: some View {
    let store = Store(initialState: CreatePromise.Feature.State()) {
      CreatePromise.Feature()
    }

    CreatePromise.RootView(store: store)
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: PromiseMain.Feature.State.preview) {
    PromiseMain.Feature()
  }

  PromiseMain.RootView(store: store)
}