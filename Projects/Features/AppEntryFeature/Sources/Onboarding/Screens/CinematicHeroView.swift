// MARK: - CinematicHeroView.swift
// Screen 1: Cinematic Hero - 혼란 → 정리 → 관리 → 태그라인

import PromisoShared
import ResourceKit
import SwiftUI

struct CinematicHeroView: View {
  let onAnimationComplete: () -> Void

  @State private var phase: AnimationPhase = .initial
  @State private var cardSet: CardSet = .random()
  @State private var visibleBubbles: Int = 0
  @State private var bubblesCollapsing: Bool = false
  @State private var visibleCards: Int = 0

  private struct CardInfo {
    let emoji: String
    let title: String
    let detail: String
    let location: String?
  }

  private struct CardSet {
    let confirmed: (info: CardInfo, count: String)
    let upcoming: (info: CardInfo, time: String)
    let personal: (info: CardInfo, time: String)

    static func random() -> CardSet {
      let confirmedOptions: [(info: CardInfo, count: String)] = [
        (
          CardInfo(
            emoji: "🎬",
            title: LocalizedStrings.Onboarding.introHeroConfirmedTitle(1),
            detail: LocalizedStrings.Onboarding.introHeroConfirmedDetail(1),
            location: LocalizedStrings.Onboarding.introHeroConfirmedLocation(1)
          ),
          "4/4"
        ),
        (
          CardInfo(
            emoji: "🍖",
            title: LocalizedStrings.Onboarding.introHeroConfirmedTitle(2),
            detail: LocalizedStrings.Onboarding.introHeroConfirmedDetail(2),
            location: LocalizedStrings.Onboarding.introHeroConfirmedLocation(2)
          ),
          "5/5"
        ),
        (
          CardInfo(
            emoji: "⚽️",
            title: LocalizedStrings.Onboarding.introHeroConfirmedTitle(3),
            detail: LocalizedStrings.Onboarding.introHeroConfirmedDetail(3),
            location: LocalizedStrings.Onboarding.introHeroConfirmedLocation(3)
          ),
          "6/6"
        ),
        (
          CardInfo(
            emoji: "🎤",
            title: LocalizedStrings.Onboarding.introHeroConfirmedTitle(4),
            detail: LocalizedStrings.Onboarding.introHeroConfirmedDetail(4),
            location: LocalizedStrings.Onboarding.introHeroConfirmedLocation(4)
          ),
          "3/3"
        ),
        (
          CardInfo(
            emoji: "🍻",
            title: LocalizedStrings.Onboarding.introHeroConfirmedTitle(5),
            detail: LocalizedStrings.Onboarding.introHeroConfirmedDetail(5),
            location: LocalizedStrings.Onboarding.introHeroConfirmedLocation(5)
          ),
          "4/4"
        ),
      ]
      let upcomingOptions: [(info: CardInfo, time: String)] = [
        (
          CardInfo(
            emoji: "🎂",
            title: LocalizedStrings.Onboarding.introHeroUpcomingTitle(1),
            detail: LocalizedStrings.Onboarding.introHeroUpcomingDetail(1),
            location: LocalizedStrings.Onboarding.introHeroUpcomingLocation(1)
          ),
          LocalizedStrings.Onboarding.introHeroUpcomingTime(1)
        ),
        (
          CardInfo(
            emoji: "☕️",
            title: LocalizedStrings.Onboarding.introHeroUpcomingTitle(2),
            detail: LocalizedStrings.Onboarding.introHeroUpcomingDetail(2),
            location: LocalizedStrings.Onboarding.introHeroUpcomingLocation(2)
          ),
          LocalizedStrings.Onboarding.introHeroUpcomingTime(2)
        ),
        (
          CardInfo(
            emoji: "🏔️",
            title: LocalizedStrings.Onboarding.introHeroUpcomingTitle(3),
            detail: LocalizedStrings.Onboarding.introHeroUpcomingDetail(3),
            location: LocalizedStrings.Onboarding.introHeroUpcomingLocation(3)
          ),
          LocalizedStrings.Onboarding.introHeroUpcomingTime(3)
        ),
        (
          CardInfo(
            emoji: "🎾",
            title: LocalizedStrings.Onboarding.introHeroUpcomingTitle(4),
            detail: LocalizedStrings.Onboarding.introHeroUpcomingDetail(4),
            location: LocalizedStrings.Onboarding.introHeroUpcomingLocation(4)
          ),
          LocalizedStrings.Onboarding.introHeroUpcomingTime(4)
        ),
        (
          CardInfo(
            emoji: "🍜",
            title: LocalizedStrings.Onboarding.introHeroUpcomingTitle(5),
            detail: LocalizedStrings.Onboarding.introHeroUpcomingDetail(5),
            location: LocalizedStrings.Onboarding.introHeroUpcomingLocation(5)
          ),
          LocalizedStrings.Onboarding.introHeroUpcomingTime(5)
        ),
      ]
      let personalOptions: [(info: CardInfo, time: String)] = [
        (
          CardInfo(
            emoji: "📚",
            title: LocalizedStrings.Onboarding.introHeroPersonalTitle(1),
            detail: LocalizedStrings.Onboarding.introHeroPersonalDetail(1),
            location: LocalizedStrings.Onboarding.introHeroPersonalLocation(1)
          ),
          LocalizedStrings.Onboarding.introHeroPersonalTime(1)
        ),
        (
          CardInfo(
            emoji: "💇",
            title: LocalizedStrings.Onboarding.introHeroPersonalTitle(2),
            detail: LocalizedStrings.Onboarding.introHeroPersonalDetail(2),
            location: LocalizedStrings.Onboarding.introHeroPersonalLocation(2)
          ),
          LocalizedStrings.Onboarding.introHeroPersonalTime(2)
        ),
        (
          CardInfo(
            emoji: "🏥",
            title: LocalizedStrings.Onboarding.introHeroPersonalTitle(3),
            detail: LocalizedStrings.Onboarding.introHeroPersonalDetail(3),
            location: LocalizedStrings.Onboarding.introHeroPersonalLocation(3)
          ),
          LocalizedStrings.Onboarding.introHeroPersonalTime(3)
        ),
        (
          CardInfo(
            emoji: "🦷",
            title: LocalizedStrings.Onboarding.introHeroPersonalTitle(4),
            detail: LocalizedStrings.Onboarding.introHeroPersonalDetail(4),
            location: LocalizedStrings.Onboarding.introHeroPersonalLocation(4)
          ),
          LocalizedStrings.Onboarding.introHeroPersonalTime(4)
        ),
        (
          CardInfo(
            emoji: "🏋️",
            title: LocalizedStrings.Onboarding.introHeroPersonalTitle(5),
            detail: LocalizedStrings.Onboarding.introHeroPersonalDetail(5),
            location: LocalizedStrings.Onboarding.introHeroPersonalLocation(5)
          ),
          LocalizedStrings.Onboarding.introHeroPersonalTime(5)
        ),
      ]

      return CardSet(
        confirmed: confirmedOptions.randomElement()!,
        upcoming: upcomingOptions.randomElement()!,
        personal: personalOptions.randomElement()!
      )
    }
  }

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
            .scaleEffect(bubblesCollapsing ? 0.15 : 1.0)
            .blur(radius: bubblesCollapsing ? 8 : 0)
            .opacity(bubblesCollapsing ? 0 : 1)
            .transition(.opacity)
        }

        if phase >= .organizing {
          organizedCardsView
            .transition(.opacity)
        }
      }
      .frame(maxHeight: .infinity)
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
        text: LocalizedStrings.Onboarding.introHeroBubble1,
        alignment: .leading,
        rotation: -3,
        visible: visibleBubbles >= 1
      )
      messageBubble(
        text: LocalizedStrings.Onboarding.introHeroBubble2,
        alignment: .trailing,
        rotation: 2,
        visible: visibleBubbles >= 2
      )
      messageBubble(
        text: LocalizedStrings.Onboarding.introHeroBubble3,
        alignment: .leading,
        rotation: -1,
        visible: visibleBubbles >= 3
      )
      messageBubble(
        text: LocalizedStrings.Onboarding.introHeroBubble4,
        alignment: .trailing,
        rotation: 1.5,
        visible: visibleBubbles >= 4
      )
    }
  }

  private func messageBubble(
    text: String,
    alignment: HorizontalAlignment,
    rotation: Double,
    visible: Bool
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
          .spring(response: 0.5, dampingFraction: 0.8),
          value: visible
        )
      if alignment == .leading { Spacer() }
    }
  }

  // MARK: - Scene 2-3: 정리된 카드

  private var organizedCardsView: some View {
    VStack(spacing: 10) {
      // 1. 전원 확정 약속
      promiseCard(
        info: cardSet.confirmed.info,
        groupName: LocalizedStrings.Onboarding.introHeroGroupClassmates,
        participantCount: cardSet.confirmed.count,
        badge: .confirmed
      )
      .cascadeIn(visible: visibleCards >= 1)

      // 2. 확정 대기 약속
      promiseCard(
        info: CardInfo(
          emoji: "🍟",
          title: LocalizedStrings.Onboarding.introHeroFriesTitle,
          detail: LocalizedStrings.Onboarding.introHeroFriesDetail,
          location: LocalizedStrings.Onboarding.introHeroFriesLocation
        ),
        groupName: LocalizedStrings.Onboarding.introHeroGroupFries,
        participantCount: "3/4",
        badge: .pending(LocalizedStrings.Onboarding.introHeroPendingOneLeft)
      )
      .cascadeIn(visible: visibleCards >= 2)

      // 3. 예정 약속
      promiseCard(
        info: cardSet.upcoming.info,
        groupName: nil,
        participantCount: nil,
        badge: .time(cardSet.upcoming.time)
      )
      .cascadeIn(visible: visibleCards >= 3)

      // 4. 개인 일정
      personalEventCard(
        info: cardSet.personal.info,
        time: cardSet.personal.time
      )
      .cascadeIn(visible: visibleCards >= 4)
    }
  }

  private enum CardBadge {
    case confirmed
    case pending(String)
    case time(String)
  }

  private func promiseCard(
    info: CardInfo,
    groupName: String?,
    participantCount: String?,
    badge: CardBadge
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(info.emoji)
        .font(.system(size: 28))

      VStack(alignment: .leading, spacing: 3) {
        Text(info.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)

        Text(info.detail)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .lineLimit(1)

        HStack(spacing: 10) {
          if let location = info.location {
            HStack(spacing: 3) {
              Image(systemName: "mappin")
                .font(.system(size: 9))
              Text(location)
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          }

          if let groupName {
            HStack(spacing: 3) {
              Image(systemName: "person.2.fill")
                .font(.system(size: 9))
              Text(groupName)
              if let participantCount {
                Text(LocalizedStrings.Onboarding.introHeroGroupParticipantCount(participantCount))
              }
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }

      Spacer()

      badgeView(badge)
    }
    .padding(12)
    .adaptiveGlassCard(cornerRadius: 14)
  }

  @ViewBuilder
  private func badgeView(_ badge: CardBadge) -> some View {
    switch badge {
    case .confirmed:
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 12))
        Text(LocalizedStrings.Onboarding.introHeroConfirmedBadge)
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundStyle(Color.green)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background {
        Capsule().fill(Color.green.opacity(0.12))
      }

    case .pending(let text):
      HStack(spacing: 4) {
        Image(systemName: "clock.fill")
          .font(.system(size: 11))
        Text(text)
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundStyle(Color.orange)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background {
        Capsule().fill(Color.orange.opacity(0.12))
      }

    case .time(let time):
      Text(time)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.pmindigo.n500)
    }
  }

  private func personalEventCard(
    info: CardInfo,
    time: String
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(info.emoji)
        .font(.system(size: 28))

      VStack(alignment: .leading, spacing: 3) {
        Text(info.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)

        Text(info.detail)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .lineLimit(1)

        HStack(spacing: 10) {
          HStack(spacing: 3) {
            Image(systemName: "clock")
              .font(.system(size: 9))
            Text(time)
          }
          .font(.system(size: 11))
          .foregroundStyle(Color.pmtext.secondary)

          if let location = info.location {
            HStack(spacing: 3) {
              Image(systemName: "mappin")
                .font(.system(size: 9))
              Text(location)
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }

      Spacer()

      Text(LocalizedStrings.Onboarding.introHeroPersonalBadge)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.pmaurora.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
          Capsule().fill(Color.pmaurora.purple.opacity(0.12))
        }
    }
    .padding(12)
    .adaptiveGlassCard(cornerRadius: 14)
  }

  // MARK: - Scene 4: 태그라인

  private var taglineView: some View {
    VStack(spacing: 8) {
      Text(LocalizedStrings.Onboarding.introHeroTaglineLine1)
        .font(.title2.bold())
        .foregroundStyle(Color.pmtext.primary)
      Text(LocalizedStrings.Onboarding.introHeroTaglineLine2)
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
    // Scene 1: 메시지 버블 하나씩 등장
    try? await Task.sleep(for: .seconds(0.5))
    phase = .messagesVisible

    for i in 1...4 {
      try? await Task.sleep(for: .seconds(0.7))
      withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        visibleBubbles = i
      }
    }

    // Scene 2: 버블 중앙으로 축소
    try? await Task.sleep(for: .seconds(1.4))
    withAnimation(.easeIn(duration: 0.7)) {
      bubblesCollapsing = true
    }

    // 축소 완료 후 카드 뷰로 전환
    try? await Task.sleep(for: .seconds(0.7))
    phase = .organizing

    // Scene 3: 카드 하나씩 캐스케이드 등장
    for i in 1...4 {
      try? await Task.sleep(for: .seconds(0.45))
      visibleCards = i
    }

    // 정리 완료
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeInOut(duration: 0.5)) {
      phase = .organized
    }

    // Scene 4: 태그라인
    try? await Task.sleep(for: .seconds(1.0))
    withAnimation(.easeOut(duration: 0.7)) {
      phase = .tagline
    }

    // 애니메이션 완료
    try? await Task.sleep(for: .seconds(0.6))
    onAnimationComplete()
  }
}

// MARK: - Cascade Modifier

private struct CascadeModifier: ViewModifier {
  let visible: Bool

  func body(content: Content) -> some View {
    content
      .opacity(visible ? 1 : 0)
      .offset(y: visible ? 0 : -30)
      .scaleEffect(visible ? 1 : 0.85)
      .animation(
        .spring(response: 0.45, dampingFraction: 0.75),
        value: visible
      )
  }
}

private extension View {
  func cascadeIn(visible: Bool) -> some View {
    modifier(CascadeModifier(visible: visible))
  }
}
