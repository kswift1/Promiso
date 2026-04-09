import Foundation
import os.log
import PromisoShared
import StoreKit

// MARK: - StoreKitDataSource

/// StoreKit 2 기반 구독/인앱 결제 데이터소스
final class StoreKitDataSource: Sendable {

  private static var productIds: Set<String> {
    SubscriptionProductType.allProductIds
  }

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
    AppLogger.subscription.debug("purchaseWithReceipt started: productId=\(productId)")
    let storeProducts = try await Product.products(for: [productId])
    AppLogger.subscription.debug("Products fetched: count=\(storeProducts.count)")
    guard let product = storeProducts.first else {
      AppLogger.subscription.error("Product not found for productId=\(productId)")
      throw SubscriptionError.productNotFound
    }

    AppLogger.subscription.debug("Calling product.purchase() for productId=\(product.id)")
    let result = try await product.purchase()
    AppLogger.subscription.debug("product.purchase() returned")

    switch result {
    case .success(let verification):
      let transaction = try checkVerified(verification)
      AppLogger.subscription.debug("Purchase success: transactionId=\(transaction.id), productID=\(transaction.productID), revoked=\(transaction.revocationDate != nil)")
      await transaction.finish()

      // JWS 토큰 추출
      let jwsString = verification.jwsRepresentation
      AppLogger.subscription.debug("JWS extracted: length=\(jwsString.count)")

      let status = try await fetchCurrentStatus()
      AppLogger.subscription.debug("fetchCurrentStatus result: \(String(describing: status))")
      return PurchaseResult(jwsString: jwsString, localStatus: status)

    case .userCancelled:
      AppLogger.subscription.debug("Purchase userCancelled")
      throw SubscriptionError.purchaseCancelled

    case .pending:
      AppLogger.subscription.debug("Purchase pending")
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

  func restoreWithReceipt() async throws -> RestoreResult {
    try await AppStore.sync()

    var lifetimeReceipt: (jwsString: String, productId: String)?
    var latestSubscriptionReceipt: (
      jwsString: String,
      productId: String,
      expirationDate: Date?
    )?

    for await result in StoreKit.Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }

      if transaction.productID == SubscriptionProductType.lifetime.productId {
        lifetimeReceipt = (
          jwsString: result.jwsRepresentation,
          productId: transaction.productID
        )
        continue
      }

      let isSubscription = transaction.productID == SubscriptionProductType.monthly.productId
        || transaction.productID == SubscriptionProductType.yearly.productId
      guard isSubscription else { continue }

      let currentExpiration = latestSubscriptionReceipt?.expirationDate ?? .distantPast
      let candidateExpiration = transaction.expirationDate ?? .distantPast

      if latestSubscriptionReceipt == nil || candidateExpiration > currentExpiration {
        latestSubscriptionReceipt = (
          jwsString: result.jwsRepresentation,
          productId: transaction.productID,
          expirationDate: transaction.expirationDate
        )
      }
    }

