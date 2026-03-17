//
//  ProPlanManageView.swift
//  ProPlanFeature
//
//  Created by Claude on 2026-02-24.
//

import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit
import SharedFeature
import StoreKit
import SwiftUI

// MARK: - ProPlan Manage View

extension ProPlan {

  /// 구독 관리 화면 - 이미 Pro 플랜인 경우 표시
  public struct ProPlanManageView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var showManageSheet = false

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 20) {
          // MARK: - Grace Period 배너 (최상단)
          if case .gracePeriod(let expirationDate) = store.subscriptionStatus {
            gracePeriodBanner(expirationDate: expirationDate)
          }

          // MARK: - Hero 카드
          heroCard

          // MARK: - 업셀 카드 (조건부)
          upsellCard

          // MARK: - Pro 전용 기능
          proFeaturesSection

          // MARK: - 구독 관리 버튼 (구독형만)
          if #available(iOS 15.0, *) {
            if isSubscriptionSource {
              manageSubscriptionSection
            }
          }

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack(spacing: 6) {
            ProBadge()
            Text("Pro 플랜 관리")
              .font(.headline)
          }
        }
      }
    }

    // MARK: - Hero Card

    @ViewBuilder
    private var heroCard: some View {
      let source = store.entitlementInfo.source

      if source == .coupon || source == .admin {
        overrideHeroCard
      } else if case .lifetime = store.subscriptionStatus, source != .coupon, source != .admin {
        lifetimeHeroCard
      } else {
        subscriptionHeroCard
      }
    }

    // 구독형 Hero (monthly/yearly)
    @ViewBuilder
    private var subscriptionHeroCard: some View {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .center, spacing: 8) {
          // Pro 뱃지 스타일 타이틀
          Text("PRO \(subscriptionBadgeText ?? "")")
            .font(.title3)
            .fontWeight(.heavy)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
              LinearGradient(
                colors: [Color.pmindigo.n500, Color.pmpurple.n500],
                startPoint: .leading,
                endPoint: .trailing
              ),
              in: Capsule()
            )

          if store.entitlementInfo.isInTrialPeriod {
            Text("무료 체험 중")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmindigo.n500)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.pmindigo.n500.opacity(0.12), in: Capsule())
          }
        }

        if case .subscribed(_, let expirationDate) = store.subscriptionStatus,
           let date = expirationDate {
          HStack(alignment: .center) {
            Text("\(formattedDate(date))에 갱신됩니다")
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)

            Spacer()

            let days = remainingDays(date)
            if days >= 0 {
              Text("D-\(days)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.pmindigo.n500)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.pmindigo.n500.opacity(0.12), in: Capsule())
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack(alignment: .trailing) {
          LinearGradient(
            colors: [Color.pmaurora.purple.opacity(0.3), Color.pmaurora.indigo.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          GeometryReader { geo in
            ResourceKitAsset.paywallHero.swiftUIImage
              .resizable()
              .scaledToFill()
              .frame(width: geo.size.height, height: geo.size.height)
              .opacity(0.25)
              .clipped()
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
      .compositingGroup()
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .staticGlassBackground(cornerRadius: 16)
    }

    // 평생 Hero
    @ViewBuilder
    private var lifetimeHeroCard: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("PRO 평생")
          .font(.title3)
          .fontWeight(.heavy)
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .leading,
              endPoint: .trailing
            ),
            in: Capsule()
          )

        Text("영구적으로 이용 가능합니다")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack(alignment: .trailing) {
          LinearGradient(
            colors: [Color.pmaurora.purple.opacity(0.3), Color.pmaurora.indigo.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          GeometryReader { geo in
            ResourceKitAsset.paywallHero.swiftUIImage
              .resizable()
              .scaledToFill()
              .frame(width: geo.size.height, height: geo.size.height)
              .opacity(0.25)
              .clipped()
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
      .compositingGroup()
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .staticGlassBackground(cornerRadius: 16)
    }

    // 쿠폰/어드민 Override Hero
    @ViewBuilder
    private var overrideHeroCard: some View {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .center, spacing: 8) {
          Text("PRO \(store.entitlementInfo.source == .coupon ? "쿠폰" : "관리자")")
            .font(.title3)
            .fontWeight(.heavy)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
              LinearGradient(
                colors: [Color.pmindigo.n500, Color.pmpurple.n500],
                startPoint: .leading,
                endPoint: .trailing
              ),
              in: Capsule()
            )

          Text("체험 중")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.pmindigo.n500.opacity(0.12), in: Capsule())
        }

        if let overrideExpiry = store.entitlementInfo.overrideExpiresAt {
          VStack(alignment: .leading, spacing: 8) {
            let totalDays = 30.0
            let remaining = Double(max(0, Calendar.current.dateComponents([.day], from: Date(), to: overrideExpiry).day ?? 0))
            let progress = min(1.0, remaining / totalDays)

            HStack {
              ProgressView(value: progress)
                .tint(Color.pmindigo.n500)

              Text("\(Int(remaining))일 남음")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(remaining <= 7 ? Color.pmwarning.n500 : Color.pmtext.secondary)
                .frame(minWidth: 60, alignment: .trailing)
            }

            Text("\(formattedDate(overrideExpiry)) 만료")
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack(alignment: .trailing) {
          LinearGradient(
            colors: [Color.pmaurora.purple.opacity(0.3), Color.pmaurora.indigo.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          GeometryReader { geo in
            ResourceKitAsset.paywallHero.swiftUIImage
              .resizable()
              .scaledToFill()
              .frame(width: geo.size.height, height: geo.size.height)
              .opacity(0.25)
              .clipped()
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
      .compositingGroup()
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .staticGlassBackground(cornerRadius: 16)
    }

    // MARK: - Grace Period 배너

    @ViewBuilder
    private func gracePeriodBanner(expirationDate: Date) -> some View {
      let days = remainingDays(expirationDate)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.body)
            .foregroundStyle(Color.pmwarning.n500)

          Text("결제 정보를 확인해주세요")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmtext.primary)
        }

        if days > 0 {
          Text("\(days)일 후 Pro 기능이 비활성화됩니다")
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        if #available(iOS 15.0, *) {
          Button {
            showManageSheet = true
          } label: {
            Text("결제 수단 업데이트")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmwarning.n500)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .manageSubscriptionsSheet(
            isPresented: $showManageSheet,
            subscriptionGroupID: "21947112"
          )
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.pmwarning.n500.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(Color.pmwarning.n500.opacity(0.3), lineWidth: 1)
      )
    }

    // MARK: - Upsell Card

    @ViewBuilder
    private var upsellCard: some View {
      let source = store.entitlementInfo.source

      if case .subscribed(let productType, _) = store.subscriptionStatus,
         productType == .monthly,
         source == .subscription || source == .none {
        // 월간 → 연간 업셀
        if let discount = yearlyDiscount {
          monthlyToYearlyUpsellCard(discount: discount)
        }
      } else if source == .coupon || source == .admin {
        // 쿠폰/어드민 → 구독 전환 유도
        couponToSubscriptionUpsellCard
      }
    }

    @ViewBuilder
    private func monthlyToYearlyUpsellCard(discount: Int) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "star.fill")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)

          Text("연간으로 전환하면 \(discount)% 절약")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmtext.primary)
        }

        if let yearlyProduct = store.products.first(where: { $0.type == .yearly }) {
          Text("연간 플랜: \(yearlyProduct.displayPrice) / 년")
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        let yearlyProduct = store.products.first(where: { $0.type == .yearly })

        Button {
          if let yearlyId = yearlyProduct?.id {
            store.send(.view(.productSelected(yearlyId)))
            store.send(.view(.purchaseTapped))
          }
        } label: {
          Text("연간 플랜으로 전환")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(yearlyProduct == nil || store.isPurchasing)
        .opacity(yearlyProduct == nil ? 0.5 : 1)
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    @ViewBuilder
    private var couponToSubscriptionUpsellCard: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)

          Text("구독으로 전환하면 계속 이용 가능")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmtext.primary)
        }

        Text("체험 기간이 끝나도 Pro 기능을 계속 사용하세요")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)

        let yearlyProduct = store.products.first(where: { $0.type == .yearly })

        Button {
          if let yearlyId = yearlyProduct?.id {
            store.send(.view(.productSelected(yearlyId)))
            store.send(.view(.purchaseTapped))
          }
        } label: {
          Text("구독 시작하기")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(yearlyProduct == nil || store.isPurchasing)
        .opacity(yearlyProduct == nil ? 0.5 : 1)
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    // MARK: - Pro Features Section

    @ViewBuilder
    private var proFeaturesSection: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text(LocalizedStrings.ProPlan.proFeatures)
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(spacing: 0) {
          proFeatureButton(
            icon: "calendar.badge.exclamationmark",
            iconColor: Color.pmwarning.n600,
            title: "일정 충돌 감지",
            description: "겹치는 일정을 자동으로 찾아줍니다",
            destination: .conflictThreshold
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureButton(
            icon: "sparkles",
            iconColor: Color.pmpurple.n500,
            title: "AI 데일리 브리핑",
            description: "매일 아침 오늘의 일정을 요약해줍니다",
            destination: .briefing
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureRow(
            icon: "location.fill",
            iconColor: Color.pmindigo.n500,
            title: "스마트 출발 알림",
            description: "교통수단별 최적 출발 시간을 알려줍니다"
          )
        }
        .adaptiveGlassCard()
      }
    }

    private func proFeatureButton(
      icon: String,
      iconColor: Color,
      title: String,
      description: String,
      destination: ProPlan.Feature.ProSettingDestination
    ) -> some View {
      Button {
        store.send(.view(.proSettingTapped(destination)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.body)
            .foregroundStyle(iconColor)
            .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.pmgray.n400)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    private func proFeatureRow(
      icon: String,
      iconColor: Color,
      title: String,
      description: String
    ) -> some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(iconColor)
          .frame(width: 24, height: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Text(description)
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        Spacer()

        Image(systemName: "checkmark.circle.fill")
          .font(.body)
          .foregroundStyle(Color.pmsuccess.n500)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }

    // MARK: - Manage Subscription Section

    @available(iOS 15.0, *)
    @ViewBuilder
    private var manageSubscriptionSection: some View {
      VStack(spacing: 12) {
        Button {
          showManageSheet = true
        } label: {
          HStack {
            Image(systemName: "gearshape.fill")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)

            Text(LocalizedStrings.ProPlan.manageAppleSubscription)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Image(systemName: "arrow.up.right")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n400)
          }
          .padding(16)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .adaptiveGlassCard()
        .manageSubscriptionsSheet(
          isPresented: $showManageSheet,
          subscriptionGroupID: "21947112"
        )

        // 안내 텍스트
        Text(LocalizedStrings.ProPlan.manageHelpText)
          .font(.footnote)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 8)
      }
    }

    // MARK: - Helpers

    private var isSubscriptionSource: Bool {
      let source = store.entitlementInfo.source
      return source == .subscription || source == .none
    }

    private var subscriptionBadgeText: String? {
      switch store.subscriptionStatus {
      case .subscribed(let productType, _):
        return productType?.displayName
      default:
        return nil
      }
    }

    private func formattedDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      formatter.locale = LocaleManager.appLocale
      return formatter.string(from: date)
    }

    private func remainingDays(_ date: Date) -> Int {
      Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }

    private var yearlyDiscount: Int? {
      guard
        let monthlyPrice = store.products.first(where: { $0.type == .monthly })?.price,
        let yearlyPrice = store.products.first(where: { $0.type == .yearly })?.price,
        monthlyPrice > 0
      else { return nil }
      let annualMonthly = monthlyPrice * 12
      let discountDecimal = ((annualMonthly - yearlyPrice) * 100) / annualMonthly
      let discount = NSDecimalNumber(decimal: discountDecimal).intValue
      return discount > 0 ? discount : nil
    }
  }
}

