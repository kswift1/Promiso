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

  /// Paywall 화면 - 프로 플랜 구독 안내 및 구매
  public struct PaywallView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ZStack {
        ScrollView {
          VStack(spacing: 32) {
            // MARK: - 헤더
            headerSection

            // MARK: - 상품 카드
            if store.isLoadingProducts {
              loadingSection
            } else {
              productsSection
            }

            // MARK: - 구매 버튼
            purchaseButton

            // MARK: - 복원 링크
            restoreButton
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 32)
        }
        .auroraBackground()

        // MARK: - 로딩 오버레이
        if store.isPurchasing {
          loadingOverlay
        }
      }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 16) {
        ResourceKitAsset.paywallHero.swiftUIImage
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 260)

        // 타이틀
        Text("Promiso Pro")
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)

        // 설명
        Text("더 강력한 기능으로\n약속 관리를 업그레이드하세요")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
      }
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
            onTap: {
              store.send(.view(.productSelected(product.id)))
            }
          )
        }
      }
    }

    // MARK: - Purchase Button

    @ViewBuilder
    private var purchaseButton: some View {
      Button {
        store.send(.view(.purchaseTapped))
      } label: {
        HStack {
          Text("지금 시작하기")
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

// MARK: - Product Card View

extension ProPlan {

  /// 상품 카드 - 월간/연간/평생 플랜 표시
  private struct ProductCardView: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 12) {
          // 상단: 타입 뱃지
          HStack {
            Text(product.displayName)
              .font(.headline)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            // 인기/평생 뱃지
            if product.type == .yearly {
              Badge(text: "인기", color: Color.pmaurora.purple)
            } else if product.type == .lifetime {
              Badge(text: "평생", color: Color.pmaurora.pink)
            }
          }

          // 설명
          Text(product.description)
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)

          // 가격
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
