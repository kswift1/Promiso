//
//  PaywallView.swift
//  ProPlanFeature
//
//  Created by Claude on 2026-02-24.
//

import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit
import SharedFeature
import SwiftUI

// MARK: - Paywall View

extension ProPlan {

  public struct PaywallView: View {
    @Bindable private var store: StoreOf<Feature>

    @State private var isPricingExpanded = false
    @State private var hasAutoExpanded = false

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ZStack {
        ScrollView {
          VStack(spacing: 32) {
            heroSection
            featureCardsSection
            comparisonSection
            legalSection

            // 스크롤 끝 감지용
            GeometryReader { geo in
              Color.clear
                .onChange(of: geo.frame(in: .global).minY) { _, minY in
                  let screenHeight = UIScreen.main.bounds.height
                  if minY < screenHeight - 100, !isPricingExpanded, !hasAutoExpanded {
                    hasAutoExpanded = true
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                      isPricingExpanded = true
                    }
                  }
                }
            }
            .frame(height: 1)
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, isPricingExpanded ? 420 : 180)
        }
        .scrollIndicators(.hidden)
        .auroraBackground()

        ctaBottomBar
          .frame(maxHeight: .infinity, alignment: .bottom)

        if store.isPurchasing {
          loadingOverlay
        }
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.hidden)
      .presentationCornerRadius(24)
      .interactiveDismissDisabled(store.isPurchasing)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
      VStack(spacing: 16) {
        // 커피 아이콘
        Text("☕️")
          .font(.system(size: 48))

        VStack(spacing: 6) {
          Text("월 커피 한 잔 가격으로")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)

          // "AI 비서" 그라데이션 강조
          Text("AI 비서를 고용하세요")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
        }
        .multilineTextAlignment(.center)

