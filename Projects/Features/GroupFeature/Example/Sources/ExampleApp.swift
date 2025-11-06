// MARK: - GroupFeatureExampleApp.swift
// Group Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import GroupFeature

// MARK: - Example Application

/// Group Feature를 위한 독립 실행형 example 앱
/// 다양한 테스트 시나리오와 함께 격리된 개발 환경을 제공
@main
struct GroupFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Group Examples")
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
        NavigationLink("GroupMain Feature") {
          groupMainExample
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

  /// GroupMain feature example with preview data
  @ViewBuilder
  private var groupMainExample: some View {
    let store = Store(initialState: GroupMain.Feature.State.preview) {
      GroupMain.Feature()
    }

    GroupMain.RootView(store: store)
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
  let store = Store(initialState: GroupMain.Feature.State.preview) {
    GroupMain.Feature()
  }

  GroupMain.RootView(store: store)
}