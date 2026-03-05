import SwiftUI
import ResourceKit

/// PRO 플랜 뱃지
public struct ProBadge: View {
  public init() {}

  public var body: some View {
    Text("PRO")
      .font(.system(size: 9, weight: .heavy))
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
      )
  }
}

#Preview {
  ProBadge()
    .padding()
}
