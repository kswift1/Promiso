import SwiftUI

/// 원형 투표 현황 프로그레스 뷰
struct CircularProgressView: View {
  let current: Int
  let total: Int
  var size: CGFloat = 32
  var lineWidth: CGFloat = 3

  private var progress: Double {
    guard total > 0 else { return 0 }
    return Double(current) / Double(total)
  }

  var body: some View {
    ZStack {
      // Background circle
      Circle()
        .stroke(Color(.systemGray5), lineWidth: lineWidth)

      // Progress circle
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          progressColor,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.spring(response: 0.4), value: progress)

      // Text
      Text("\(current)/\(total)")
        .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
    }
    .frame(width: size, height: size)
  }

  private var progressColor: Color {
    if progress >= 1.0 {
      return .green
    } else if progress >= 0.5 {
      return Color.pmindigo.n500
    } else {
      return .orange
    }
  }
}

/// 점 스타일 투표 현황 뷰 (가로 나열)
struct VoteDotsView: View {
  let accepted: Int
  let declined: Int
  let pending: Int
  var dotSize: CGFloat = 6
  var maxDots: Int = 5

  private var totalVisible: Int {
    min(accepted + declined + pending, maxDots)
  }

  var body: some View {
    HStack(spacing: 3) {
      // Accepted dots (green)
      ForEach(0..<min(accepted, maxDots), id: \.self) { _ in
        Circle()
          .fill(Color.green)
          .frame(width: dotSize, height: dotSize)
      }

      // Declined dots (red)
      ForEach(0..<min(declined, max(0, maxDots - accepted)), id: \.self) { _ in
        Circle()
          .fill(Color.red)
          .frame(width: dotSize, height: dotSize)
      }

      // Pending dots (gray)
      ForEach(0..<min(pending, max(0, maxDots - accepted - declined)), id: \.self) { _ in
        Circle()
          .fill(Color(.systemGray4))
          .frame(width: dotSize, height: dotSize)
      }

      // Overflow indicator
      let overflow = (accepted + declined + pending) - maxDots
      if overflow > 0 {
        Text("+\(overflow)")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Preview

#Preview("Circular Progress") {
  VStack(spacing: 20) {
    HStack(spacing: 20) {
      CircularProgressView(current: 3, total: 5)
      CircularProgressView(current: 4, total: 5)
      CircularProgressView(current: 5, total: 5)
    }

    HStack(spacing: 20) {
      CircularProgressView(current: 1, total: 5)
      CircularProgressView(current: 0, total: 5)
      CircularProgressView(current: 2, total: 3)
    }

    // Large size
    CircularProgressView(current: 7, total: 10, size: 60, lineWidth: 5)
  }
  .padding()
  .auroraBackground()
}

#Preview("Vote Dots") {
  VStack(spacing: 16) {
    VoteDotsView(accepted: 3, declined: 1, pending: 2)
    VoteDotsView(accepted: 5, declined: 0, pending: 0)
    VoteDotsView(accepted: 2, declined: 2, pending: 4)
    VoteDotsView(accepted: 6, declined: 2, pending: 3)  // overflow
  }
  .padding()
  .auroraBackground()
}