// MARK: - Preview

#Preview("Manage - Subscribed (Yearly)") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: {
          var state = ProPlan.Feature.State(
            subscriptionStatus: .subscribed(
              productType: .yearly,
              expirationDate: Date().addingTimeInterval(31 * 24 * 3600)
            ),
            purchaseDate: Date().addingTimeInterval(-335 * 24 * 3600)
          )
          state.entitlementInfo = ProEntitlementInfo(
            source: .subscription,
            overrideExpiresAt: nil,
            isInTrialPeriod: false
          )
          return state
        }()
      ) {
        ProPlan.Feature()
      }
    )
  }
}

#Preview("Manage - Subscribed (Monthly)") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: {
          var state = ProPlan.Feature.State(
            products: [
              SubscriptionProduct(
                id: "com.promiso.pro.monthly",
                type: .monthly,
                displayName: "월간",
                description: "",
                displayPrice: "₩3,900",
                price: 3900
              ),
              SubscriptionProduct(
                id: "com.promiso.pro.yearly",
                type: .yearly,
                displayName: "연간",
                description: "",
                displayPrice: "₩29,900",
                price: 29900
              )
            ],
            subscriptionStatus: .subscribed(
              productType: .monthly,
              expirationDate: Date().addingTimeInterval(20 * 24 * 3600)
            ),
            purchaseDate: Date().addingTimeInterval(-10 * 24 * 3600)
          )
          state.entitlementInfo = ProEntitlementInfo(
            source: .subscription,
            overrideExpiresAt: nil,
            isInTrialPeriod: false
          )
          return state
        }()
      ) {
        ProPlan.Feature()
      }
    )
  }
}

