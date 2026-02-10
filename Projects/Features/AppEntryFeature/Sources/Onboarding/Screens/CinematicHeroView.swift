// MARK: - CinematicHeroView.swift
// Screen 1: Cinematic Hero - 혼란 → 정리 → 관리 → 태그라인

import PromisoShared
import ResourceKit
import SwiftUI

struct CinematicHeroView: View {
  let onAnimationComplete: () -> Void

  @State private var phase: AnimationPhase = .initial
  @State private var cardSet: CardSet = .random()

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
        (CardInfo(emoji: "🎬", title: "대학 동기 모임", detail: "영화 보고 저녁!", location: "CGV 강남"), "4/4"),
        (CardInfo(emoji: "🍖", title: "회식", detail: "분기 마무리 회식", location: "강남 고깃집"), "5/5"),
        (CardInfo(emoji: "⚽️", title: "풋살 모임", detail: "이번 주 매치", location: "잠실 풋살장"), "6/6"),
        (CardInfo(emoji: "🎤", title: "노래방 번개", detail: "스트레스 해소!", location: "홍대 코인노래방"), "3/3"),
        (CardInfo(emoji: "🍻", title: "금요 치맥", detail: "한 주 고생했다", location: "을지로 호프집"), "4/4"),
      ]
      let upcomingOptions: [(info: CardInfo, time: String)] = [
        (CardInfo(emoji: "🎂", title: "엄마 생신 저녁", detail: "선물 준비 완료", location: "한정식집"), "내일 오후 6시"),
        (CardInfo(emoji: "☕️", title: "카페 스터디", detail: "중간고사 대비", location: "스타벅스 역삼점"), "토요일 오전 10시"),
        (CardInfo(emoji: "🏔️", title: "등산 모임", detail: "북한산 코스", location: "북한산 입구"), "일요일 오전 7시"),
        (CardInfo(emoji: "🎾", title: "테니스 레슨", detail: "초급반 3회차", location: "올림픽공원"), "수요일 오후 7시"),
        (CardInfo(emoji: "🍜", title: "점심 약속", detail: "오랜만에 만남", location: "광화문 맛집"), "오늘 낮 12시"),
      ]
      let personalOptions: [(info: CardInfo, time: String)] = [
        (CardInfo(emoji: "📚", title: "토익 시험", detail: "목표 900점", location: "서울대 시험장"), "오후 2시"),
        (CardInfo(emoji: "💇", title: "미용실 예약", detail: "커트 + 염색", location: "헤어살롱"), "오후 3시"),
        (CardInfo(emoji: "🏥", title: "건강검진", detail: "연례 종합검진", location: "서울병원"), "오전 9시"),
        (CardInfo(emoji: "🦷", title: "치과 예약", detail: "스케일링", location: "연세치과"), "오후 4시"),
        (CardInfo(emoji: "🏋️", title: "PT 수업", detail: "하체 운동 Day", location: "피트니스센터"), "오후 7시"),
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
            .transition(.opacity)
        }

        if phase >= .organizing {
          organizedCardsView
            .transition(.scale(scale: 0.9).combined(with: .opacity))
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
    VStack(spacing: 10) {
      // 1. 전원 확정 약속
      promiseCard(
        info: cardSet.confirmed.info,
        groupName: "대학 동기",
        participantCount: cardSet.confirmed.count,
        badge: .confirmed
      )
      // 2. 확정 대기 약속
      promiseCard(
        info: CardInfo(emoji: "🍟", title: "감튀 파티", detail: "케첩 필수 지참", location: "맥도날드"),
        groupName: "감튀 그룹",
        participantCount: "3/4",
        badge: .pending("1명 남음")
      )
      // 3. 예정 약속
      promiseCard(
        info: cardSet.upcoming.info,
        groupName: nil,
        participantCount: nil,
        badge: .time(cardSet.upcoming.time)
      )
      // 4. 개인 일정
      personalEventCard(
        info: cardSet.personal.info,
        time: cardSet.personal.time
      )
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
                Text("· \(participantCount)명")
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
        Text("확정")
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

      Text("개인")
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

    // Scene 2: 정리 시작 (버블을 충분히 보여준 뒤)
    try? await Task.sleep(for: .seconds(2.0))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      phase = .organizing
    }

    // Scene 3: 정리 완료
    try? await Task.sleep(for: .seconds(0.6))
    withAnimation(.easeInOut(duration: 0.5)) {
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
