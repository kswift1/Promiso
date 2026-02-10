// MARK: - BenefitHomeView.swift
// Screen 4: Benefit 2 - "열기만 하면, 오늘 뭐 할지 다 보여요"

import PromisoShared
import ResourceKit
import SwiftUI

struct BenefitHomeView: View {
  let onAnimationComplete: () -> Void

  @State private var showTodaySection: Bool = false
  @State private var showNeedResponseSection: Bool = false
  @State private var showUpcomingSection: Bool = false
  @State private var showCopy: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 홈 화면 프리뷰
      VStack(spacing: 10) {
        if showTodaySection {
          todayCard
            .transition(.move(edge: .leading).combined(with: .opacity))
        }

        if showNeedResponseSection {
          needResponseBanner
            .transition(.move(edge: .leading).combined(with: .opacity))
        }

        if showUpcomingSection {
          upcomingCard
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
      }
      .padding(.horizontal, 24)

      Spacer()
        .frame(height: 28)

      // 하단 카피
      if showCopy {
        VStack(spacing: 8) {
          Text("열기만 하면, 오늘 뭐 할지 다 보여요")
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("개인 약속, 그룹 약속, 응답할 것까지\nPromiso가 알아서 챙겨요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .onAppear {
      Task {
        await runAnimationSequence()
      }
    }
  }

  // MARK: - Section 1: 오늘의 일정

  private var todayCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack {
        Text("오늘의 일정")
          .font(.pmHeadline)
          .foregroundStyle(.primary)
        Spacer()
        Text("2개")
          .font(.pmCaption)
          .foregroundStyle(Color.pmindigo.n500)
        Image(systemName: "chevron.down")
          .font(.pmCaption)
          .foregroundStyle(Color.pmgray.n400)
      }
      .padding(.horizontal, 14)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()
        .padding(.horizontal, 14)

      // 일정 목록
      VStack(spacing: 0) {
        todayRow(
          time: "12:00",
          emoji: "🍝",
          title: "점심 약속",
          tag: "회사 동료",
          tagColor: Color.pmindigo.n500
        )

        Divider()
          .padding(.leading, 52)
          .padding(.trailing, 14)

        todayRow(
          time: "18:00",
          emoji: "🎂",
          title: "엄마 생신 저녁",
          tag: "개인",
          tagColor: Color.pmaurora.purple
        )
      }
      .padding(.bottom, 6)
    }
    .adaptiveGlassCard(cornerRadius: 16)
  }

  private func todayRow(
    time: String,
    emoji: String,
    title: String,
    tag: String,
    tagColor: Color
  ) -> some View {
    HStack(spacing: 10) {
      Text(time)
        .font(.pmCaption2Medium)
        .foregroundStyle(.secondary)
        .frame(width: 38, alignment: .leading)

      RoundedRectangle(cornerRadius: 1.5)
        .fill(tagColor)
        .frame(width: 3, height: 32)

      Text(emoji)
        .font(.pmSubheadline)

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.pmSubheadlineMedium)
          .foregroundStyle(.primary)
          .lineLimit(1)
        Text(tag)
          .font(.pmCaption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  // MARK: - Section 2: 응답 필요

  private var needResponseBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "envelope.badge.fill")
        .font(.pmBody)
        .foregroundStyle(.white)

      Text("응답이 필요해요")
        .font(.pmSubheadlineMedium)
        .foregroundStyle(.white)

      Spacer()

      Text("2개")
        .font(.pmCaption)
        .foregroundStyle(.white.opacity(0.85))

      Image(systemName: "chevron.right")
        .font(.pmCaption)
        .foregroundStyle(.white.opacity(0.7))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      LinearGradient(
        colors: [Color.orange, Color.orange.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Section 3: 다가오는 약속

  private var upcomingCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack {
        Text("다가오는 약속")
          .font(.pmHeadline)
          .foregroundStyle(.primary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()
        .padding(.horizontal, 14)

      // 일정 목록
      VStack(spacing: 0) {
        upcomingRow(day: "수", date: "12", emoji: "🍖", title: "팀 회식", time: "오후 7시")

        Divider()
          .padding(.leading, 52)
          .padding(.trailing, 14)

        upcomingRow(day: "금", date: "14", emoji: "🎬", title: "영화 관람", time: "오후 6시")
      }
      .padding(.bottom, 6)
    }
    .adaptiveGlassCard(cornerRadius: 16)
  }

  private func upcomingRow(
    day: String,
    date: String,
    emoji: String,
    title: String,
    time: String
  ) -> some View {
    HStack(spacing: 10) {
      // 요일 + 날짜
      VStack(spacing: 0) {
        Text(day)
          .font(.pmCaption2)
          .foregroundStyle(.secondary)
        Text(date)
          .font(.pmSubheadlineSemibold)
          .foregroundStyle(Color.pmindigo.n500)
      }
      .frame(width: 28)

      Text(emoji)
        .font(.pmSubheadline)

      Text(title)
        .font(.pmSubheadlineMedium)
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer(minLength: 0)

      Text(time)
        .font(.pmCaption)
        .foregroundStyle(.secondary)

      Image(systemName: "chevron.right")
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 오늘의 일정 등장
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showTodaySection = true
    }

    // 응답 필요 슬라이드 인
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showNeedResponseSection = true
    }

    // 다가오는 약속 슬라이드 인
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showUpcomingSection = true
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
