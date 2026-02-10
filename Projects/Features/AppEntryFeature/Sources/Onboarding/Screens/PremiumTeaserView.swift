// MARK: - PremiumTeaserView.swift
// Screen 6: Premium Teaser - "곧 찾아올 새로운 기능"

import PromisoShared
import SwiftUI

struct PremiumTeaserView: View {
  let interestedFeatures: Set<String>
  let onToggle: (String) -> Void
  let onAnimationComplete: () -> Void

  @State private var showTitle: Bool = false
  @State private var showCards: [Bool] = [false, false, false]

  private let features: [(id: String, emoji: String, title: String, description: String)] = [
    (
      id: "recurring_promise",
      emoji: "🔄",
      title: "반복 약속",
      description: "매주 수요일 팀 회식\n자동으로 생성돼요"
    ),
    (
      id: "report",
      emoji: "📊",
      title: "약속 리포트",
      description: "이번 달 약속 12회\n가장 많이 만난 친구: 민수"
    ),
    (
      id: "premium_theme",
      emoji: "🎨",
      title: "프리미엄 테마",
      description: "나만의 약속 카드\n스타일 커스텀"
    )
  ]

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: 20)

      // 타이틀
      if showTitle {
        Text("곧 찾아올 새로운 기능")
          .font(.title2.bold())
          .foregroundStyle(Color.pmtext.primary)
          .padding(.bottom, 24)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }

      // 기능 카드들
      VStack(spacing: 14) {
        ForEach(0..<features.count, id: \.self) { index in
          if showCards[index] {
            featureCard(feature: features[index])
              .transition(.move(edge: .trailing).combined(with: .opacity))
          }
        }
      }
      .padding(.horizontal, 24)

      Spacer()
    }
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Feature Card

  private func featureCard(feature: (id: String, emoji: String, title: String, description: String)) -> some View {
    HStack(spacing: 14) {
      Text(feature.emoji)
        .font(.system(size: 32))

      VStack(alignment: .leading, spacing: 4) {
        Text(feature.title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)
        Text(feature.description)
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.secondary)
          .lineSpacing(2)
      }

      Spacer()

      // "출시되면 알려줘" 토글
      Button {
        onToggle(feature.id)
      } label: {
        let isInterested = interestedFeatures.contains(feature.id)
        HStack(spacing: 4) {
          Image(systemName: isInterested ? "bell.fill" : "bell")
            .font(.system(size: 12, weight: .medium))
          Text(isInterested ? "알림 설정됨" : "알려줘")
            .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(isInterested ? Color.white : Color.pmindigo.n500)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
          Capsule()
            .fill(isInterested ? Color.pmindigo.n500 : Color.clear)
          if !isInterested {
            Capsule()
              .strokeBorder(Color.pmindigo.n500.opacity(0.3), lineWidth: 1)
          }
        }
      }
      .buttonStyle(.plain)
    }
    .padding(16)
    .background { glassCardBackground }
  }

  @ViewBuilder
  private var glassCardBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear
        .glassEffect(
          .regular.tint(.white.opacity(0.08)),
          in: .rect(cornerRadius: 16)
        )
    } else {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 타이틀
    try? await Task.sleep(for: .seconds(0.2))
    withAnimation(.easeOut(duration: 0.4)) {
      showTitle = true
    }

    // 카드 순차 등장
    for i in 0..<features.count {
      try? await Task.sleep(for: .seconds(0.25))
      withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
        showCards[i] = true
      }
    }

    try? await Task.sleep(for: .seconds(0.3))
    onAnimationComplete()
  }
}