        Text("이동시간, 겹치는 일정, 날씨까지\nPromiso Pro가 대신 챙겨드려요")
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
      .padding(.top, 16)
    }

    // MARK: - Feature Cards

    @ViewBuilder
    private var featureCardsSection: some View {
      VStack(spacing: 12) {
        FeatureCardView(
          icon: "location.fill",
          iconColor: Color.pmindigo.n500,
          problem: "약속 잡고 또 지도 검색하고 계산하고...",
          solution: "교통수단별 이동시간 비교,\n여유시간 설정, 출발 알림까지",
          previewContent: AnyView(DeparturePreviewView()),
          index: 0
        )

        FeatureCardView(
          icon: "calendar.badge.exclamationmark",
          iconColor: Color.pmwarning.n600,
          problem: "일정 잡고 나서야 겹친 걸 발견?",
          solution: "일정 생성 시 충돌·날씨를\n타임라인으로 미리 확인",
          previewContent: AnyView(ConflictPreviewView()),
          index: 1
        )

        FeatureCardView(
          icon: "sparkles",
          iconColor: Color.pmpurple.n500,
          problem: "오늘 일정 뭐였지? 또 앱 열어봐야 하나",
          solution: "매일 설정한 시간에 알림으로,\n홈에서는 언제든 브리핑 확인",
          previewContent: AnyView(BriefingPreviewView()),
          index: 2
        )
      }
    }

    // MARK: - Free vs Pro Comparison Table

    @ViewBuilder
    private var comparisonSection: some View {
      VStack(spacing: 16) {
        VStack(spacing: 4) {
          Text("Free도 충분해요. Pro는 한 발 더 나아가요.")
            .font(.headline)
            .foregroundStyle(Color.pmtext.primary)

          Text("출발시간부터 날씨까지, 일정 그 이후를 챙겨드려요")
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: 0) {
          // 헤더
          HStack {
            Text("기능")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text("Free")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.secondary)
              .frame(width: 48)
            Text("Pro")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 48)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)

          Divider().padding(.horizontal, 16)

          // 공통 기능
          comparisonRow("일정 생성 · 관리", free: true, pro: true)
          comparisonRow("그룹 일정", free: true, pro: true)
          comparisonRow("캘린더 (일·주·월)", free: true, pro: true)
          comparisonRow("위젯", free: true, pro: true)
          comparisonRow("Live Activity", free: true, pro: true)

          Divider().padding(.horizontal, 16).padding(.vertical, 2)

          // Pro 전용
          comparisonRow("출발 시간 자동 계산 및 알림", free: false, pro: true)
          comparisonRow("일정 충돌 감지", free: false, pro: true)
          comparisonRow("일정별 날씨 확인", free: false, pro: true)
          comparisonRow("매일 AI 일정 브리핑", free: false, pro: true)

          Divider().padding(.horizontal, 16).padding(.vertical, 2)

          // 추후 Pro 기능 안내
          HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 13))
              .foregroundStyle(Color.pmindigo.n500)
            Text("추후 생성될 유용한 Pro 기능들")
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
        }
        .padding(.vertical, 8)
        .staticGlassBackground(cornerRadius: 16)
      }
    }

    private func comparisonRow(_ feature: String, free: Bool, pro: Bool) -> some View {
      HStack {
        Text(feature)
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Group {
          if free {
            Image(systemName: "checkmark")
              .foregroundStyle(Color.pmgray.n400)
          } else {
            Image(systemName: "minus")
              .foregroundStyle(Color.pmgray.n300)
          }
        }
        .font(.system(size: 13, weight: .medium))
        .frame(width: 48)

        Image(systemName: "checkmark")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 48)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }

    // MARK: - Pricing

    @ViewBuilder
    private var pricingSection: some View {
      VStack(spacing: 12) {
        if store.isLoadingProducts {
          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 16)
              .fill(Color.pmgray.n700.opacity(0.3))
              .frame(height: 88)
          }
        } else {
          ForEach(store.products) { product in
            PricingCardView(
              product: product,
              isSelected: store.selectedProductId == product.id,
              isEligibleForIntroOffer: store.isEligibleForIntroOffer,
              onTap: {
                store.send(.view(.productSelected(product.id)))
              }
            )
          }
        }
      }
    }

    // MARK: - Legal

    @ViewBuilder
    private var legalSection: some View {
      VStack(spacing: 8) {
        Text(showFreeTrialText
          ? "무료 체험 기간이 끝나면 구독이 자동으로 시작되며, iTunes 계정으로 청구됩니다. 무료 체험 중 언제든 설정에서 취소할 수 있습니다. 구독은 현재 기간 종료 최소 24시간 전에 자동 갱신 해제하지 않으면 자동으로 갱신됩니다."
          : "구독은 확인 시 iTunes 계정으로 청구됩니다. 구독은 현재 기간 종료 최소 24시간 전에 자동 갱신 해제하지 않으면 자동으로 갱신됩니다. 갱신 요금은 현재 기간 종료 전 24시간 이내에 청구됩니다. 구독은 구매 후 계정 설정에서 관리 및 취소할 수 있습니다."
        )
          .font(.caption2)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)

        HStack(spacing: 16) {
          if let termsURL = URL(string: "https://promiso.app/terms") {
            Link("이용약관", destination: termsURL)
          }
          if let privacyURL = URL(string: "https://promiso.app/privacy") {
            Link("개인정보처리방침", destination: privacyURL)
          }
        }
        .font(.caption2)
        .foregroundStyle(Color.pmindigo.n500)
      }
    }

    // MARK: - CTA Bottom Bar

    @ViewBuilder
    private var ctaBottomBar: some View {
      VStack(spacing: 8) {
        // 접기/펼치기 토글
        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPricingExpanded.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Text(isPricingExpanded ? "요금제 접기" : "요금제 보기")
              .font(.system(size: 13, weight: .semibold))
            Image(systemName: "chevron.up")
              .font(.system(size: 11, weight: .semibold))
              .rotationEffect(.degrees(isPricingExpanded ? 180 : 0))
          }
          .foregroundStyle(Color.pmindigo.n500)
          .contentShape(Rectangle())
        }

        // 가격표 (접혔다 펼쳐짐)
        if isPricingExpanded {
          pricingSection
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        // CTA 버튼
        Button {
          store.send(.view(.purchaseTapped))
        } label: {
          Text(ctaButtonText)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .leading,
                endPoint: .trailing
              ),
              in: RoundedRectangle(cornerRadius: 16)
            )
            .contentShape(Rectangle())
        }
        .disabled(store.selectedProductId == nil || store.isPurchasing)
        .opacity((store.selectedProductId == nil || store.isPurchasing) ? 0.5 : 1.0)

        Text("7일 이내 취소 시 무료 · 언제든 해지 가능")
          .font(.caption2)
          .foregroundStyle(Color.pmgray.n400)

        Button {
          store.send(.view(.restoreTapped))
        } label: {
          Text("구매 내역 복원")
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
            .underline()
        }
        .disabled(store.isPurchasing)
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 8)
      .background(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: Color(.systemBackground).opacity(0.95), location: 0.15),
            .init(color: Color(.systemBackground), location: 1.0),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()
      )
    }

    // MARK: - CTA Text

    private var ctaButtonText: String {
      if let selectedId = store.selectedProductId,
         let product = store.products.first(where: { $0.id == selectedId }),
         product.type == .lifetime {
        return "평생 이용권 구매하기"
      }
      if showFreeTrialText {
        return "\(freeTrialDays)일 무료 체험 시작하기"
      }
      return "Pro 시작하기"
    }

    // MARK: - Computed Properties

    private var showFreeTrialText: Bool {
      guard store.isEligibleForIntroOffer,
            let selectedId = store.selectedProductId,
            let product = store.products.first(where: { $0.id == selectedId }),
            let intro = product.introductoryOffer,
            intro.isFreeTrialOffer else {
        return false
      }
      return true
    }

    private var freeTrialDays: Int {
      guard let selectedId = store.selectedProductId,
            let product = store.products.first(where: { $0.id == selectedId }) else {
        return 0
      }
      return product.introductoryOffer?.periodDays ?? 0
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private var loadingOverlay: some View {
      ZStack {
        Color.black.opacity(0.4)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(.white)

          Text("처리 중...")
            .font(.body)
            .foregroundStyle(.white)
        }
        .padding(32)
        .adaptiveGlassCard()
      }
    }
  }
}