#Preview("Manage - Lifetime") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: ProPlan.Feature.State(
          subscriptionStatus: .lifetime
        )
      ) {
        ProPlan.Feature()
      }
    )
  }
}

#Preview("Manage - Grace Period") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: ProPlan.Feature.State(
          subscriptionStatus: .gracePeriod(
            expirationDate: Date().addingTimeInterval(5 * 24 * 3600)
          )
        )
      ) {
        ProPlan.Feature()
      }
    )
  }
}

#Preview("Manage - Coupon") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: {
          var state = ProPlan.Feature.State(
            subscriptionStatus: .subscribed(
              productType: .monthly,
              expirationDate: Date().addingTimeInterval(15 * 24 * 3600)
            )
          )
          state.entitlementInfo = ProEntitlementInfo(
            source: .coupon,
            overrideExpiresAt: Date().addingTimeInterval(15 * 24 * 3600),
            isInTrialPeriod: true
          )
          return state
        }()
      ) {
        ProPlan.Feature()
      }
    )
  }
}

#Preview("Manage - Admin") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: {
          var state = ProPlan.Feature.State(
            subscriptionStatus: .lifetime
          )
          state.entitlementInfo = ProEntitlementInfo(
            source: .admin,
            overrideExpiresAt: Date().addingTimeInterval(30 * 24 * 3600),
            isInTrialPeriod: false
          )
          return state
        }()
      ) {
        ProPlan.Feature()
      }
    )
  }
}