    let status = try await fetchCurrentStatus()
    if let lifetimeReceipt {
      return RestoreResult(
        jwsString: lifetimeReceipt.jwsString,
        productId: lifetimeReceipt.productId,
        localStatus: status
      )
    }
    if let latestSubscriptionReceipt {
      return RestoreResult(
        jwsString: latestSubscriptionReceipt.jwsString,
        productId: latestSubscriptionReceipt.productId,
        localStatus: status
      )
    }
    return RestoreResult(jwsString: nil, productId: nil, localStatus: status)
  }

  // MARK: - Current Status

  func fetchCurrentStatus() async throws -> SubscriptionStatus {
    AppLogger.subscription.debug("fetchCurrentStatus started")
    var lifetimeTransaction: StoreKit.Transaction?
    var latestSubscriptionTransaction: StoreKit.Transaction?

    // 단일 패스로 entitlements 수집
    for await result in StoreKit.Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }
      AppLogger.subscription.debug("Entitlement: productID=\(transaction.productID), revocationDate=\(String(describing: transaction.revocationDate)), expirationDate=\(String(describing: transaction.expirationDate))")

      if transaction.productID == SubscriptionProductType.lifetime.productId {
        lifetimeTransaction = transaction
      } else if transaction.productID == SubscriptionProductType.monthly.productId
                || transaction.productID == SubscriptionProductType.yearly.productId {
        latestSubscriptionTransaction = transaction
      }
    }

    // 1. Lifetime 판별
    if let lifetime = lifetimeTransaction {
      if lifetime.revocationDate != nil {
        AppLogger.subscription.debug("fetchCurrentStatus -> .revoked (lifetime revoked)")
        return .revoked
      }
      AppLogger.subscription.debug("fetchCurrentStatus -> .lifetime")
      return .lifetime
    }

    // 2. 구독 판별
    if let subscription = latestSubscriptionTransaction {
      if subscription.revocationDate != nil {
        AppLogger.subscription.debug("fetchCurrentStatus -> .revoked (subscription revoked)")
        return .revoked
      }

      if let expirationDate = subscription.expirationDate {
        if expirationDate > Date() {
          // Grace period 감지
          if let gracePeriodExpiration = try? await detectGracePeriod(for: subscription) {
            AppLogger.subscription.debug("fetchCurrentStatus -> .gracePeriod(expirationDate=\(gracePeriodExpiration))")
            return .gracePeriod(expirationDate: gracePeriodExpiration)
          }
          let productType = SubscriptionProductType(productId: subscription.productID)
          AppLogger.subscription.debug("fetchCurrentStatus -> .subscribed(productType=\(String(describing: productType)), expirationDate=\(expirationDate))")
          return .subscribed(productType: productType, expirationDate: expirationDate)
        } else {
          AppLogger.subscription.debug("fetchCurrentStatus -> .expired(expirationDate=\(expirationDate))")
          return .expired(expirationDate: expirationDate)
        }
      }
    }

    AppLogger.subscription.debug("fetchCurrentStatus -> .none")
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
    guard let type = SubscriptionProductType(productId: product.id) else { return nil }

    let introOffer: IntroductoryOffer? = product.subscription?.introductoryOffer.flatMap { offer in
      let periodDays: Int
      switch offer.period.unit {
      case .day: periodDays = offer.period.value
      case .week: periodDays = offer.period.value * 7
      case .month: periodDays = offer.period.value * 30
      case .year: periodDays = offer.period.value * 365
      @unknown default: periodDays = offer.period.value
      }
      return IntroductoryOffer(
        periodDays: periodDays,
        displayPrice: offer.displayPrice,
        isFreeTrialOffer: offer.paymentMode == .freeTrial
      )
    }

    return SubscriptionProduct(
      id: product.id,
      type: type,
      displayName: product.displayName,
      description: product.description,
      displayPrice: product.displayPrice,
      price: product.price,
      introductoryOffer: introOffer
    )
  }

  // MARK: - Purchase Date

  func fetchPurchaseDate() async -> Date? {
    for await result in StoreKit.Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }
      return transaction.originalPurchaseDate
    }
    return nil
  }

  /// 무료 체험 대상 여부 확인
  func checkIntroOfferEligibility() async -> Bool {
    let subscriptionProductIds: Set<String> = [
      SubscriptionProductType.monthly.productId,
      SubscriptionProductType.yearly.productId
    ]
    guard let products = try? await Product.products(for: subscriptionProductIds),
          let product = products.first,
          let subscription = product.subscription else {
      return false
    }
    return await subscription.isEligibleForIntroOffer
  }
}

// MARK: - SubscriptionError

public enum SubscriptionError: Error, Equatable, LocalizedError {
  case productNotFound
  case purchaseCancelled
  case purchasePending
  case verificationFailed
  case alreadyOwnedByOther
  case unknown

  public var errorDescription: String? {
    switch self {
    case .productNotFound:
      return LocalizedStrings.Error.subscriptionProductNotFound
    case .purchaseCancelled:
      return LocalizedStrings.Error.subscriptionPurchaseCancelled
    case .purchasePending:
      return LocalizedStrings.Error.subscriptionPurchasePending
    case .verificationFailed:
      return LocalizedStrings.Error.subscriptionVerificationFailed
    case .alreadyOwnedByOther:
      return "이 구독은 다른 계정에 연결되어 있습니다"
    case .unknown:
      return LocalizedStrings.Error.unknownError
    }
  }
}
