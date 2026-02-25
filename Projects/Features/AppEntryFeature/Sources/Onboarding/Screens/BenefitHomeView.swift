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
          Text(LocalizedStrings.Onboarding.introHomeTitle)
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text(LocalizedStrings.Onboarding.introHomeSubtitle)
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
        Text(LocalizedStrings.Onboarding.introHomeTodayTitle)
          .font(.pmHeadline)
          .foregroundStyle(.primary)
        Spacer()
        Text(LocalizedStrings.Onboarding.introHomeItemCount(2))
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
          title: LocalizedStrings.Onboarding.introHomeTodayRow1Title,
          tag: LocalizedStrings.Onboarding.introHomeTodayRow1Tag,
          tagColor: Color.pmindigo.n500
        )

        Divider()
          .padding(.leading, 52)
          .padding(.trailing, 14)

        todayRow(
          time: "18:00",
          emoji: "📚",
          title: LocalizedStrings.Onboarding.introHomeTodayRow2Title,
          tag: LocalizedStrings.Onboarding.introHomeTodayRow2Tag,
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

      Text(LocalizedStrings.Onboarding.introHomeNeedResponseTitle)
        .font(.pmSubheadlineMedium)
        .foregroundStyle(.white)

      Spacer()

      Text(LocalizedStrings.Onboarding.introHomeItemCount(2))
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
        Text(LocalizedStrings.Onboarding.introHomeUpcomingTitle)
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
        upcomingRow(
          day: LocalizedStrings.Onboarding.introHomeUpcomingRow1Day,
          date: "12",
          emoji: "🍖",
          title: LocalizedStrings.Onboarding.introHomeUpcomingRow1Title,
          time: LocalizedStrings.Onboarding.introHomeUpcomingRow1Time
        )

        Divider()
          .padding(.leading, 52)
          .padding(.trailing, 14)

        upcomingRow(
          day: LocalizedStrings.Onboarding.introHomeUpcomingRow2Day,
          date: "14",
          emoji: "🎬",
          title: LocalizedStrings.Onboarding.introHomeUpcomingRow2Title,
          time: LocalizedStrings.Onboarding.introHomeUpcomingRow2Time
        )
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
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      showTodaySection = true
    }

    // 응답 필요 슬라이드 인
    try? await Task.sleep(for: .seconds(0.9))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      showNeedResponseSection = true
    }

    // 다가오는 약속 슬라이드 인
    try? await Task.sleep(for: .seconds(0.9))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      showUpcomingSection = true
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.9))
    withAnimation(.easeOut(duration: 0.6)) {
      showCopy = true
    }

    try? await Task.sleep(for: .seconds(0.5))
    onAnimationComplete()
  }
}