// MARK: - Feature Card View

extension ProPlan {

  fileprivate struct FeatureCardView: View {
    let icon: String
    let iconColor: Color
    let problem: String
    let solution: String
    let previewContent: AnyView
    let index: Int

    @State private var isVisible = false

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(iconColor, in: RoundedRectangle(cornerRadius: 8))

          Text(problem)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }

        Text(solution)
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        previewContent
          .allowsHitTesting(false)
          .padding(12)
          .frame(maxWidth: .infinity)
          .staticGlassBackground(cornerRadius: 12)
      }
      .padding(16)
      .staticGlassBackground(cornerRadius: 16)
      .opacity(isVisible ? 1 : 0)
      .offset(y: isVisible ? 0 : 20)
      .onAppear {
        withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.1)) {
          isVisible = true
        }
      }
    }
  }
}

// MARK: - Feature Preview Views

extension ProPlan {

  /// 출발 알림 미리보기 — 약속시간 → 교통수단 소요시간 → 여유시간 → 알림시간 흐름
  fileprivate struct DeparturePreviewView: View {
    var body: some View {
      VStack(spacing: 10) {
        // 경로 헤더 (실제 DepartureAlertSheet routeInfoCard 스타일)
        VStack(spacing: 8) {
          HStack(spacing: 0) {
            // 출발
            VStack(spacing: 2) {
              HStack(spacing: 4) {
                Circle().fill(Color.pmindigo.n400).frame(width: 5, height: 5)
                Text("출발")
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmindigo.n400)
              }
              Text("집")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(Color.pmgray.n400)
              .frame(width: 28)

            // 도착
            VStack(spacing: 2) {
              HStack(spacing: 4) {
                Circle().fill(Color.pmerror.n500).frame(width: 5, height: 5)
                Text("도착")
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmerror.n500)
              }
              Text("강남역 카페")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)
            }
            .frame(maxWidth: .infinity)
          }

          // 약속 시간
          Text("🗓️ 오후 2:00 시작")
            .font(.system(size: 10))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground).opacity(0.5))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.pmgray.n200.opacity(0.3), lineWidth: 1)
        )

        // 교통수단 카드 (실제 transportCard 스타일)
        transportCard(
          icon: "car.fill", label: "자동차",
          detail: "약 15분", departureTime: "오후 1:35",
          isSelected: true
        )
        transportCard(
          icon: "bus.fill", label: "대중교통",
          detail: "약 28분", departureTime: "오후 1:22",
          isSelected: false
        )

        // 여유시간 + 알림 결과
        VStack(spacing: 6) {
          HStack {
            Text("여유 시간")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
            Spacer()
            HStack(spacing: 3) {
              Text("10분")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)
              Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(Color.pmgray.n400)
            }
          }

          // 확인 버튼 (실제 confirmButton 스타일)
          HStack(spacing: 4) {
            Image(systemName: "bell.fill")
              .font(.system(size: 10))
            Text("알림 받기")
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 10))

          // 설명 텍스트
          Text("자동차로 오후 1:25 — 10분 여유 포함해 알림을 드려요")
            .font(.system(size: 9))
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
      }
    }

    private func transportCard(icon: String, label: String, detail: String, departureTime: String, isSelected: Bool) -> some View {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isSelected ? .white : Color.pmindigo.n500)
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 7)
              .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.08))
          )

        VStack(alignment: .leading, spacing: 1) {
          Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text(detail)
            .font(.system(size: 10))
            .foregroundStyle(Color.pmtext.secondary)
        }

        Spacer(minLength: 0)

        Text(departureTime)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? .white : Color.pmindigo.n500)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(
            RoundedRectangle(cornerRadius: 7)
              .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.1))
          )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.pmindigo.n500.opacity(0.08) : Color(.systemBackground).opacity(0.4))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(
            isSelected ? Color.pmindigo.n500.opacity(0.4) : Color.pmgray.n200.opacity(0.3),
            lineWidth: isSelected ? 1.5 : 1
          )
      )
    }
  }

  /// 충돌 감지 미리보기 — 실제 ProBonusFloatingView + ProConflictRow 패턴
  fileprivate struct ConflictPreviewView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        // ProBonusFloatingView 스타일 카드
        VStack(alignment: .leading, spacing: 6) {
          // PRO 뱃지 (실제 ProBadge 패턴)
          HStack(spacing: 2) {
            Image(systemName: "sparkles")
              .font(.system(size: 7, weight: .bold))
            Text("PRO")
              .font(.system(size: 7, weight: .heavy))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .leading,
              endPoint: .trailing
            ),
            in: Capsule()
          )

          // 날씨 행 (실제 ProWeatherRow 패턴)
          HStack(spacing: 6) {
            Image(systemName: "cloud.rain.fill")
              .symbolRenderingMode(.multicolor)
              .font(.system(size: 11))
              .frame(width: 20, height: 20)
              .background(
                Circle()
                  .fill(Color.cyan.opacity(0.12))
              )

            Text("8°")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color.pmtext.primary)

            Text("비 올 수 있어요, 우산 챙기세요")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
              .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "info.circle")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmgray.n400)
          }

          // 충돌 요약 행 (실제 ProConflictRow 패턴)
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 12))
              .foregroundStyle(Color.pmwarning.n500)

            Text("'팀 회의'과(와) 30분 겹쳐요")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.primary)
              .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "info.circle")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmgray.n400)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .proGlassCard(cornerRadius: 10)

        // 타임라인 시각화 (ConflictTooltip 스타일 — 2열 블록)
        HStack(alignment: .top, spacing: 4) {
          // 시간 라벨
          VStack(alignment: .trailing, spacing: 0) {
            Text("1:00")
              .font(.system(size: 8, weight: .medium, design: .rounded))
              .foregroundStyle(Color.pmtext.secondary)
            Spacer()
            Text("1:30")
              .font(.system(size: 8, weight: .medium, design: .rounded))
              .foregroundStyle(Color.pmwarning.n600)
            Spacer()
            Text("2:00")
              .font(.system(size: 8, weight: .medium, design: .rounded))
              .foregroundStyle(Color.pmtext.secondary)
            Spacer()
            Text("3:00")
              .font(.system(size: 8, weight: .medium, design: .rounded))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .frame(width: 26, height: 64)

          // 팀 회의 블록 (1:00-2:00, 높이 50%)
          VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.pmindigo.n500.opacity(0.15))
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .strokeBorder(Color.pmindigo.n500.opacity(0.4), lineWidth: 1)
              )
              .overlay(
                Text("📌 팀 회의")
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmindigo.n500)
              )
              .frame(height: 32)
            Spacer(minLength: 0)
          }
          .frame(height: 64)

          // 점심 약속 블록 (1:30-3:00, offset y 16 = 1:30 시작)
          VStack(spacing: 0) {
            Spacer().frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.pmwarning.n600.opacity(0.12))
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .strokeBorder(Color.pmwarning.n600.opacity(0.4), lineWidth: 1)
              )
              .overlay(
                Text("🍽️ 점심 약속")
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmwarning.n600)
              )
              .frame(height: 48)
          }
          .frame(height: 64)
        }
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemBackground).opacity(0.5))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.pmgray.n200.opacity(0.3), lineWidth: 1)
        )
      }
    }
  }

  /// AI 브리핑 미리보기 — DailyBriefingCard 스타일
  fileprivate struct BriefingPreviewView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        // 헤더
        HStack(spacing: 6) {
          HStack(spacing: 2) {
            Image(systemName: "sparkles")
              .font(.system(size: 8, weight: .bold))
            Text("PRO")
              .font(.system(size: 8, weight: .heavy))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .leading,
              endPoint: .trailing
            ),
            in: Capsule()
          )

          Text("데일리 브리핑")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          Spacer()
        }

        Divider()

        // 브리핑 본문 (유머러스 톤 예시)
        Text("오늘 3개 약속이 있어요 💪 첫 번째 강남 카페는 비 온다니까 우산 챙기고, 자동차로 1:35에 출발하면 딱이에요. 팀 회의랑 점심이 30분 겹치는데 — 회의 일찍 빠지든 점심 늦게 가든 선택은 당신의 몫! 저녁 홍대 약속은 대중교통 40분, 6:10 출발 추천이요 🚇")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.primary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)

        Divider()

        // 커스텀 옵션 태그
        HStack(spacing: 6) {
          customTag(icon: "face.smiling", text: "유머러스")
          customTag(icon: "car.fill", text: "자동차 포함")
          customTag(icon: "clock", text: "오전 8시")
        }
      }
    }

    private func customTag(icon: String, text: String) -> some View {
      HStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 8))
        Text(text)
          .font(.system(size: 9, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color.pmindigo.n500.opacity(0.08), in: Capsule())
    }
  }
}

