import SwiftUI

extension View {
  func shimmer() -> some View {
    modifier(ShimmerModifier())
  }
}

struct ShimmerModifier: ViewModifier {
  @State private var phase: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(
        LinearGradient(
          gradient: Gradient(colors: [
            .clear,
            Color.white.opacity(0.3),
            .clear
          ]),
          startPoint: .leading,
          endPoint: .trailing
        )
        .offset(x: phase)
        .mask(content)
      )
      .onAppear {
        withAnimation(
          .linear(duration: 1.5)
          .repeatForever(autoreverses: false)
        ) {
          phase = 300
        }
      }
  }
}
