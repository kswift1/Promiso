// MARK: - BenefitHomeView.swift
// Screen 3: 일정 관리 - "열기만 하면, 오늘 뭐 할지 다 보여요"

import PromisoShared
import ResourceKit
import SwiftUI

struct BenefitHomeView: View {
  let onAnimationComplete: () -> Void

  @State private var showTodayHeader: Bool = false
  @State private var showRow1: Bool = false
  @State private var showRow2: Bool = false
  @State private var showRow3: Bool = false
  @State private var showNeedResponseSection: Bool = false
  @State private var showCopy: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 홈 화면 프리뷰 (스크롤 가능)
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 12) {
          // 오늘의 일정
          todayCard

          // 응답 필요
          if showNeedResponseSection {
            pendingSection
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .padding(.horizontal, 24)
      }

      Spacer()
        .frame(height: 20)

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
      if showTodayHeader {
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            Text(LocalizedStrings.Onboarding.introHomeTodayTitle)
              .font(.pmHeadline)
              .foregroundStyle(.primary)
            Spacer()
            Text(LocalizedStrings.Onboarding.introHomeItemCount(3))
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
        }
        .transition(.opacity)
      }

      // 일정 목록
      VStack(spacing: 0) {
        // 아이템 1: 점심 약속 (확정, 그룹)
        if showRow1 {
          scheduleRow(
            time: "12:00",
            emoji: "🍝",
            title: LocalizedStrings.Onboarding.introHomeTodayRow1Title,
            tag: LocalizedStrings.Onboarding.introHomeTodayRow1Tag,
            tagColor: Color.pmindigo.n500,
            isConfirmed: true,
            participantText: "3/5명 참여",
            proIcon: "cloud.rain.fill",
            proIconColor: .cyan,
            proText: "15° 비 예보 · 우산 챙기세요",
            showTransportInfo: false
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        if showRow1 && showRow2 {
          Divider()
            .padding(.leading, 52)
            .padding(.trailing, 14)
        }

        // 아이템 2: 카페 미팅 (미확정, 그룹)
        if showRow2 {
          scheduleRow(
            time: "15:00",
            emoji: "☕",
            title: "카페 미팅",
            tag: "대학 동기",
            tagColor: Color.orange,
            isConfirmed: false,
            participantText: "2/4명 참여",
            proIcon: nil,
            proIconColor: nil,
            proText: nil,
            showTransportInfo: false
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        if showRow2 && showRow3 {
          Divider()
            .padding(.leading, 52)
            .padding(.trailing, 14)
        }

        // 아이템 3: 스터디 (개인)
        if showRow3 {
          scheduleRow(
            time: "18:00",
            emoji: "📚",
            title: LocalizedStrings.Onboarding.introHomeTodayRow2Title,
            tag: LocalizedStrings.Onboarding.introHomeTodayRow2Tag,
            tagColor: Color.pmaurora.purple,
            isConfirmed: nil,
            participantText: nil,
            proIcon: nil,
            proIconColor: nil,
            proText: nil,
            showTransportInfo: true
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .padding(.bottom, showRow1 ? 6 : 0)
    }
    .adaptiveGlassCard(cornerRadius: 16)
    .opacity(showTodayHeader ? 1 : 0)
  }

  private func scheduleRow(
    time: String,
    emoji: String,
    title: String,
    tag: String,
    tagColor: Color,
    isConfirmed: Bool?,
    participantText: String?,
    proIcon: String?,
    proIconColor: Color?,
    proText: String?,
    showTransportInfo: Bool = false
  ) -> some View {
    HStack(alignment: .center, spacing: 10) {
      // 시간
      Text(time)
        .font(.pmCaption2Medium)
        .foregroundStyle(.secondary)
        .frame(width: 38, alignment: .leading)

      // 색상 바
      RoundedRectangle(cornerRadius: 1.5)
        .fill(tagColor)
        .frame(width: 3)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 4)

      // 콘텐츠
      VStack(alignment: .leading, spacing: 4) {
        // Row 1: 이모지 + 제목 + 태그 캡슐
        HStack {
          Text(emoji)
            .font(.pmSubheadline)
          Text(title)
            .font(.pmSubheadlineMedium)
            .foregroundStyle(.primary)
            .lineLimit(1)
          Spacer()
          Text(tag)
            .font(.pmCaption2)
            .foregroundStyle(tagColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tagColor.opacity(0.1), in: Capsule())
        }

        // Row 2: 확정/미확정 상태 + 참여자 (그룹만)
        if let isConfirmed {
          HStack(spacing: 4) {
            Text(isConfirmed ? "확정" : "미확정")
              .font(.pmCaption2)
              .fontWeight(.medium)
              .foregroundStyle(isConfirmed ? .green : Color.orange)
            if let participantText {
              Text("·")
                .font(.pmCaption2)
                .foregroundStyle(.secondary)
              Text(participantText)
                .font(.pmCaption2)
                .foregroundStyle(.secondary)
            }
          }
        } else {
          // 개인 일정
          Text("개인")
            .font(.pmCaption2)
            .foregroundStyle(.secondary)
        }

        // Row 3: Pro 정보
        if let proIcon, let proIconColor, let proText {
          HStack(spacing: 6) {
            ProBadge()
            Image(systemName: proIcon)
              .font(.system(size: 12))
              .foregroundStyle(proIconColor)
            Text(proText)
              .font(.pmCaption2)
              .foregroundStyle(.secondary)
          }
        }

        // Row 3: 교통수단 비교 (Pro)
        if showTransportInfo {
          HStack(spacing: 6) {
            ProBadge()
            transportChip(icon: "bus.fill", text: "25분", color: Color.pmindigo.n500)
            transportChip(icon: "car.fill", text: "15분", color: .secondary)
            Text("·")
              .font(.pmCaption2)
              .foregroundStyle(Color.pmgray.n400)
            Text("🚶 비추천")
              .font(.pmCaption2)
              .foregroundStyle(Color.pmgray.n400)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  private func transportChip(icon: String, text: String, color: Color) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon)
        .font(.system(size: 9))
      Text(text)
        .font(.pmCaption2)
    }
    .foregroundStyle(color)
  }

  // MARK: - Section 2: 응답 필요 (PendingCard 스타일)

  private var pendingSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      // 섹션 헤더
      HStack(spacing: 6) {
        Text("응답 필요")
          .font(.pmSubheadlineMedium)
          .foregroundStyle(.primary)
        Text("3")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 18, height: 18)
          .background(Circle().fill(Color.orange))
      }
      .padding(.horizontal, 4)

      // 가로 스크롤 카드
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 10) {
          pendingCard(
            dDay: "D-3",
            dDayColor: Color.pmindigo.n500,
            emoji: "🍕",
            title: "금요 회식",
            date: "3월 15일 (토) 18:00",
            groupName: "대학 동기",
            accepted: 3,
            declined: 1,
            total: 5,
            confirmThreshold: 3
          )

          pendingCard(
            dDay: "D-7",
            dDayColor: Color.pmindigo.n500,
            emoji: "🎂",
            title: "지은이 생일",
            date: "3월 20일 (목) 14:00",
            groupName: "고등학교",
            accepted: 1,
            declined: 0,
            total: 4,
            confirmThreshold: 3
          )

          pendingCard(
            dDay: "D-14",
            dDayColor: Color.pmindigo.n500,
            emoji: "🏔️",
            title: "봄 소풍",
            date: "3월 28일 (금) 10:00",
            groupName: "동호회",
            accepted: 2,
            declined: 2,
            total: 6,
            confirmThreshold: 4
          )
        }
      }
    }
  }

  private func pendingCard(
    dDay: String,
    dDayColor: Color,
    emoji: String,
    title: String,
    date: String,
    groupName: String,
    accepted: Int,
    declined: Int,
    total: Int,
    confirmThreshold: Int
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      // D-day 뱃지
      Text(dDay)
        .font(.caption2)
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(dDayColor, in: Capsule())

      // 이모지 + 제목
      HStack(spacing: 6) {
        Text(emoji)
          .font(.headline)
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      // 날짜
      HStack(spacing: 4) {
        Image(systemName: "calendar")
          .font(.system(size: 10))
        Text(date)
          .font(.caption2)
      }
      .foregroundStyle(.secondary)

      // 그룹 정보
      HStack(spacing: 4) {
        Image(systemName: "person.2.fill")
          .font(.system(size: 9))
        Text(groupName)
          .font(.caption2)
      }
      .foregroundStyle(.secondary)

      // 투표 진행도 바
      voteProgressBar(accepted: accepted, declined: declined, total: total, threshold: confirmThreshold)
    }
    .padding(10)
    .frame(width: 140)
    .background(dDayColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    .adaptiveGlassBackground(cornerRadius: 16)
  }

  private func voteProgressBar(accepted: Int, declined: Int, total: Int, threshold: Int) -> some View {
    GeometryReader { geo in
      let barWidth = geo.size.width
      let acceptedRatio = min(1.0, CGFloat(accepted) / CGFloat(max(total, 1)))
      let declinedRatio = min(1.0 - acceptedRatio, CGFloat(declined) / CGFloat(max(total, 1)))
      let confirmRatio = min(1.0, CGFloat(threshold) / CGFloat(max(total, 1)))

      ZStack(alignment: .leading) {
        // 배경
        Capsule()
          .fill(Color.gray.opacity(0.2))

        // 참여 + 거절 채움
        HStack(spacing: 0) {
          Rectangle()
            .fill(accepted >= threshold ? Color.green : Color.green.opacity(0.7))
            .frame(width: max(0, barWidth * acceptedRatio))
          Rectangle()
            .fill(Color.red.opacity(0.5))
            .frame(width: max(0, barWidth * declinedRatio))
        }
        .clipShape(Capsule())

        // 확정 기준선
        if threshold < total {
          RoundedRectangle(cornerRadius: 1)
            .fill(Color.pmindigo.n500)
            .frame(width: 2, height: 8)
            .offset(x: barWidth * confirmRatio - 1)
        }
      }
    }
    .frame(height: 4)
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 카드 프레임 + 헤더
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.easeOut(duration: 0.4)) {
      showTodayHeader = true
    }

    // 아이템 1
    try? await Task.sleep(for: .seconds(0.4))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showRow1 = true
    }

    // 아이템 2
    try? await Task.sleep(for: .seconds(0.35))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showRow2 = true
    }

    // 아이템 3
    try? await Task.sleep(for: .seconds(0.35))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
      showRow3 = true
    }

    // 응답 필요
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
      showNeedResponseSection = true
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeOut(duration: 0.5)) {
      showCopy = true
    }

    try? await Task.sleep(for: .seconds(0.4))
    onAnimationComplete()
  }
}