// MARK: - Pricing Card View

extension ProPlan {

  fileprivate struct PricingCardView: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let isEligibleForIntroOffer: Bool
    let onTap: () -> Void

    private var showFreeTrial: Bool {
      isEligibleForIntroOffer && product.introductoryOffer?.isFreeTrialOffer == true
    }

    private var freeTrialDays: Int {
      product.introductoryOffer?.periodDays ?? 0
    }

    var body: some View {
      Button(action: onTap) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(product.displayName)
                .font(.headline)
                .foregroundStyle(Color.pmtext.primary)

              if product.type == .yearly {
                Text("BEST")
                  .font(.system(size: 9, weight: .heavy))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.pmindigo.n500, in: Capsule())
              } else if product.type == .lifetime {
                Text("LIMITED")
                  .font(.system(size: 9, weight: .heavy))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.pmwarning.n500, in: Capsule())
              }
            }

            if product.type == .yearly {
              Text("월 ₩2,416 · 38% 절약")
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            } else if product.type == .lifetime {
              Text("지금만 제공되는 특가 · 조기 종료 예정")
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            if showFreeTrial {
              Text("\(freeTrialDays)일 무료 후 시작")
                .font(.caption)
                .foregroundStyle(Color.pmindigo.n500)
            }
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 2) {
            Text(product.displayPrice)
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.primary)

            if product.type == .monthly {
              Text("/ 월")
                .font(.caption)
                .foregroundStyle(Color.pmgray.n400)
            } else if product.type == .yearly {
              Text("/ 년")
                .font(.caption)
                .foregroundStyle(Color.pmgray.n400)
            }
          }
        }
        .padding(16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .staticGlassBackground(cornerRadius: 16)
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected ? Color.pmindigo.n500 : Color.clear,
            lineWidth: 2
          )
          .animation(.spring(duration: 0.3), value: isSelected)
      }
    }
  }
}

