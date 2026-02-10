// MARK: - BenefitHomeView.swift
// Screen 4: Benefit 2 - "비서처럼 관리하는 홈"

import PromisoShared
import SwiftUI

struct BenefitHomeView: View {
  let onAnimationComplete: () -> Void

  @State private var showTodayCards: [Bool] = [false, false]
  @State private var showWeekSection: Bool = false
  @State private var showCopy: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 홈 화면 미니어처
      VStack(alignment: .leading, spacing: 0) {
        // 오늘의 약속 섹션
        sectionHeader("오늘의 약속")
          .padding(.bottom, 12)

        VStack(spacing: 10) {
          if showTodayCards[0] {
            scheduleCard(
              time: "12:00",
              emoji: "🍝",
              title: "점심 약속",
              detail: "회사 동료 3명 · 강남역 2번 출구",
              isGroup: true
            )
            .transition(.move(edge: .top).combined(with: .opacity))
          }

          if showTodayCards[1] {
            scheduleCard(
              time: "18:00",
              emoji: "🎂",
              title: "엄마 생신",
              detail: "가족 모임 · 한정식 예담",
              isGroup: false
            )
            .transition(.move(edge: .top).combined(with: .opacity))
          }
        }

        // 이번 주 섹션
        if showWeekSection {
          sectionHeader("이번 주")
            .padding(.top, 20)
            .padding(.bottom, 8)

          VStack(alignment: .leading, spacing: 8) {
            weekItem(day: "수", title: "팀 회식")
            weekItem(day: "금", title: "대학 동기 모임")
          }
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .padding(20)
      .background { glassCardBackground }
      .padding(.horizontal, 24)

      Spacer()
        .frame(height: 32)

      // 하단 카피
      if showCopy {
        VStack(spacing: 8) {
          Text("\"오늘 뭐 있었지?\"")
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("이제 안 물어봐도 돼요")
            .font(.subheadline)
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

  // MARK: - Components

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Color.pmtext.secondary)
  }

  private func scheduleCard(
    time: String,
    emoji: String,
    title: String,
    detail: String,
    isGroup: Bool
  ) -> some View {
    HStack(spacing: 12) {
      // 시간
      Text(time)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(Color.pmtext.secondary)
        .frame(width: 42, alignment: .leading)

      // 구분선
      RoundedRectangle(cornerRadius: 1.5)
        .fill(isGroup ? Color.pmindigo.n500 : Color.pmaurora.purple)
        .frame(width: 3, height: 40)

      // 내용
      HStack(spacing: 8) {
        Text(emoji)
          .font(.system(size: 22))
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }

      Spacer()
    }
  }

  private func weekItem(day: String, title: String) -> some View {
    HStack(spacing: 8) {
      Text("📅")
        .font(.system(size: 14))
      Text(day)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.pmindigo.n500)
      Text("- \(title)")
        .font(.system(size: 13))
        .foregroundStyle(Color.pmtext.secondary)
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
    // 오늘의 약속 카드 순차 등장
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showTodayCards[0] = true
    }

    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showTodayCards[1] = true
    }

    // 이번 주 섹션
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeOut(duration: 0.4)) {
      showWeekSection = true
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
