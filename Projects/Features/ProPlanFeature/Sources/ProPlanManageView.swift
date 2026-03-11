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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
      }
      .auroraBackground()
      .navigationTitle("Pro 플랜")
      .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Current Plan Section

    @ViewBuilder
    private var currentPlanSection: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("구독 정보")
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(spacing: 12) {
          // 구독 상태
          HStack {
            Label {
              Text("상태")
                .font(.body)
                .foregroundStyle(Color.pmtext.secondary)
            } icon: {
              Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(statusColor)
            }

            Spacer()

            Text(statusText)
              .font(.body)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.primary)
          }

          // 플랜 종류
          if let planName = store.subscriptionStatus.planDisplayName {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Label {
                Text("플랜")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.secondary)
              } icon: {
                Image(systemName: "creditcard")
                  .font(.caption)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text("\(planName) 플랜")
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
                Text("시작일")
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
                Text("갱신일")
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
                Text("유예 기간 만료")
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
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Pro Features Section

    @ViewBuilder
    private var proFeaturesSection: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("Pro 전용 기능")
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(spacing: 0) {
          proFeatureRow(
            icon: "exclamationmark.triangle",
            title: "일정 충돌 감지",
            description: "겹치는 일정을 자동으로 감지"
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureRow(
            icon: "wand.and.stars",
            title: "AI 일정 추천",
            description: "최적의 일정 시간을 추천 (예정)"
          )

          Divider()
            .background(Color.white.opacity(0.12))

          proFeatureRow(
            icon: "chart.bar",
            title: "일정 통계",
            description: "일정 이행률 및 패턴 분석 (예정)"
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

            Text("Apple 구독 관리")
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
        Text("구독 관리, 취소 및 환불은 Apple 설정에서 가능합니다.")
          .font(.footnote)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 8)
      }
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
        return "활성"
      case .lifetime:
        return "평생 구독"
      case .gracePeriod:
        return "유예 기간"
      case .expired:
        return "만료됨"
      case .revoked:
        return "환불됨"
      case .none:
        return "없음"
      }
    }

    private static let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      formatter.locale = Locale(identifier: "ko_KR")
      return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
      Self.dateFormatter.string(from: date)
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
