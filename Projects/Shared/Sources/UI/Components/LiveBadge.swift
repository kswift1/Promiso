import Lottie
import ResourceKit
import SwiftUI

/// 실시간 공유 중 뱃지 (Lottie 애니메이션 + 텍스트)
public struct LiveBadge: View {
  @Environment(\.colorScheme) private var colorScheme

  private let showText: Bool

  public init(showText: Bool = true) {
    self.showText = showText
  }

  public var body: some View {
    HStack(spacing: 3) {
      LottieView(animation: LottieAsset.live.animation)
        .playing(loopMode: .loop)
        .frame(width: 14, height: 10)

      if showText {
        Text(LocalizedStrings.Common.live)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(textColor)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(backgroundColor, in: Capsule())
  }

  private var textColor: Color {
    colorScheme == .dark ? Color.pmindigo.n200 : Color.pmindigo.n600
  }

  private var backgroundColor: Color {
    colorScheme == .dark
      ? Color.pmindigo.n800.opacity(0.6)
      : Color.pmindigo.n100.opacity(0.8)
  }
}

#Preview("Light") {
  VStack(spacing: 20) {
    LiveBadge()
    LiveBadge(showText: false)
  }
  .padding()
  .background(Color.white)
}

#Preview("Dark") {
  VStack(spacing: 20) {
    LiveBadge()
    LiveBadge(showText: false)
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
