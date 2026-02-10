// MARK: - CinematicHeroView.swift
// Screen 1: Cinematic Hero - 혼란 → 정리 → 관리 → 태그라인

import PromisoShared
import ResourceKit
import SwiftUI

struct CinematicHeroView: View {
  let onAnimationComplete: () -> Void

  @State private var phase: AnimationPhase = .initial

  enum AnimationPhase: Int, Comparable {
    case initial = 0
    case messagesVisible = 1
    case organizing = 2
    case organized = 3
    case tagline = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 메시지 / 카드 영역
      ZStack {
        if phase < .organizing {
          messagesView
            .transition(.opacity)
        }

        if phase >= .organizing {
          organizedCardsView
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }
      .frame(height: 280)
      .padding(.horizontal, 24)

      Spacer()
        .frame(height: 40)

      // 태그라인
      if phase >= .tagline {
        taglineView
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Scene 1: 흩어진 메시지 버블

  private var messagesView: some View {
    VStack(spacing: 16) {
      messageBubble(
        text: "토요일 되는 사람? 🙋",
        alignment: .leading,
        rotation: -3,
        visible: phase >= .messagesVisible
      )
      messageBubble(
        text: "나 7시 이후만 돼",
        alignment: .trailing,
        rotation: 2,
        visible: phase >= .messagesVisible,
        delay: 0.15
      )
      messageBubble(
        text: "읽씹...",
        alignment: .leading,
        rotation: -1,
        visible: phase >= .messagesVisible,
        delay: 0.3
      )
      messageBubble(
        text: "결국 어떻게 된거야?",
        alignment: .trailing,
        rotation: 1.5,
        visible: phase >= .messagesVisible,
        delay: 0.45
      )
    }
  }

  private func messageBubble(
    text: String,
    alignment: HorizontalAlignment,
    rotation: Double,
    visible: Bool,
    delay: Double = 0
  ) -> some View {
    HStack {
      if alignment == .trailing { Spacer() }
      Text(text)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.pmtext.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
          glassCardBackground(cornerRadius: 16)
        }
        .rotationEffect(.degrees(rotation))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 20)
        .animation(
          .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
          value: visible
        )
      if alignment == .leading { Spacer() }
    }
  }

  // MARK: - Scene 2-3: 정리된 카드

  private var organizedCardsView: some View {
    VStack(spacing: 12) {
      promiseCard(
        emoji: "🎬",
        title: "대학 동기 모임",
        status: "4/4 전원 확정",
        confirmed: true
      )
      promiseCard(
        emoji: "🎂",
        title: "엄마 생신 저녁",
        status: "내일 오후 6시",
        confirmed: false
      )
    }
  }

  private func promiseCard(
    emoji: String,
    title: String,
    status: String,
    confirmed: Bool
  ) -> some View {
    HStack(spacing: 12) {
      Text(emoji)
        .font(.system(size: 28))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Text(status)
          .font(.system(size: 13))
          .foregroundStyle(confirmed ? Color.green : Color.pmtext.secondary)
      }

      Spacer()

      if confirmed {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.green)
      }
    }
    .padding(16)
    .background { glassCardBackground(cornerRadius: 16) }
  }

  // MARK: - Scene 4: 태그라인

  private var taglineView: some View {
    VStack(spacing: 8) {
      Text("흩어진 약속,")
        .font(.title2.bold())
        .foregroundStyle(Color.pmtext.primary)
      Text("이제 Promiso가 챙길게요")
        .font(.title2.bold())
        .foregroundStyle(
          LinearGradient(
            colors: [Color.pmindigo.n600, Color.pmpurple.n600],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 24)
  }

  // MARK: - Glass Card Background

  @ViewBuilder
  private func glassCardBackground(cornerRadius: CGFloat) -> some View {
    if #available(iOS 26.0, *) {
      Color.clear
        .glassEffect(
          .regular.tint(.white.opacity(0.08)),
          in: .rect(cornerRadius: cornerRadius)
        )
    } else {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // Scene 1: 메시지 버블 등장
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.easeOut(duration: 0.5)) {
      phase = .messagesVisible
    }

    // Scene 2: 정리 시작
    try? await Task.sleep(for: .seconds(1.2))
    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
      phase = .organizing
    }

    // Scene 3: 정리 완료
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.easeInOut(duration: 0.4)) {
      phase = .organized
    }

    // Scene 4: 태그라인
    try? await Task.sleep(for: .seconds(0.8))
    withAnimation(.easeOut(duration: 0.5)) {
      phase = .tagline
    }

    // 애니메이션 완료
    try? await Task.sleep(for: .seconds(0.4))
    onAnimationComplete()
  }
}
