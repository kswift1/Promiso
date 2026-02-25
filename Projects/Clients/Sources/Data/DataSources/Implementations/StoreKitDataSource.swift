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

  // MARK: - Purchase with Receipt (서버 검증용)

  func purchaseWithReceipt(productId: String) async throws -> PurchaseResult {
    let storeProducts = try await Product.products(for: [productId])
    guard let product = storeProducts.first else {
      throw SubscriptionError.productNotFound
    }

    let result = try await product.purchase()

    switch result {
    case .success(let verification):
      let transaction = try checkVerified(verification)
      await transaction.finish()

      // JWS 토큰 추출
      let jwsString = verification.jwsRepresentation

      let status = try await fetchCurrentStatus()
      return PurchaseResult(jwsString: jwsString, localStatus: status)

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
    var lifetimeTransaction: StoreKit.Transaction?
    var latestSubscriptionTransaction: StoreKit.Transaction?

    // 단일 패스로 entitlements 수집
    for await result in StoreKit.Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }

      if transaction.productID == SubscriptionProductType.lifetime.rawValue {
        lifetimeTransaction = transaction
      } else if transaction.productID == SubscriptionProductType.monthly.rawValue
                || transaction.productID == SubscriptionProductType.yearly.rawValue {
        latestSubscriptionTransaction = transaction
      }
    }

    // 1. Lifetime 판별
    if let lifetime = lifetimeTransaction {
      if lifetime.revocationDate != nil {
        return .revoked
      }
      return .lifetime
    }

    // 2. 구독 판별
    if let subscription = latestSubscriptionTransaction {
      if subscription.revocationDate != nil {
        return .revoked
      }

      if let expirationDate = subscription.expirationDate {
        if expirationDate > Date() {
          // Grace period 감지
          if let gracePeriodExpiration = try? await detectGracePeriod(for: subscription) {
            return .gracePeriod(expirationDate: gracePeriodExpiration)
          }
          return .subscribed(expirationDate: expirationDate)
        } else {
          return .expired(expirationDate: expirationDate)
        }
      }
    }

    return .none
  }

  // MARK: - Grace Period Detection

  private func detectGracePeriod(for transaction: StoreKit.Transaction) async throws -> Date? {
    let products = try await Product.products(for: [transaction.productID])
    guard let product = products.first,
          let subscription = product.subscription else { return nil }

    let statuses = try await subscription.status
    for status in statuses {
      guard case .verified(let renewalInfo) = status.renewalInfo,
            case .verified(let transactionInfo) = status.transaction,
            transactionInfo.originalID == transaction.originalID else { continue }

      if let gracePeriodExpiration = renewalInfo.gracePeriodExpirationDate {
        return gracePeriodExpiration
      }
    }
    return nil
  }

  // MARK: - Status Stream

  func statusStream() -> AsyncStream<SubscriptionStatus> {
    AsyncStream { continuation in
      let task = Task {
        for await result in StoreKit.Transaction.updates {
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

// MARK: - SubscriptionRemoteDataSource

import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Firestore subscriptions/{userId} 문서의 실시간 변경을 감지하는 DataSource
/// Apple webhook → Firebase Functions → Firestore 업데이트를 클라이언트에서 수신
final class SubscriptionRemoteDataSource: Sendable {
  private let db: Firestore

  init(db: Firestore = Firestore.firestore()) {
    self.db = db
  }

  /// subscriptions/{userId} 문서의 실시간 변경 스트림
  func subscribeToStatus() -> AsyncStream<SubscriptionStatus> {
    AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        continuation.finish()
        return
      }

      let docRef = db.collection("subscriptions").document(currentUserId)

      let listener = docRef.addSnapshotListener { snapshot, error in
        if error != nil { return }

        guard let data = snapshot?.data() else {
          continuation.yield(.none)
          return
        }

        let status = Self.parseStatus(from: data)
        continuation.yield(status)
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  private static func parseStatus(from data: [String: Any]) -> SubscriptionStatus {
    guard let statusString = data["status"] as? String else { return .none }

    let expirationDateString = data["expirationDate"] as? String
    let expirationDate = expirationDateString.flatMap { ISO8601DateFormatter().date(from: $0) }

    switch statusString {
    case "subscribed":
      return .subscribed(expirationDate: expirationDate)
    case "lifetime":
      return .lifetime
    case "expired":
      return .expired(expirationDate: expirationDate ?? Date())
    case "gracePeriod":
      return .gracePeriod(expirationDate: expirationDate ?? Date())
    case "revoked":
      return .revoked
    default:
      return .none
    }
  }
}
