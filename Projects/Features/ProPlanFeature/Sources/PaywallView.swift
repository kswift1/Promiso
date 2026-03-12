//
//  PaywallView.swift
//  ProPlanFeature
//
//  Created by Claude on 2026-02-24.
//

import Clients
import ComposableArchitecture
import Lottie
import PromisoShared
import ResourceKit
import SharedFeature
import SwiftUI

// MARK: - Paywall View

extension ProPlan {

  /// Paywall 화면 - 2단계 시트 (베네핏 소개 → 요금제 선택)
  public struct PaywallView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        benefitsPage
          .navigationDestination(
            isPresented: Binding(
              get: { store.showPricing },
              set: { newValue in
                if newValue {
                  store.send(.view(.showPricingTapped))
                } else {
                  store.send(.view(.backToBenefitsTapped))
                }
              }
            )
          ) {
            pricingPage
              .navigationDestination(
                isPresented: Binding(
                  get: { store.showProOnboarding },
                  set: { _ in }
                )
              ) {
                proOnboardingPage
              }
          }
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.hidden)
      .presentationCornerRadius(24)
      .interactiveDismissDisabled(store.isPurchasing)
    }

    // MARK: - Page 1: Benefits

    @ViewBuilder
    private var benefitsPage: some View {
      ZStack {
        ScrollView {
          VStack(spacing: 24) {
            heroSection
            benefitsSection
            comparisonSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 120)
        }
        .auroraBackground()

        // 하단 고정 CTA
        VStack(spacing: 8) {
          Button {
            store.send(.view(.showPricingTapped))
          } label: {
            HStack {
              Text(LocalizedStrings.ProPlan.viewPlans)
                .font(.headline)
                .foregroundStyle(.white)

              Spacer()

              Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
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
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: Color(.systemBackground).opacity(0.8), location: 0.3),
              .init(color: Color(.systemBackground), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 140)
          .frame(maxHeight: .infinity, alignment: .bottom)
          .ignoresSafeArea()
        )
      }
      .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Page 2: Pricing

    @ViewBuilder
    private var pricingPage: some View {
      ZStack {
        ScrollView {
          VStack(spacing: 24) {
            if store.isLoadingProducts {
              loadingSection
            } else {
              productsSection
            }

            trustSection
            legalSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 120)
        }
        .auroraBackground()

        // 하단 고정 CTA
        VStack(spacing: 8) {
          HStack(spacing: 12) {
            // 뒤로가기 원형 버튼
            Button {
              store.send(.view(.backToBenefitsTapped))
            } label: {
              Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)
                .frame(width: 52, height: 52)
                .background(Color.pmgray.n700.opacity(0.3), in: Circle())
                .contentShape(Circle())
            }

            purchaseButton
          }
          restoreButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: Color(.systemBackground).opacity(0.8), location: 0.3),
              .init(color: Color(.systemBackground), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 140)
          .frame(maxHeight: .infinity, alignment: .bottom)
          .ignoresSafeArea()
        )

        if store.isPurchasing {
          loadingOverlay
        }

        if store.showCelebration {
          celebrationOverlay
        }
      }
      .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Celebration Overlay

    @ViewBuilder
    private var celebrationOverlay: some View {
      ZStack {
        Color.black.opacity(0.6)
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            LottieView(animation: LottieAsset.fanfare.animation)
              .playing(loopMode: .playOnce)
              .frame(width: 200, height: 200)

            VStack(spacing: 8) {
              Text(LocalizedStrings.ProPlan.celebrationTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

              Text(LocalizedStrings.ProPlan.celebrationSubtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
            }

            // Pro 기능 가이드
            VStack(spacing: 12) {
              celebrationGuideRow(
                icon: "bell.badge.waveform",
                iconColor: Color.pmaurora.purple,
                title: LocalizedStrings.ProPlan.featureSmartBriefingTitle,
                description: LocalizedStrings.ProPlan.featureSmartBriefingDescription
              )

              celebrationGuideRow(
                icon: "widget.small",
                iconColor: Color.pmindigo.n500,
                title: LocalizedStrings.ProPlan.featureWidgetTitle,
                description: LocalizedStrings.ProPlan.featureWidgetDescription
              )

              celebrationGuideRow(
                icon: "calendar.badge.exclamationmark",
                iconColor: Color.pmwarning.n500,
                title: LocalizedStrings.ProPlan.featureConflictTitle,
                description: LocalizedStrings.ProPlan.featureConflictDescription
              )
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            Button {
              store.send(.view(.dismissCelebration))
            } label: {
              Text(LocalizedStrings.ProPlan.startButton)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                  LinearGradient(
                    colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
          }
          .padding(.vertical, 40)
        }
      }
    }

    // MARK: - Pro Onboarding Page

    @ViewBuilder
    private var proOnboardingPage: some View {
      ProOnboardingSetupView(store: store)
    }

    private func celebrationGuideRow(
      icon: String,
      iconColor: Color,
      title: String,
      description: String
    ) -> some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(iconColor, in: Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
          Text(description)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }

        Spacer(minLength: 0)
      }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
      VStack(spacing: 16) {
        ResourceKitAsset.paywallHero.swiftUIImage
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 200)

        Text("Promiso Pro")
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)

        Text(LocalizedStrings.ProPlan.heroSubtitle)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
      }
    }

    // MARK: - Benefits Section

    @ViewBuilder
    private var benefitsSection: some View {
      VStack(spacing: 12) {
        BenefitCardView(
          icon: "bell.badge.waveform",
          iconColor: Color.pmaurora.purple,
          title: LocalizedStrings.ProPlan.featureSmartBriefingTitle,
          description: LocalizedStrings.ProPlan.featureSmartBriefingDescription,
          previewContent: AnyView(NotificationMockView())
        )

        BenefitCardView(
          icon: "widget.small",
          iconColor: Color.pmindigo.n500,
          title: LocalizedStrings.ProPlan.featureWidgetTitle,
          description: LocalizedStrings.ProPlan.featureWidgetDescription,
          previewContent: AnyView(WidgetMockView())
        )

        BenefitCardView(
          icon: "calendar.badge.exclamationmark",
          iconColor: Color.pmwarning.n500,
          title: LocalizedStrings.ProPlan.featureConflictTitle,
          description: LocalizedStrings.ProPlan.featureConflictDescription,
          previewContent: AnyView(ConflictMockView())
        )
      }
    }

    // MARK: - Comparison Section

    @ViewBuilder
    private var comparisonSection: some View {
      VStack(spacing: 16) {
        Text(LocalizedStrings.ProPlan.comparisonTitle)
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 0) {
          comparisonHeaderRow()

          Divider().padding(.vertical, 4)

          comparisonRow(LocalizedStrings.ProPlan.comparisonBasicSchedule, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonGroupSchedule, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonLiveActivity, free: true, pro: true)

          Divider().padding(.vertical, 4)

          comparisonRow(LocalizedStrings.ProPlan.featureSmartBriefingTitle, free: false, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.featureWidgetTitle, free: false, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.featureConflictTitle, free: false, pro: true)
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    private func comparisonHeaderRow() -> some View {
      HStack {
        Spacer()
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(LocalizedStrings.ProPlan.comparisonFreeLabel)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(Color.pmtext.secondary)
          .frame(width: 50)
        Text(LocalizedStrings.ProPlan.comparisonProLabel)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 50)
      }
    }

    private func comparisonRow(_ feature: String, free: Bool, pro: Bool) -> some View {
      HStack {
        Text(feature)
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
          .font(.system(size: 16))
          .foregroundStyle(free ? Color.pmsuccess.n500 : Color.pmgray.n400)
          .frame(width: 50)

        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 50)
      }
      .padding(.vertical, 6)
    }

    // MARK: - Loading Section

    @ViewBuilder
    private var loadingSection: some View {
      VStack(spacing: 16) {
        ForEach(0..<3) { _ in
          RoundedRectangle(cornerRadius: 16)
            .fill(Color.pmgray.n700.opacity(0.3))
            .frame(height: 120)
        }
      }
    }

    // MARK: - Products Section

    @ViewBuilder
    private var productsSection: some View {
      VStack(spacing: 12) {
        ForEach(store.products) { product in
          ProductCardView(
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

    // MARK: - Trust Section

    @ViewBuilder
    private var trustSection: some View {
      HStack(spacing: 8) {
        Image(systemName: "checkmark.shield.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmsuccess.n500)
        Text(LocalizedStrings.ProPlan.trustText)
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity)
    }

    // MARK: - Purchase Button

    /// 선택된 상품이 무료 체험 대상인지
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

    /// 무료 체험 일수
    private var freeTrialDays: Int {
      guard let selectedId = store.selectedProductId,
            let product = store.products.first(where: { $0.id == selectedId }) else {
        return 0
      }
      return product.introductoryOffer?.periodDays ?? 0
    }

    @ViewBuilder
    private var purchaseButton: some View {
      Button {
        store.send(.view(.purchaseTapped))
      } label: {
        HStack {
          Text(showFreeTrialText ? LocalizedStrings.ProPlan.freeTrialStart(freeTrialDays) : LocalizedStrings.ProPlan.startButton)
            .font(.headline)
            .foregroundStyle(.white)

          Spacer()

          Image(systemName: "arrow.right")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
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
    }

    // MARK: - Restore Button

    @ViewBuilder
    private var restoreButton: some View {
      Button {
        store.send(.view(.restoreTapped))
      } label: {
        Text(LocalizedStrings.ProPlan.restorePurchases)
          .font(.footnote)
          .foregroundStyle(Color.pmtext.secondary)
          .underline()
      }
      .disabled(store.isPurchasing)
    }

    // MARK: - Legal Section

    @ViewBuilder
    private var legalSection: some View {
      VStack(spacing: 8) {
        Text(showFreeTrialText
          ? LocalizedStrings.ProPlan.legalTrialDisclaimer
          : LocalizedStrings.ProPlan.legalSubscriptionDisclaimer
        )
          .font(.caption2)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)

        HStack(spacing: 16) {
          if let termsURL = URL(string: "https://promiso.app/terms") {
            Link(LocalizedStrings.ProPlan.legalTerms, destination: termsURL)
          }
          if let privacyURL = URL(string: "https://promiso.app/privacy") {
            Link(LocalizedStrings.ProPlan.legalPrivacy, destination: privacyURL)
          }
        }
        .font(.caption2)
        .foregroundStyle(Color.pmindigo.n500)
      }
      .padding(.top, 8)
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

          Text(LocalizedStrings.ProPlan.processing)
            .font(.body)
            .foregroundStyle(.white)
        }
        .padding(32)
        .adaptiveGlassCard()
      }
    }
  }
}

// MARK: - Benefit Card View

extension ProPlan {

  private struct BenefitCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let previewContent: AnyView

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
              LinearGradient(
                colors: [iconColor, iconColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              in: Circle()
            )

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.headline)
              .foregroundStyle(Color.pmtext.primary)
            Text(description)
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
          }
        }

        previewContent
          .allowsHitTesting(false)
          .padding(12)
          .frame(maxWidth: .infinity)
          .background(Color.pmgray.n700.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }

  // MARK: - Notification Mock

  private struct NotificationMockView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "car.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmaurora.purple)
          Text(LocalizedStrings.ProPlan.mockDepartureNow)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
        }
        Text(LocalizedStrings.ProPlan.mockTravelTime)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
        HStack(spacing: 12) {
          Label(LocalizedStrings.ProPlan.mockRainAlert, systemImage: "cloud.rain.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pminfo.n500)
          Label(LocalizedStrings.ProPlan.mockLeaveRecommendation, systemImage: "clock.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Widget Mock

  private struct WidgetMockView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(LocalizedStrings.ProPlan.mockNextSchedule)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
          Spacer()
          ProBadge()
        }
        Text(LocalizedStrings.ProPlan.mockNextScheduleSummary)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Divider()
        HStack(spacing: 12) {
          Label(LocalizedStrings.ProPlan.mockTemperature, systemImage: "sun.max.fill")
            .font(.system(size: 11))
            .symbolRenderingMode(.multicolor)
          Label(LocalizedStrings.ProPlan.mockTravelDuration, systemImage: "car.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          Label(LocalizedStrings.ProPlan.mockDepartureTime, systemImage: "clock.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmaurora.purple)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Conflict Mock

  private struct ConflictMockView: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmwarning.n500)
          Text(LocalizedStrings.ProPlan.mockConflictTitle)
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.primary)
        }
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStrings.ProPlan.mockConflictExistingTitle)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
            Text(LocalizedStrings.ProPlan.mockConflictExistingTime)
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .padding(8)
          .background(Color.pmwarning.n500.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

          Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)

          VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStrings.ProPlan.mockConflictNewTitle)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
            Text(LocalizedStrings.ProPlan.mockConflictNewTime)
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .padding(8)
          .background(Color.pmindigo.n500.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Product Card View

extension ProPlan {

  /// 상품 카드 - 월간/연간/평생 플랜 표시
  private struct ProductCardView: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let isEligibleForIntroOffer: Bool
    let onTap: () -> Void

    /// 무료 체험 표시 여부
    private var showFreeTrial: Bool {
      isEligibleForIntroOffer && product.introductoryOffer?.isFreeTrialOffer == true
    }

    /// 무료 체험 일수
    private var freeTrialDays: Int {
      product.introductoryOffer?.periodDays ?? 0
    }

    var body: some View {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(product.displayName)
              .font(.headline)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            if product.type == .yearly {
              Badge(text: LocalizedStrings.ProPlan.badgeTwoMonthsFree, color: Color.pmaurora.purple)
            } else if product.type == .lifetime {
              Badge(text: LocalizedStrings.ProPlan.badgeLifetime, color: Color.pmaurora.pink)
            }
          }

          if showFreeTrial {
            Text(LocalizedStrings.ProPlan.freeTrialAfter(freeTrialDays, product.description))
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
          } else {
            Text(product.description)
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
          }

          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(product.displayPrice)
              .font(.system(size: 24, weight: .bold))
              .foregroundStyle(Color.pmindigo.n500)

            if product.type == .monthly {
              Text(LocalizedStrings.ProPlan.perMonth)
                .font(.subheadline)
                .foregroundStyle(Color.pmgray.n400)
            } else if product.type == .yearly {
              Text(LocalizedStrings.ProPlan.perYear)
                .font(.subheadline)
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
        if isSelected {
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.pmindigo.n500, lineWidth: 2)
        }
      }
    }
  }

  /// 뱃지 컴포넌트
  private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
      Text(text)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color, in: Capsule())
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
            description: "매년 자동 갱신 (월 ₩3,250)",
            displayPrice: "₩39,000",
            price: 39000
          ),
          SubscriptionProduct(
            id: SubscriptionProductType.lifetime.productId,
            type: .lifetime,
            displayName: "평생 프로",
            description: "한 번 결제, 영구 사용",
            displayPrice: "₩59,000",
            price: 59000
          )
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
            description: "매년 자동 갱신 (월 ₩3,250)",
            displayPrice: "₩39,000",
            price: 39000
          )
        ],
        isPurchasing: true,
        selectedProductId: SubscriptionProductType.yearly.productId
      )
    ) {
      ProPlan.Feature()
    }
  )
}
