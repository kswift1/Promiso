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
            pricingSection
            legalSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 180)
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
      VStack(spacing: 14) {
        Text("약속 잡고 나서,\n또 계산하고 계신가요?")
          .font(.system(size: 26, weight: .bold))
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.pmtext.primary)

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
          solution: "자동차·대중교통·도보\n이동시간과 출발시간을 자동 계산",
          previewContent: AnyView(DeparturePreviewView()),
          index: 0
        )

        FeatureCardView(
          icon: "calendar.badge.exclamationmark",
          iconColor: Color.pmwarning.n600,
          problem: "일정 잡고 나서야 겹친 걸 발견?",
          solution: "일정 생성할 때 시간 충돌을\n자동으로 계산해서 미리 알려줘요",
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
          Text("꾸미기가 아니라, 진짜 쓸모")
            .font(.headline)
            .foregroundStyle(Color.pmtext.primary)

          Text("실제로 일정 관리에 도움이 되는 기능만 담았어요")
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
          comparisonRow("출발시간 자동 계산", free: false, pro: true)
          comparisonRow("일정 충돌 감지", free: false, pro: true)
          comparisonRow("날씨 연동 안내", free: false, pro: true)
          comparisonRow("AI 일정 브리핑", free: false, pro: true)
        }
        .padding(.vertical, 8)
        .adaptiveGlassCard()
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
      VStack(spacing: 6) {
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
            .init(color: Color(.systemBackground).opacity(0.95), location: 0.25),
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
          .background(Color.pmgray.n700.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
      }
      .padding(16)
      .adaptiveGlassCard()
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

  /// 출발 알림 미리보기 — DepartureAlertSheet 교통수단 카드 스타일
  fileprivate struct DeparturePreviewView: View {
    var body: some View {
      VStack(spacing: 6) {
        // 경로 헤더
        HStack(spacing: 6) {
          Circle().fill(Color.pmindigo.n500).frame(width: 5, height: 5)
          Text("집")
            .font(.system(size: 10))
            .foregroundStyle(Color.pmtext.secondary)
          Image(systemName: "arrow.right")
            .font(.system(size: 8))
            .foregroundStyle(Color.pmgray.n400)
          Circle().fill(Color.pmpurple.n500).frame(width: 5, height: 5)
          Text("강남역 카페")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.pmtext.primary)
          Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.pmgray.n200.opacity(0.4), lineWidth: 1)
        )

        // 교통수단 3종 (자동차 선택 상태)
        transportRow(icon: "car.fill", label: "자동차", time: "15분", departure: "1:35 출발", isSelected: true)
        transportRow(icon: "bus.fill", label: "대중교통", time: "28분", departure: "1:22 출발", isSelected: false)
        transportRow(icon: "figure.walk", label: "도보", time: "42분", departure: "1:08 출발", isSelected: false)
      }
    }

    private func transportRow(icon: String, label: String, time: String, departure: String, isSelected: Bool) -> some View {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 10))
          .foregroundStyle(isSelected ? .white : Color.pmindigo.n500)
          .frame(width: 24, height: 24)
          .background(
            isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 5)
          )

        Text(label)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.pmtext.primary)

        Text(time)
          .font(.system(size: 10))
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Text(departure)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        isSelected ? Color.pmindigo.n500.opacity(0.06) : Color.clear,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            isSelected ? Color.pmindigo.n500.opacity(0.35) : Color.pmgray.n200.opacity(0.3),
            lineWidth: isSelected ? 1.5 : 1
          )
      )
    }
  }

  /// 충돌 감지 미리보기 — ConflictWarningSection 스타일
  fileprivate struct ConflictPreviewView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        // 경고 헤더 (실제 앱의 ConflictWarningSection 헤더)
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmwarning.n600)
          Text("겹치는 일정이 있어요")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmwarning.n600)
        }

        // 충돌 행 (실제 앱의 ConflictRow 패턴)
        HStack(spacing: 10) {
          // 아이콘
          Image(systemName: "calendar")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmwarning.n600)
            .frame(width: 28, height: 28)
            .background(Color.pmwarning.n600.opacity(0.12), in: Circle())

          VStack(alignment: .leading, spacing: 2) {
            Text("팀 회의")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
            Text("1:00 – 2:00")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          Text("30분 겹침")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.pmwarning.n600)
        }

        HStack(spacing: 10) {
          Image(systemName: "calendar")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmwarning.n600)
            .frame(width: 28, height: 28)
            .background(Color.pmwarning.n600.opacity(0.12), in: Circle())

          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
              Text("점심 약속")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.pmtext.primary)
              Text("미확정")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.pmwarning.n500)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.pmwarning.n500.opacity(0.12), in: Capsule())
            }
            Text("1:30 – 3:00")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()
        }
      }
      .padding(12)
      .background(Color.pmwarning.n50, in: RoundedRectangle(cornerRadius: 10))
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

          Text("오전 8시 알림")
            .font(.system(size: 10))
            .foregroundStyle(Color.pmindigo.n500)
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
      .adaptiveGlassCard()
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
