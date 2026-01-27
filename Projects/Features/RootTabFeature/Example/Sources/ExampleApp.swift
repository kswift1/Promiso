// MARK: - RootTabFeatureExampleApp.swift
// RootTab Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션

import SwiftUI
import ComposableArchitecture
import RootTabFeature
import Clients

// MARK: - Example Application

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

// MARK: - Mock User

private let mockUser = UserPrivateModel(
  userId: "test-user-123",
  name: "테스트",
  nickname: "테스트유저",
  email: "test@example.com",
  provider: "apple",
  profile: nil,
  metadata: Metadata(createdAt: Date(), updatedAt: Date()),
  groups: []
)

// MARK: - Content View

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

  @ViewBuilder
  private var defaultExample: some View {
    let store = Store(initialState: RootTab.Feature.State(currentUser: Shared(value: mockUser))) {
      RootTab.Feature()
        ._printChanges()
    } withDependencies: { dependencies in
      dependencies.authClient = .previewValue
      dependencies.userProfileClient = .previewValue
      dependencies.groupClient = .previewValue
      dependencies.promiseClient = .previewValue
    }

    RootTab.RootView(store: store)
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: RootTab.Feature.State(currentUser: Shared(value: mockUser))) {
    RootTab.Feature()
  } withDependencies: { dependencies in
    dependencies.authClient = .previewValue
    dependencies.userProfileClient = .previewValue
    dependencies.groupClient = .previewValue
    dependencies.promiseClient = .previewValue
  }

  RootTab.RootView(store: store)
}
