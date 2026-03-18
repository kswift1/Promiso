// MARK: - HomeFeatureExampleApp.swift
// Home Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션

import SwiftUI
import ComposableArchitecture
import HomeFeature
import Clients

// MARK: - Example Application

@main
struct HomeFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Home Examples")
          .navigationBarTitleDisplayMode(.large)
      }
    }
  }
}

// MARK: - Content View

private struct ExampleContentView: View {

  var body: some View {
    List {
      Section("기본 상태") {
        NavigationLink("기본 Home") {
          defaultExample
        }
      }
    }
  }

  // MARK: - Example Views

  /// Default feature state example with mock user
  @ViewBuilder
  private var defaultExample: some View {
    let mockUser = UserPrivateModel(
      userId: "test-user-123",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      profile: nil,
      metadata: Metadata(createdAt: Date(), updatedAt: Date()),
      groups: []
    )

    let store = Store(initialState: Home.Feature.State(currentUser: Shared(value: mockUser))) {
      Home.Feature()
    } withDependencies: { dependencies in
      dependencies.scheduleClient = .previewValue
    }

    Home.RootView(store: store)
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let mockUser = UserPrivateModel(
    userId: "test-user-123",
    name: "테스트",
    nickname: "테스트유저",
    email: "test@example.com",
    provider: "apple",
    profile: nil,
    metadata: Metadata(createdAt: Date(), updatedAt: Date()),
    groups: []
  )

  let store = Store(initialState: Home.Feature.State(currentUser: Shared(value: mockUser))) {
    Home.Feature()
  } withDependencies: { dependencies in
    dependencies.scheduleClient = .previewValue
  }

  Home.RootView(store: store)
}
