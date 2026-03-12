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

private func localizedPreviewTime(hour: Int, minute: Int) -> String {
  var components = DateComponents()
  components.calendar = .autoupdatingCurrent
  components.timeZone = .autoupdatingCurrent
  components.year = 2026
  components.month = 1
  components.day = 1
  components.hour = hour
  components.minute = minute

  return (components.date ?? Date()).formatted(date: .omitted, time: .shortened)
}

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
      .analyticsScreen(
        name: AnalyticsClient.ScreenName.paywall.rawValue,
        class: "PaywallView"
      )
      .onAppear {
        store.send(.view(.paywallAppeared))
      }
      .onDisappear {
        store.send(.view(.paywallDisappeared))
      }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
      VStack(spacing: 16) {
        // 커피 아이콘
        Text("☕️")
          .font(.system(size: 48))

        VStack(spacing: 6) {
          Text(LocalizedStrings.ProPlan.heroTitleTop)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)

          // "AI 비서" 그라데이션 강조
          Text(LocalizedStrings.ProPlan.heroTitleBottom)
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

        Text(LocalizedStrings.ProPlan.heroSubtitle)
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
          problem: LocalizedStrings.ProPlan.paywallDepartureProblem,
          solution: LocalizedStrings.ProPlan.paywallDepartureSolution,
          previewContent: AnyView(DeparturePreviewView()),
          index: 0
        )

        FeatureCardView(
          icon: "calendar.badge.exclamationmark",
          iconColor: Color.pmwarning.n600,
          problem: LocalizedStrings.ProPlan.paywallConflictProblem,
          solution: LocalizedStrings.ProPlan.paywallConflictSolution,
          previewContent: AnyView(ConflictPreviewView()),
          index: 1
        )

        FeatureCardView(
          icon: "sparkles",
          iconColor: Color.pmpurple.n500,
          problem: LocalizedStrings.ProPlan.paywallBriefingProblem,
          solution: LocalizedStrings.ProPlan.paywallBriefingSolution,
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
          Text(LocalizedStrings.ProPlan.comparisonTitle)
            .font(.headline)
            .foregroundStyle(Color.pmtext.primary)

          Text(LocalizedStrings.ProPlan.comparisonSubtitle)
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: 0) {
          // 헤더
          HStack {
            Text(LocalizedStrings.ProPlan.comparisonFeatureLabel)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(LocalizedStrings.ProPlan.comparisonFreeLabel)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.secondary)
              .frame(width: 48)
            Text(LocalizedStrings.ProPlan.comparisonProLabel)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 48)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)

          Divider().padding(.horizontal, 16)

          // 공통 기능
          comparisonRow(LocalizedStrings.ProPlan.comparisonBasicSchedule, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonGroupSchedule, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonCalendar, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonWidget, free: true, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonLiveActivity, free: true, pro: true)

          Divider().padding(.horizontal, 16).padding(.vertical, 2)

          // Pro 전용
          comparisonRow(LocalizedStrings.ProPlan.comparisonDepartureAlert, free: false, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonConflictDetection, free: false, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonWeather, free: false, pro: true)
          comparisonRow(LocalizedStrings.ProPlan.comparisonDailyBriefing, free: false, pro: true)

          Divider().padding(.horizontal, 16).padding(.vertical, 2)

          // 추후 Pro 기능 안내
          HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 13))
              .foregroundStyle(Color.pmindigo.n500)
            Text(LocalizedStrings.ProPlan.comparisonComingSoon)
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
        if store.isLoadingProducts || (store.products.isEmpty && store.productsLoadErrorMessage == nil) {
          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 16)
              .fill(Color.pmgray.n700.opacity(0.3))
              .frame(height: 88)
          }
        } else if let productsLoadErrorMessage = store.productsLoadErrorMessage,
                  store.products.isEmpty {
          ProductsLoadErrorCardView(
            message: productsLoadErrorMessage,
            onRetry: { store.send(.view(.retryProductsLoadTapped)) }
          )
        } else {
          ForEach(store.products) { product in
            PricingCardView(
              product: product,
              isSelected: store.selectedProductId == product.id,
              isEligibleForIntroOffer: store.isEligibleForIntroOffer,
              monthlyPrice: store.products.first { $0.type == .monthly }?.price,
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
        Text(legalDisclaimerText)
          .font(.caption2)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)

        HStack(spacing: 16) {
          Link(LocalizedStrings.ProPlan.legalTerms, destination: AppConstants.App.termsOfServiceURL)
          Link(LocalizedStrings.ProPlan.legalPrivacy, destination: AppConstants.App.privacyPolicyURL)
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
            Text(isPricingExpanded ? LocalizedStrings.Common.collapse : LocalizedStrings.ProPlan.viewPlans)
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

        Text(showFreeTrialText ? LocalizedStrings.ProPlan.freeTrialTrustText(freeTrialDays) : LocalizedStrings.ProPlan.trustText)
          .font(.caption2)
          .foregroundStyle(Color.pmgray.n400)

        Button {
          store.send(.view(.restoreTapped))
        } label: {
          Text(LocalizedStrings.ProPlan.restorePurchases)
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
        return LocalizedStrings.ProPlan.lifetimePurchaseButton
      }
      if showFreeTrialText {
        return LocalizedStrings.ProPlan.freeTrialStart(freeTrialDays)
      }
      return LocalizedStrings.ProPlan.startButton
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

    private var selectedProduct: SubscriptionProduct? {
      guard let selectedId = store.selectedProductId else { return nil }
      return store.products.first(where: { $0.id == selectedId })
    }

    private var priceAndPeriodText: String {
      let price = selectedProduct?.displayPrice ?? ""
      switch selectedProduct?.type {
      case .monthly: return "\(price)\(LocalizedStrings.ProPlan.perMonth)"
      case .yearly: return "\(price)\(LocalizedStrings.ProPlan.perYear)"
      case .lifetime, .none: return price
      }
    }

    private var legalDisclaimerText: String {
      if showFreeTrialText {
        return LocalizedStrings.ProPlan.legalTrialDynamic(freeTrialDays, priceAndPeriodText)
      }

      if selectedProduct?.type == .lifetime {
        return LocalizedStrings.ProPlan.legalLifetimeDynamic(priceAndPeriodText)
      }

      return LocalizedStrings.ProPlan.legalSubscriptionDynamic(priceAndPeriodText)
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

// MARK: - Feature Card View

extension ProPlan {

  fileprivate struct ProductsLoadErrorCardView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
      VStack(spacing: 12) {
        Image(systemName: "wifi.exclamationmark")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(Color.pmwarning.n600)

        Text(message)
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.primary)
          .multilineTextAlignment(.center)

        Button(action: onRetry) {
          Text(LocalizedStrings.Common.retry)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
      }
      .padding(20)
      .frame(maxWidth: .infinity)
      .staticGlassBackground(cornerRadius: 16)
    }
  }

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
                Text(LocalizedStrings.Home.departureStart)
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmindigo.n400)
              }
              Text(LocalizedStrings.ProPlan.previewOrigin)
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
                Text(LocalizedStrings.Home.departureArrival)
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(Color.pmerror.n500)
              }
              Text(LocalizedStrings.ProPlan.previewDestination)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pmtext.primary)
            }
            .frame(maxWidth: .infinity)
          }

          // 약속 시간
          Text(verbatim: "🗓️ \(LocalizedStrings.ProPlan.previewStartsAt(localizedPreviewTime(hour: 14, minute: 0)))")
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
          icon: "car.fill",
          label: AvailableTransport.car.displayName,
          detail: LocalizedStrings.Home.transportApproxMinutes(15),
          departureTime: localizedPreviewTime(hour: 13, minute: 35),
          isSelected: true
        )
        transportCard(
          icon: "bus.fill",
          label: AvailableTransport.transit.displayName,
          detail: LocalizedStrings.Home.transportApproxMinutes(28),
          departureTime: localizedPreviewTime(hour: 13, minute: 22),
          isSelected: false
        )

        // 여유시간 + 알림 결과
        VStack(spacing: 6) {
          HStack {
            Text(LocalizedStrings.Home.transportBufferTime)
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
            Spacer()
            HStack(spacing: 3) {
              Text(LocalizedStrings.Home.minutesOnly(10))
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
            Text(LocalizedStrings.Home.departureAlertButton)
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 10))

          // 설명 텍스트
          Text(
            LocalizedStrings.Home.departureSelectionWithBuffer(
              AvailableTransport.car.displayName,
              localizedPreviewTime(hour: 13, minute: 25),
              10
            )
          )
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

            Text(LocalizedStrings.ProPlan.mockRainAlert)
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

            Text(LocalizedStrings.ProPlan.mockConflictTitle)
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
                Text(verbatim: "📌 \(LocalizedStrings.ProPlan.mockConflictExistingTitle)")
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
                Text(verbatim: "🍽️ \(LocalizedStrings.ProPlan.mockConflictNewTitle)")
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

          Text(LocalizedStrings.ProPlan.onboardingTodayBriefing)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          Spacer()
        }

        Divider()

        // 브리핑 본문 (유머러스 톤 예시)
        Text(LocalizedStrings.ProPlan.previewBriefingBody)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.primary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)

        Divider()

        // 커스텀 옵션 태그
        HStack(spacing: 6) {
          customTag(icon: "face.smiling", text: BriefingStyle.humorous.displayName)
          customTag(icon: "car.fill", text: LocalizedStrings.ProPlan.previewTransportIncluded(AvailableTransport.car.displayName))
          customTag(icon: "clock", text: LocalizedStrings.ProPlan.onboardingTodayBriefingTime)
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
    let monthlyPrice: Decimal?
    let onTap: () -> Void

    private var yearlyDiscountPercent: Int? {
      guard product.type == .yearly,
            let monthlyPrice,
            monthlyPrice > 0 else { return nil }
      let yearlyIfMonthly = monthlyPrice * 12
      let saving = yearlyIfMonthly - product.price
      guard saving > 0 else { return nil }
      let percent = (saving * 100) / yearlyIfMonthly
      return Int(ceil(NSDecimalNumber(decimal: percent).doubleValue))
    }

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

              if let discount = yearlyDiscountPercent {
                Text(LocalizedStrings.ProPlan.badgeDiscountPercent(discount))
                  .font(.system(size: 9, weight: .heavy))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.pmindigo.n500, in: Capsule())
              } else if product.type == .lifetime {
                Text(LocalizedStrings.ProPlan.badgeLimited)
                  .font(.system(size: 9, weight: .heavy))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.pmwarning.n500, in: Capsule())
              }
            }

            if product.type != .monthly, !product.description.isEmpty {
              Text(product.description)
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            if showFreeTrial {
              Text(LocalizedStrings.ProPlan.freeTrialStartsAfter(freeTrialDays))
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
              Text(LocalizedStrings.ProPlan.perMonth)
                .font(.caption)
                .foregroundStyle(Color.pmgray.n400)
            } else if product.type == .yearly {
              Text(LocalizedStrings.ProPlan.perYear)
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
            displayName: SubscriptionProductType.monthly.displayName,
            description: SubscriptionProductType.monthly.paywallDescription,
            displayPrice: "₩3,900",
            price: 3900
          ),
          SubscriptionProduct(
            id: SubscriptionProductType.yearly.productId,
            type: .yearly,
            displayName: SubscriptionProductType.yearly.displayName,
            description: SubscriptionProductType.yearly.paywallDescription,
            displayPrice: "₩29,000",
            price: 29000
          ),
          SubscriptionProduct(
            id: SubscriptionProductType.lifetime.productId,
            type: .lifetime,
            displayName: SubscriptionProductType.lifetime.displayName,
            description: SubscriptionProductType.lifetime.paywallDescription,
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
            displayName: SubscriptionProductType.yearly.displayName,
            description: SubscriptionProductType.yearly.paywallDescription,
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
