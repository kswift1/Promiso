// MARK: - CalendarFeatureExampleApp.swift
// Calendar Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션

import SwiftUI
import ComposableArchitecture
import CalendarFeature
import Clients

// MARK: - Example Application

@main
struct CalendarFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("Calendar Examples")
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
      Section("기본 상태") {
        NavigationLink("기본 Calendar") {
          defaultExample
        }
      }
    }
  }

  // MARK: - Example Views

  @ViewBuilder
  private var defaultExample: some View {
    let store = Store(initialState: CalendarTab.Feature.State(currentUser: mockUser)) {
      CalendarTab.Feature()
    } withDependencies: { dependencies in
      dependencies.promiseClient = .previewValue
    }

    CalendarTab.RootView(store: store)
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: CalendarTab.Feature.State(currentUser: mockUser)) {
    CalendarTab.Feature()
  } withDependencies: { dependencies in
    dependencies.promiseClient = .previewValue
  }

  CalendarTab.RootView(store: store)
}
