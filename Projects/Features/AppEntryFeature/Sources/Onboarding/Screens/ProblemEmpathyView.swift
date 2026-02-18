// MARK: - ProblemEmpathyView.swift
// Screen 2: 문제 공감 - "약속 하나 잡는 데 카톡 47개"

import PromisoShared
import SwiftUI

struct ProblemEmpathyView: View {
  let onAnimationComplete: () -> Void

  @State private var count: Int = 0
  @State private var showPainPoints: [Bool] = [false, false, false]
  @State private var showBottomCopy: Bool = false

  private let targetCount = 47

  private var painPoints: [(emoji: String, text: String)] {
    [
      ("😩", LocalizedStrings.Onboarding.introProblemPainPoint1),
      ("😶", LocalizedStrings.Onboarding.introProblemPainPoint2),
      ("🤔", LocalizedStrings.Onboarding.introProblemPainPoint3)
    ]
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 카운트업 숫자
      VStack(spacing: 4) {
        Text("\(count)")
          .font(.system(size: 72, weight: .black, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n600],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .contentTransition(.numericText(value: Double(count)))

        Text(LocalizedStrings.Onboarding.introProblemCountLabel)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(Color.pmtext.secondary)
      }
      .padding(.bottom, 32)

      // 고충 리스트
      VStack(alignment: .leading, spacing: 16) {
        ForEach(0..<painPoints.count, id: \.self) { index in
          HStack(spacing: 12) {
            Text(painPoints[index].emoji)
              .font(.system(size: 24))
            Text(painPoints[index].text)
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
          }
          .opacity(showPainPoints[index] ? 1 : 0)
          .offset(x: showPainPoints[index] ? 0 : -20)
        }
      }
      .padding(.horizontal, 32)
      .padding(.bottom, 40)

      // 하단 공감 카피
      if showBottomCopy {
        VStack(spacing: 6) {
          Text(LocalizedStrings.Onboarding.introProblemBottomLine1)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text(LocalizedStrings.Onboarding.introProblemBottomLine2)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 카운트업 (0 → 47, 약 1.0초)
    try? await Task.sleep(for: .seconds(0.5))
    let steps = 20
    let interval = 1.0 / Double(steps)
    for i in 1...steps {
      try? await Task.sleep(for: .seconds(interval))
      let progress = Double(i) / Double(steps)
      let eased = progress * progress // ease-in
      withAnimation(.none) {
        count = Int(Double(targetCount) * eased)
      }
    }
    withAnimation(.spring(response: 0.5)) {
      count = targetCount
    }

    // 고충 순차 등장
    try? await Task.sleep(for: .seconds(0.6))
    for i in 0..<painPoints.count {
      try? await Task.sleep(for: .seconds(0.6))
      withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
        showPainPoints[i] = true
      }
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.7))
    withAnimation(.easeOut(duration: 0.6)) {
      showBottomCopy = true
    }

    try? await Task.sleep(for: .seconds(0.5))
    onAnimationComplete()
  }
}
