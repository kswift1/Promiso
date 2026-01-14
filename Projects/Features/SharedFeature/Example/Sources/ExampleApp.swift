// MARK: - SharedFeatureExampleApp.swift
// Shared Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션

import SwiftUI

// MARK: - Example Application

@main
struct SharedFeatureExampleApp: App {

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        Text("SharedFeature Example")
          .navigationTitle("Shared Examples")
          .navigationBarTitleDisplayMode(.large)
      }
    }
  }
}
