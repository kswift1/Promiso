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

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // MARK: - 헤더
          headerSection

          // MARK: - 현재 플랜 정보
          currentPlanSection

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

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 16) {
        // 아이콘
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 80, height: 80)

          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.white)
        }

        // 타이틀
        Text("Promiso Pro 이용 중")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)

        // 감사 메시지
        Text("프로 플랜을 이용해 주셔서 감사합니다!")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
      }
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

          Divider()
            .background(Color.white.opacity(0.12))

          // 만료일 (구독형인 경우만)
          if case .subscribed(let expirationDate) = store.subscriptionStatus,
             let date = expirationDate {
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

    // MARK: - Manage Subscription Section

    @available(iOS 15.0, *)
    @ViewBuilder
    private var manageSubscriptionSection: some View {
      VStack(spacing: 12) {
        Button {
          store.send(.view(.manageSubscriptionTapped))
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
          isPresented: Binding(
            get: { store.showManageView },
            set: { if !$0 { store.send(.view(.dismissManageView)) } }
          )
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
            expirationDate: Date().addingTimeInterval(30 * 24 * 3600)
          )
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
