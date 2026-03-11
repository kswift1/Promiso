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
              Text("요금제 보기")
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
              Text("Pro 플랜 시작!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

              Text("모든 프리미엄 기능을 이용할 수 있어요")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
            }

            // Pro 기능 가이드
            VStack(spacing: 12) {
              celebrationGuideRow(
                icon: "bell.badge.waveform",
                iconColor: Color.pmaurora.purple,
                title: "스마트 알림 브리핑",
                description: "일정 전 출발 시간, 날씨, 이동시간을 자동으로 알려드려요"
              )

              celebrationGuideRow(
                icon: "widget.small",
                iconColor: Color.pmindigo.n500,
                title: "AI 위젯",
                description: "홈 화면 위젯에서 다음 일정 정보를 한눈에 확인하세요"
              )

              celebrationGuideRow(
                icon: "calendar.badge.exclamationmark",
                iconColor: Color.pmwarning.n500,
                title: "일정 충돌 감지",
                description: "일정을 잡을 때 겹치는 일정이 있으면 미리 알려드려요"
              )
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            Button {
              store.send(.view(.dismissCelebration))
            } label: {
              Text("시작하기")
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

        Text("일정 하나도 놓치지 않는\n스마트한 일정 관리")
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
          title: "스마트 알림 브리핑",
          description: "날씨, 이동시간 포함 출발 알림을 자동으로 받으세요",
          previewContent: AnyView(NotificationMockView())
        )

        BenefitCardView(
          icon: "widget.small",
          iconColor: Color.pmindigo.n500,
          title: "AI 위젯",
          description: "홈 화면에서 날씨, 이동시간, 출발시간을 한눈에",
          previewContent: AnyView(WidgetMockView())
        )

        BenefitCardView(
          icon: "calendar.badge.exclamationmark",
          iconColor: Color.pmwarning.n500,
          title: "일정 충돌 감지",
          description: "겹치는 일정을 자동으로 찾아 알려드려요",
          previewContent: AnyView(ConflictMockView())
        )
      }
    }

    // MARK: - Comparison Section

    @ViewBuilder
    private var comparisonSection: some View {
      VStack(spacing: 16) {
        Text("Free vs Pro")
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 0) {
          comparisonHeaderRow()

          Divider().padding(.vertical, 4)

          comparisonRow("기본 일정 관리", free: true, pro: true)
          comparisonRow("그룹 일정", free: true, pro: true)
          comparisonRow("Live Activity", free: true, pro: true)

          Divider().padding(.vertical, 4)

          comparisonRow("스마트 알림 브리핑", free: false, pro: true)
          comparisonRow("AI 위젯", free: false, pro: true)
          comparisonRow("일정 충돌 감지", free: false, pro: true)
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    private func comparisonHeaderRow() -> some View {
      HStack {
        Spacer()
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Free")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(Color.pmtext.secondary)
          .frame(width: 50)
        Text("Pro")
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
        Text("언제든 취소 가능 · 약정 없음")
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
          Text(showFreeTrialText ? "\(freeTrialDays)일 무료 체험 시작" : "지금 시작하기")
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
        Text("구매 내역 복원")
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
          Text("출발 시간이에요!")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
        }
        Text("강남역 카페까지 15분 걸려요")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
        HStack(spacing: 12) {
          Label("비 예보", systemImage: "cloud.rain.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pminfo.n500)
          Label("1:45 출발 추천", systemImage: "clock.fill")
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
          Text("다음 일정")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
          Spacer()
          ProBadge()
        }
        Text("오후 2시 · 강남역 카페")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Divider()
        HStack(spacing: 12) {
          Label("22°", systemImage: "sun.max.fill")
            .font(.system(size: 11))
            .symbolRenderingMode(.multicolor)
          Label("15분", systemImage: "car.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          Label("1:30 출발", systemImage: "clock.fill")
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
          Text("'팀 회의'와 30분 겹쳐요")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.primary)
        }
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text("팀 회의")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
            Text("1:00 - 2:00")
              .font(.system(size: 10))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .padding(8)
          .background(Color.pmwarning.n500.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

          Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)

          VStack(alignment: .leading, spacing: 2) {
            Text("점심 일정")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmtext.primary)
            Text("1:30 - 3:00")
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
              Badge(text: "2개월 무료", color: Color.pmaurora.purple)
            } else if product.type == .lifetime {
              Badge(text: "평생", color: Color.pmaurora.pink)
            }
          }

          if showFreeTrial {
            Text("\(freeTrialDays)일 무료 후 \(product.description)")
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
              Text("/월")
                .font(.subheadline)
                .foregroundStyle(Color.pmgray.n400)
            } else if product.type == .yearly {
              Text("/년")
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
            id: "com.promiso.pro.monthly",
            type: .monthly,
            displayName: "월간 프로",
            description: "매월 자동 갱신",
            displayPrice: "₩2,900",
            price: 2900
          ),
          SubscriptionProduct(
            id: "com.promiso.pro.yearly",
            type: .yearly,
            displayName: "연간 프로",
            description: "매년 자동 갱신 (월 ₩2,075)",
            displayPrice: "₩24,900",
            price: 24900
          ),
          SubscriptionProduct(
            id: "com.promiso.pro.lifetime",
            type: .lifetime,
            displayName: "평생 프로",
            description: "한 번 결제, 영구 사용",
            displayPrice: "₩59,000",
            price: 59000
          )
        ],
        selectedProductId: "com.promiso.pro.yearly"
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
            id: "com.promiso.pro.yearly",
            type: .yearly,
            displayName: "연간 프로",
            description: "매년 자동 갱신 (월 ₩2,075)",
            displayPrice: "₩24,900",
            price: 24900
          )
        ],
        isPurchasing: true,
        selectedProductId: "com.promiso.pro.yearly"
      )
    ) {
      ProPlan.Feature()
    }
  )
}
