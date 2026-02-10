// MARK: - BenefitVoteView.swift
// Screen 3: Benefit 1 - "인원 모이면, 알아서 확정"

import PromisoShared
import ResourceKit
import SwiftUI

struct BenefitVoteView: View {
  let onAnimationComplete: () -> Void

  @State private var showCard: Bool = false
  @State private var confirmedMembers: Set<Int> = []
  @State private var showConfirmed: Bool = false
  @State private var showNotification: Bool = false
  @State private var showCopy: Bool = false

  private let members: [(emoji: String, name: String, index: Int)] = [
    ("🧑‍💻", "민수", 0), ("😎", "지훈", 1), ("🙋‍♀️", "재윤", 2), ("🎧", "예은", 3)
  ]

  private let minimumRequired = 3

  var body: some View {
    ZStack(alignment: .top) {
      // 메인 콘텐츠
      VStack(spacing: 0) {
        Spacer()

        // 약속 카드
        if showCard {
          voteCard
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }

        Spacer()
          .frame(height: 32)

        // 하단 카피
        if showCopy {
          VStack(spacing: 8) {
            Text("인원 모이면, 알아서 확정")
              .font(.title3.bold())
              .foregroundStyle(Color.pmtext.primary)
            Text("수락만 누르세요. 나머지는 Promiso가 할게요.")
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
          }
          .multilineTextAlignment(.center)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        Spacer()
      }
      .padding(.horizontal, 24)

      // 푸시 알림 배너 (상단 오버레이)
      if showNotification {
        notificationBanner
          .transition(.move(edge: .top).combined(with: .opacity))
          .padding(.horizontal, 16)
          .padding(.top, 8)
      }
    }
    .onAppear {
      Task {
        await runAnimationSequence()
      }
    }
  }

  // MARK: - Vote Card

  private var voteCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack(spacing: 10) {
        Text("🎓")
          .font(.system(size: 28))
        VStack(alignment: .leading, spacing: 2) {
          Text("대학 동기 모임")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)
          Text("\(confirmedMembers.count)/4 수락")
            .font(.system(size: 13))
            .foregroundStyle(Color.pmtext.secondary)
            .contentTransition(.numericText(value: Double(confirmedMembers.count)))
        }

        Spacer()

        // 최소 인원 표시
        Text("최소 \(minimumRequired)명")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background {
            Capsule().fill(Color.pmindigo.n500.opacity(0.12))
          }
      }
      .padding(.bottom, 16)

      // 멤버 리스트
      VStack(spacing: 10) {
        ForEach(members, id: \.index) { member in
          memberRow(emoji: member.emoji, name: member.name, index: member.index)
        }
      }

      // 자동 확정 배너
      if showConfirmed {
        HStack(spacing: 6) {
          Spacer()
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 14))
          Text("자동 확정!")
            .font(.system(size: 15, weight: .bold))
          Spacer()
        }
        .foregroundStyle(Color.green)
        .padding(.top, 16)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(20)
    .background { glassCardBackground }
  }

  private func memberRow(emoji: String, name: String, index: Int) -> some View {
    HStack(spacing: 8) {
      Text(emoji)
        .font(.system(size: 20))
      Text(name)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.pmtext.primary)

      Spacer()

      if confirmedMembers.contains(index) {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.green)
          Text("수락")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.green)
        }
        .transition(.scale.combined(with: .opacity))
      } else {
        HStack(spacing: 4) {
          Image(systemName: "clock")
            .foregroundStyle(Color.pmtext.secondary)
          Text("대기중")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }
  }

  // MARK: - Push Notification Banner

  private var notificationBanner: some View {
    HStack(spacing: 12) {
      // 앱 아이콘
      ResourceKitAsset.notificationLogo.swiftUIImage
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text("Promiso")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Spacer()
          Text("지금")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary)
        }
        Text("🎓 대학 동기 모임 약속 확정! 🎉")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)
        Text("내일 오후 6:00에 만나요!")
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.secondary)
          .lineLimit(1)
      }
    }
    .padding(14)
    .background {
      if #available(iOS 26.0, *) {
        Color.clear
          .glassEffect(
            .regular.tint(.white.opacity(0.3)),
            in: .rect(cornerRadius: 16)
          )
      } else {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
      }
    }
  }

  // MARK: - Glass Card Background

  @ViewBuilder
  private var glassCardBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear
        .glassEffect(
          .regular.tint(.white.opacity(0.08)),
          in: .rect(cornerRadius: 20)
        )
    } else {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 카드 등장
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showCard = true
    }

    // 민수, 지훈 순차 수락
    try? await Task.sleep(for: .seconds(0.5))
    for i in 0..<2 {
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
        confirmedMembers.insert(i)
      }
    }

    // 수진 수락 (3번째 = 최소 인원 충족!)
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
      confirmedMembers.insert(2)
    }

    // 자동 확정 배너
    try? await Task.sleep(for: .seconds(0.4))
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
      showConfirmed = true
    }

    // 푸시 알림 슬라이드 다운
    try? await Task.sleep(for: .seconds(0.6))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      showNotification = true
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.8))
    withAnimation(.easeOut(duration: 0.4)) {
      showCopy = true
    }

    // 예은은 대기중 상태로 남아있음 (전원 아니어도 확정됨을 보여줌)

    try? await Task.sleep(for: .seconds(0.3))
    onAnimationComplete()
  }
}