// MARK: - Preview

#Preview("Paywall - Loading") {
  ProPlan.PaywallView(
    store: Store(
      initialState: ProPlan.Feature.State(
        products: [],
        isLoadingProducts: true
      )
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
}

#Preview("Paywall - Products") {
  ProPlan.PaywallView(
    store: Store(
      initialState: ProPlan.Feature.State(
        products: [
          SubscriptionProduct(
            id: SubscriptionProductType.monthly.productId,
            type: .monthly,
            displayName: "월간 프로",
            description: "매월 자동 갱신",
            displayPrice: "₩3,900",
            price: 3900
          ),
          SubscriptionProduct(
            id: SubscriptionProductType.yearly.productId,
            type: .yearly,
            displayName: "연간 프로",
            description: "매년 자동 갱신 (월 ₩2,416)",
            displayPrice: "₩29,000",
            price: 29000
          ),
          SubscriptionProduct(
            id: SubscriptionProductType.lifetime.productId,
            type: .lifetime,
            displayName: "평생 프로",
            description: "한 번 결제, 영구 사용",
            displayPrice: "₩39,000",
            price: 39000
          ),
        ],
        selectedProductId: SubscriptionProductType.yearly.productId
      )
    ) {
      ProPlan.Feature()
    } withDependencies: {
      $0.subscriptionClient = .previewValue
    }
  )
}

#Preview("Paywall - Purchasing") {
  ProPlan.PaywallView(
    store: Store(
      initialState: ProPlan.Feature.State(
        products: [
          SubscriptionProduct(
            id: SubscriptionProductType.yearly.productId,
            type: .yearly,
            displayName: "연간 프로",
            description: "매년 자동 갱신 (월 ₩2,416)",
            displayPrice: "₩29,000",
            price: 29000
          ),
        ],
        isPurchasing: true,
        selectedProductId: SubscriptionProductType.yearly.productId
      )
    ) {
      ProPlan.Feature()
    }
  )
}
