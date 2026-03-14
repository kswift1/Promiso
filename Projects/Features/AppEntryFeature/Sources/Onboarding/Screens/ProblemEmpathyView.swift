// MARK: - ProblemEmpathyView.swift
// Screen 2: 문제 공감 - 타임라인 단편화

import PromisoShared
import SwiftUI

struct ProblemEmpathyView: View {
  let onAnimationComplete: () -> Void

  @State private var showTopCopy: Bool = false
  @State private var count: Int = 0
  @State private var showCards: [Bool] = [false, false, false]
  @State private var showDividers: Bool = false
  @State private var showBottomCopy: Bool = false

  private let cards: [(emoji: String, appName: String, content: String)] = [
    ("💬", "카카오톡", "토요일 고기 ㄱ?"),
    ("📝", "메모", "강남역 6시"),
    ("📅", "캘린더", "3/15 저녁")
  ]

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 상단 카피: "약속 하나에 앱 N개"
      HStack(alignment: .center, spacing: 6) {
        Text("약속 하나에 앱")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(Color.pmtext.secondary)

        Text("\(count)")
          .font(.system(size: 40, weight: .black, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n600],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .contentTransition(.numericText(value: Double(count)))
          .animation(.spring(response: 0.4), value: count)

        Text("개")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(Color.pmtext.secondary)
      }
      .opacity(showTopCopy ? 1 : 0)
      .animation(.easeOut(duration: 0.5), value: showTopCopy)
      .padding(.bottom, 28)

      // 타임라인 카드 3개
      VStack(spacing: 0) {
        ForEach(0..<cards.count, id: \.self) { index in
          VStack(spacing: 0) {
            TimelineCardView(
              emoji: cards[index].emoji,
              appName: cards[index].appName,
              content: cards[index].content
            )
            .opacity(showCards[index] ? 1 : 0)
            .offset(x: showCards[index] ? 0 : -24)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showCards[index])

            if index < cards.count - 1 {
              DashedDividerView()
                .opacity(showDividers ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: showDividers)
            }
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 36)

      // 하단 카피
      VStack(spacing: 4) {
        Text("같은 약속인데")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Text("이렇게 흩어져 있어요")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(Color.pmtext.secondary)
      }
      .multilineTextAlignment(.center)
      .opacity(showBottomCopy ? 1 : 0)
      .animation(.easeOut(duration: 0.5), value: showBottomCopy)

      Spacer()
    }
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 0.5s 상단 카피 fade-in
    try? await Task.sleep(for: .seconds(0.5))
    showTopCopy = true

    // 0.8s 카운트 1 + 카드 1
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation { count = 1 }
    showCards[0] = true

    // 1.2s 카운트 2 + 카드 2
    try? await Task.sleep(for: .seconds(0.4))
    withAnimation { count = 2 }
    showCards[1] = true

    // 1.6s 카운트 3 + 카드 3
    try? await Task.sleep(for: .seconds(0.4))
    withAnimation { count = 3 }
    showCards[2] = true

    // 1.9s 점선 끊김 표시
    try? await Task.sleep(for: .seconds(0.3))
    showDividers = true

    // 2.4s 하단 카피 fade-in
    try? await Task.sleep(for: .seconds(0.5))
    showBottomCopy = true

    // 2.9s onAnimationComplete
    try? await Task.sleep(for: .seconds(0.5))
    onAnimationComplete()
  }
}

// MARK: - TimelineCardView

private struct TimelineCardView: View {
  let emoji: String
  let appName: String
  let content: String

  var body: some View {
    HStack(spacing: 12) {
      Text(emoji)
        .font(.system(size: 22))

      VStack(alignment: .leading, spacing: 2) {
        Text(appName)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.pmtext.secondary)

        Text(content)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.pmtext.primary)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .adaptiveGlassCard(cornerRadius: 14)
  }
}

// MARK: - DashedDividerView

private struct DashedDividerView: View {
  var body: some View {
    Path { path in
      path.move(to: CGPoint(x: 20, y: 0))
      path.addLine(to: CGPoint(x: 20, y: 16))
    }
    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
    .foregroundStyle(Color.pmtext.secondary.opacity(0.3))
    .frame(width: 40, height: 16)
  }
}
