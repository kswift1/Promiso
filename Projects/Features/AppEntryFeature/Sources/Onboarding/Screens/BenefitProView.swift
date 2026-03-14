// MARK: - BenefitProView.swift
// Screen 4: Pro 기능 소개

import PromisoShared
import ResourceKit
import SwiftUI

struct BenefitProView: View {
  let onAnimationComplete: () -> Void

  @State private var showBriefing: Bool = false
  @State private var showFeatures: Bool = false
  @State private var showCopy: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(spacing: 16) {
        // Pro 브리핑 카드
        if showBriefing {
          briefingCard
            .transition(.move(edge: .leading).combined(with: .opacity))
        }

        // Pro 기능 리스트
        if showFeatures {
          featureCard
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
      }
      .padding(.horizontal, 24)

      Spacer()
        .frame(height: 20)

      // 하단 카피
      if showCopy {
        VStack(spacing: 8) {
          Text("약속을 더 스마트하게")
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("Pro와 함께라면 빠짐없이 챙길 수 있어요")
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

  // MARK: - Pro 브리핑 카드

  private var briefingCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.pmSubheadline)
          .foregroundStyle(Color.pmindigo.n500)
        ProBadge()
        Text("오늘의 브리핑")
          .font(.pmSubheadlineMedium)
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()
        .padding(.horizontal, 16)

      // 브리핑 내용
      VStack(alignment: .leading, spacing: 8) {
        Text("오늘 점심 약속 전에 우산 챙기세요!\n오후 2시부터 비 예보가 있어요.")
          .font(.pmSubheadline)
          .foregroundStyle(Color.pmtext.primary)
          .lineSpacing(4)

        // 날씨 정보 row
        HStack(spacing: 8) {
          Image(systemName: "cloud.rain.fill")
            .font(.system(size: 16))
            .foregroundStyle(.cyan)
          Text("15° · 오후 비 예보")
            .font(.pmCaption)
            .foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "car.fill")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Text("12:20 출발 추천")
            .font(.pmCaption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .proGlassCard(cornerRadius: 16)
  }

  // MARK: - Pro 기능 카드

  private var featureCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack {
        ProBadge()
        Text("더 똑똑한 일정 관리")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()
        .padding(.horizontal, 16)

      // Pro 기능 리스트
      VStack(spacing: 0) {
        proFeatureRow(
          icon: "sun.max.fill",
          iconColor: .orange,
          title: "오늘의 약속 브리핑",
          subtitle: "날씨, 교통, 준비물까지 한눈에",
          isLast: false
        )
        proFeatureRow(
          icon: "exclamationmark.triangle.fill",
          iconColor: Color.pmindigo.n500,
          title: "일정 충돌 감지",
          subtitle: "겹치는 약속을 미리 알려드려요",
          isLast: false
        )
        proFeatureRow(
          icon: "car.fill",
          iconColor: .cyan,
          title: "출발 알림",
          subtitle: "교통 상황 고려한 출발 시간 안내",
          isLast: false
        )
        proFeatureRow(
          icon: "arrow.triangle.2.circlepath",
          iconColor: .green,
          title: "고정 약속 자동 생성",
          subtitle: "매주 반복되는 약속을 자동으로",
          isLast: true
        )
      }
    }
    .proGlassCard(cornerRadius: 16)
  }

  private func proFeatureRow(
    icon: String,
    iconColor: Color,
    title: String,
    subtitle: String,
    isLast: Bool
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 14))
          .foregroundStyle(iconColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pmtext.primary)
          Text(subtitle)
            .font(.pmCaption2)
            .foregroundStyle(Color.pmtext.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      if !isLast {
        Divider()
          .padding(.leading, 50)
          .padding(.trailing, 16)
      }
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 브리핑 카드
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      showBriefing = true
    }

    // 기능 카드
    try? await Task.sleep(for: .seconds(0.8))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
      showFeatures = true
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.7))
    withAnimation(.easeOut(duration: 0.6)) {
      showCopy = true
    }

    try? await Task.sleep(for: .seconds(0.5))
    onAnimationComplete()
  }
}
