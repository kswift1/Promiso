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
        VStack(spacing: 24) {
          // MARK: - 현재 플랜 정보
          currentPlanSection

          // MARK: - Pro 전용 기능
          proFeaturesSection

          // MARK: - 구독 관리 버튼
          if #available(iOS 15.0, *) {
            manageSubscriptionSection
          }

          // MARK: - 쿠폰 섹션
          couponSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.ProPlan.manageTitle)
      .navigationBarTitleDisplayMode(.large)
      .sheet(
        isPresented: Binding(
          get: { store.showCouponSheet },
          set: { if !$0 { store.send(.view(.couponSheetDismissed)) } }
        )
      ) {
        couponRedeemSheet
      }
    }

    // MARK: - Current Plan Section

    @ViewBuilder
    private var currentPlanSection: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text(LocalizedStrings.ProPlan.subscriptionInfo)
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(spacing: 12) {
          // 구독 상태
          HStack {
            Label {
              Text(LocalizedStrings.ProPlan.status)
                .font(.body)
                .foregroundStyle(Color.pmtext.secondary)
            } icon: {
              Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(statusColor)
            }

            Spacer()

            HStack(spacing: 6) {
              if store.entitlementInfo.isInTrialPeriod {
                Text("체험 중")
                  .font(.caption2)
                  .fontWeight(.semibold)
                  .foregroundStyle(Color.pmindigo.n500)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.pmindigo.n500.opacity(0.12), in: Capsule())
              }

              Text(statusText)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pmtext.primary)
            }
          }

          // 플랜 종류
          if let planName = store.subscriptionStatus.planDisplayName {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text(LocalizedStrings.ProPlan.plan)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "creditcard")
                  .font(.caption)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text(LocalizedStrings.ProPlan.planValue(planName))
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)
            }
          }

          // 구독 시작일
          if let purchaseDate = store.purchaseDate {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text(LocalizedStrings.ProPlan.startDate)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "calendar.badge.clock")
                  .font(.caption)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text(formattedDate(purchaseDate))
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)
            }
          }

          // 만료일 (구독형인 경우만)
          if case .subscribed(_, let expirationDate) = store.subscriptionStatus,
             let date = expirationDate {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text(LocalizedStrings.ProPlan.renewalDate)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "calendar")
                  .font(.caption)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text(formattedDate(date))
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)
            }
          }

          // Grace Period 안내
          if case .gracePeriod(let expirationDate) = store.subscriptionStatus {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text(LocalizedStrings.ProPlan.gracePeriodEnds)
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "exclamationmark.triangle")
                  .font(.caption)
                  .foregroundStyle(Color.pmwarning.n500)
              }

              Spacer()

              Text(formattedDate(expirationDate))
                .font(.body)
                .foregroundStyle(Color.pmwarning.n500)
            }
          }

          // Pro 유형 (source)
          if store.entitlementInfo.source != .none {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text("이용 유형")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: sourceIcon)
                  .font(.caption)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text(sourceText)
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)
            }
          }

          // Override 만료일
          if let overrideExpiry = store.entitlementInfo.overrideExpiresAt,
             store.entitlementInfo.source == .coupon || store.entitlementInfo.source == .admin {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text("혜택 만료일")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "hourglass")
                  .font(.caption)
                  .foregroundStyle(overrideExpiryColor(overrideExpiry))
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDate(overrideExpiry))
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
                Text(remainingDaysText(overrideExpiry))
                  .font(.caption)
                  .foregroundStyle(overrideExpiryColor(overrideExpiry))
              }
            }
          }
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Pro Features Section

    @ViewBuilder
    private var proFeaturesSection: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text(LocalizedStrings.ProPlan.proFeatures)
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(spacing: 0) {
          proFeatureRow(
            icon: "exclamationmark.triangle",
            title: LocalizedStrings.ProPlan.featureConflictTitle,
            description: LocalizedStrings.ProPlan.featureConflictDescription
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureRow(
            icon: "wand.and.stars",
            title: LocalizedStrings.ProPlan.featureRecommendationTitle,
            description: LocalizedStrings.ProPlan.featureRecommendationDescription
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureRow(
            icon: "chart.bar",
            title: LocalizedStrings.ProPlan.featureStatsTitle,
            description: LocalizedStrings.ProPlan.featureStatsDescription
          )
        }
        .adaptiveGlassCard()
      }
    }

    private func proFeatureRow(icon: String, title: String, description: String) -> some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
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

    // MARK: - Coupon Section

    @ViewBuilder
    private var couponSection: some View {
      VStack(spacing: 12) {
        Button {
          store.send(.view(.couponTapped))
        } label: {
          HStack {
            Image(systemName: "ticket.fill")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)

            Text("쿠폰 코드 입력")
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n400)
          }
          .padding(16)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Coupon Redeem Sheet

    @ViewBuilder
    private var couponRedeemSheet: some View {
      NavigationStack {
        VStack(spacing: 24) {
          VStack(spacing: 8) {
            Image(systemName: "ticket.fill")
              .font(.system(size: 40))
              .foregroundStyle(Color.pmindigo.n500)

            Text("쿠폰 코드 입력")
              .font(.title2)
              .fontWeight(.bold)

            Text("Pro 플랜 체험 쿠폰 코드를 입력해주세요")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 20)

          TextField("쿠폰 코드", text: Binding(
            get: { store.couponCode },
            set: { store.send(.view(.couponCodeChanged($0))) }
          ))
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .padding(.horizontal, 20)

          if let message = store.couponResultMessage {
            Text(message)
              .font(.subheadline)
              .foregroundStyle(store.couponResultIsSuccess ? Color.pmsuccess.n500 : Color.pmerror.n500)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }

          Button {
            store.send(.view(.redeemCouponTapped))
          } label: {
            if store.isRedeemingCoupon {
              ProgressView()
                .tint(.white)
            } else {
              Text("적용하기")
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.pmindigo.n500)
          .disabled(
            store.couponCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || store.isRedeemingCoupon
          )
          .padding(.horizontal, 20)

          Spacer()
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("닫기") {
              store.send(.view(.couponSheetDismissed))
            }
          }
        }
      }
      .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var statusColor: Color {
      switch store.subscriptionStatus {
      case .subscribed, .lifetime:
        return Color.pmsuccess.n500
      case .gracePeriod:
        return Color.pmwarning.n500
      case .expired, .revoked:
        return Color.pmerror.n500
      case .none:
        return Color.pmgray.n400
      }
    }

    private var statusText: String {
      switch store.subscriptionStatus {
      case .subscribed:
        return LocalizedStrings.ProPlan.statusActive
      case .lifetime:
        return LocalizedStrings.ProPlan.statusLifetime
      case .gracePeriod:
        return LocalizedStrings.ProPlan.statusGracePeriod
      case .expired:
        return LocalizedStrings.ProPlan.statusExpired
      case .revoked:
        return LocalizedStrings.ProPlan.statusRefunded
      case .none:
        return LocalizedStrings.ProPlan.statusNone
      }
    }

    private func formattedDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      formatter.locale = LocaleManager.appLocale
      return formatter.string(from: date)
    }

    private var sourceIcon: String {
      switch store.entitlementInfo.source {
      case .subscription: return "creditcard"
      case .coupon: return "ticket"
      case .admin: return "person.badge.shield.checkmark"
      case .none: return "questionmark.circle"
      }
    }

    private var sourceText: String {
      switch store.entitlementInfo.source {
      case .subscription: return "구독"
      case .coupon: return "쿠폰"
      case .admin: return "관리자 부여"
      case .none: return "-"
      }
    }

    private func overrideExpiryColor(_ date: Date) -> Color {
      let remaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
      return remaining <= 7 ? Color.pmwarning.n500 : Color.pmindigo.n500
    }

    private func remainingDaysText(_ date: Date) -> String {
      let remaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
      if remaining <= 0 { return "만료됨" }
      return "\(remaining)일 남음"
    }
  }
}

// MARK: - Preview

#Preview("Manage - Subscribed") {
  NavigationStack {
    ProPlan.ProPlanManageView(
      store: Store(
        initialState: ProPlan.Feature.State(
          subscriptionStatus: .subscribed(
            productType: .yearly,
            expirationDate: Date().addingTimeInterval(30 * 24 * 3600)
          ),
          purchaseDate: Date().addingTimeInterval(-335 * 24 * 3600)
        )
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
            expirationDate: Date().addingTimeInterval(7 * 24 * 3600)
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
              expirationDate: Date().addingTimeInterval(20 * 24 * 3600)
            )
          )
          state.entitlementInfo = ProEntitlementInfo(
            source: .coupon,
            overrideExpiresAt: Date().addingTimeInterval(5 * 24 * 3600),
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
