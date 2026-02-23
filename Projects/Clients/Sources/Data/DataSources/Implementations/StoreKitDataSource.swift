import Foundation
import StoreKit

// MARK: - StoreKitDataSource

/// StoreKit 2 기반 구독/인앱 결제 데이터소스
final class StoreKitDataSource: Sendable {

  private static let productIds: Set<String> = [
    SubscriptionProductType.monthly.rawValue,
    SubscriptionProductType.yearly.rawValue,
    SubscriptionProductType.lifetime.rawValue
  ]

  // MARK: - Fetch Products

  func fetchProducts() async throws -> [SubscriptionProduct] {
    let storeProducts = try await Product.products(for: Self.productIds)
    return storeProducts.compactMap { mapProduct($0) }
      .sorted { $0.price < $1.price }
  }

  // MARK: - Purchase

  func purchase(productId: String) async throws -> SubscriptionStatus {
    let storeProducts = try await Product.products(for: [productId])
    guard let product = storeProducts.first else {
      throw SubscriptionError.productNotFound
    }

    let result = try await product.purchase()

    switch result {
    case .success(let verification):
      let transaction = try checkVerified(verification)
      await transaction.finish()
      return try await fetchCurrentStatus()

    case .userCancelled:
      throw SubscriptionError.purchaseCancelled

    case .pending:
      throw SubscriptionError.purchasePending

    @unknown default:
      throw SubscriptionError.unknown
    }
  }

  // MARK: - Restore

  func restore() async throws -> SubscriptionStatus {
    try await AppStore.sync()
    return try await fetchCurrentStatus()
  }

  // MARK: - Current Status

  func fetchCurrentStatus() async throws -> SubscriptionStatus {
    // 1. 평생 구매 확인
    for await result in Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }
      if transaction.productID == SubscriptionProductType.lifetime.rawValue {
        if transaction.revocationDate == nil {
          return .lifetime
        }
      }
    }

    // 2. 구독 상태 확인
    for await result in Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }
      let productId = transaction.productID
      guard productId == SubscriptionProductType.monthly.rawValue
              || productId == SubscriptionProductType.yearly.rawValue else {
        continue
      }

      if transaction.revocationDate != nil {
        return .revoked
      }

      if let expirationDate = transaction.expirationDate {
        if expirationDate > Date() {
          return .subscribed(expirationDate: expirationDate)
        } else {
          return .expired(expirationDate: expirationDate)
        }
      }
    }

    return .none
  }

  // MARK: - Status Stream

  func statusStream() -> AsyncStream<SubscriptionStatus> {
    AsyncStream { continuation in
      let task = Task {
        for await result in Transaction.updates {
          guard let _ = try? self.checkVerified(result) else { continue }
          if let status = try? await self.fetchCurrentStatus() {
            continuation.yield(status)
          }
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  // MARK: - Private Helpers

  private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
      throw SubscriptionError.verificationFailed
    case .verified(let safe):
      return safe
    }
  }

  private func mapProduct(_ product: Product) -> SubscriptionProduct? {
    guard let type = SubscriptionProductType(rawValue: product.id) else { return nil }
    return SubscriptionProduct(
      id: product.id,
      type: type,
      displayName: product.displayName,
      description: product.description,
      displayPrice: product.displayPrice,
      price: product.price
    )
  }
}

// MARK: - SubscriptionError

public enum SubscriptionError: Error, Equatable, LocalizedError {
  case productNotFound
  case purchaseCancelled
  case purchasePending
  case verificationFailed
  case unknown

  public var errorDescription: String? {
    switch self {
    case .productNotFound:
      return "상품을 찾을 수 없습니다."
    case .purchaseCancelled:
      return "구매가 취소되었습니다."
    case .purchasePending:
      return "구매 승인 대기 중입니다."
    case .verificationFailed:
      return "구매 검증에 실패했습니다."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}
