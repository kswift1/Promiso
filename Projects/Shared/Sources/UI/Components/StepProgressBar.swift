import SwiftUI
import ResourceKit

// MARK: - Step Progress Bar

/// 단계별 진행바 (ProgressHeader에서 분리된 순수 진행바 컴포넌트)
public struct StepProgressBar: View {
  let currentStep: Int
  let totalSteps: Int

  public init(currentStep: Int, totalSteps: Int) {
    self.currentStep = currentStep
    self.totalSteps = totalSteps
  }

  public var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<totalSteps, id: \.self) { step in
        StepProgressSegment(isActive: step <= currentStep)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }
}

// MARK: - Step Progress Segment

private struct StepProgressSegment: View {
  let isActive: Bool

  private let animationDuration: TimeInterval = 0.5

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color(.systemGray5))
        Rectangle()
          .fill(Color.pmpurple.n500)
          .frame(width: isActive ? geometry.size.width : 0)
          .animation(.easeInOut(duration: animationDuration), value: isActive)
      }
    }
    .frame(height: 4)
    .clipShape(Capsule())
  }
}

// MARK: - Previews

#Preview("1/3 단계") {
  VStack(spacing: 16) {
    Text("Step 1 of 3")
      .font(.headline)
    StepProgressBar(currentStep: 0, totalSteps: 3)
  }
  .padding()
}

#Preview("2/3 단계") {
  VStack(spacing: 16) {
    Text("Step 2 of 3")
      .font(.headline)
    StepProgressBar(currentStep: 1, totalSteps: 3)
  }
  .padding()
}

#Preview("완료 (3/3)") {
  VStack(spacing: 16) {
    Text("Step 3 of 3")
      .font(.headline)
    StepProgressBar(currentStep: 2, totalSteps: 3)
  }
  .padding()
}

#Preview("4단계 진행") {
  VStack(spacing: 20) {
    ForEach(0..<4) { step in
      VStack(spacing: 4) {
        Text("Step \(step + 1) of 4")
          .font(.caption)
          .foregroundStyle(.secondary)
        StepProgressBar(currentStep: step, totalSteps: 4)
      }
    }
  }
  .padding()
}
