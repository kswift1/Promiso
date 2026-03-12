import ComposableArchitecture
import SwiftUI

private struct AnalyticsScreenModifier: ViewModifier {
  @Dependency(\.analyticsClient) private var analyticsClient

  let screen: AnalyticsClient.ScreenName
  let additionalParameters: [String: AnalyticsClient.ParameterValue]

  @State private var hasLogged = false

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard !hasLogged else { return }
        hasLogged = true
        analyticsClient.logScreen(screen, additionalParameters: additionalParameters)
      }
      .onDisappear {
        hasLogged = false
      }
  }
}

public extension View {
  func analyticsScreen(
    _ screen: AnalyticsClient.ScreenName,
    additionalParameters: [String: AnalyticsClient.ParameterValue] = [:]
  ) -> some View {
    modifier(
      AnalyticsScreenModifier(
        screen: screen,
        additionalParameters: additionalParameters
      )
    )
  }
}
