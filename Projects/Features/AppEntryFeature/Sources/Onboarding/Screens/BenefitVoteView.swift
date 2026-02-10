// MARK: - BenefitVoteView.swift
// Screen 3: Benefit 1 - "모두가 진짜 OK한 약속만"

import PromisoShared
import SwiftUI

struct BenefitVoteView: View {
  let onAnimationComplete: () -> Void

  @State private var showCard: Bool = false
  @State private var confirmedMembers: Set<Int> = []
  @State private var lastMemberConfirmed: Bool = false
  @State private var showCelebration: Bool = false
  @State private var showCopy: Bool = false

  private let members: [(name: String, index: Int)] = [
    ("민수", 0), ("지훈", 1), ("수진", 2), ("예은", 3)
  ]

  var body: some View {
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
          Text("모두가 OK한 약속만")
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("다시는 \"나 그 약속 몰랐는데?\" 가 없도록")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .padding(.horizontal, 24)
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Vote Card

  private var voteCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack(spacing: 10) {
        Text("🍕")
          .font(.system(size: 28))
        VStack(alignment: .leading, spacing: 2) {
          Text("대학 동기 모임")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)
          Text("\(confirmedMembers.count)/4 응답 완료")
            .font(.system(size: 13))
            .foregroundStyle(Color.pmtext.secondary)
            .contentTransition(.numericText(value: Double(confirmedMembers.count)))
        }
      }
      .padding(.bottom, 16)

      // 멤버 리스트
      VStack(spacing: 10) {
        ForEach(members, id: \.index) { member in
          memberRow(name: member.name, index: member.index)
        }
      }

      // 전원 확정 배너
      if showCelebration {
        HStack {
          Spacer()
          Text("전원 확정! 🎉")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.green)
          Spacer()
        }
        .padding(.top, 16)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(20)
    .background { glassCardBackground }
  }

  private func memberRow(name: String, index: Int) -> some View {
    HStack {
      Text(name)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.pmtext.primary)

      Spacer()

      if confirmedMembers.contains(index) {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.green)
          Text("확정")
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

    // 3명 순차 확정
    try? await Task.sleep(for: .seconds(0.5))
    for i in 0..<3 {
      try? await Task.sleep(for: .seconds(0.25))
      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
        confirmedMembers.insert(i)
      }
    }

    // 예은 대기 (긴장감)
    try? await Task.sleep(for: .seconds(0.8))

    // 예은 확정
    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
      confirmedMembers.insert(3)
      lastMemberConfirmed = true
    }

    // 전원 확정 축하
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
      showCelebration = true
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeOut(duration: 0.4)) {
      showCopy = true
    }

    try? await Task.sleep(for: .seconds(0.3))
    onAnimationComplete()
  }
}
