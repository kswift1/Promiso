import Foundation
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
    var lifetimeTransaction: StoreKit.Transaction?
    var latestSubscriptionTransaction: StoreKit.Transaction?

    // 단일 패스로 entitlements 수집
    for await result in StoreKit.Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }

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
          let productType = SubscriptionProductType(productId: subscription.productID)
          return .subscribed(productType: productType, expirationDate: expirationDate)
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

  /// subscriptions/{userId} 문서 단건 조회
  /// - 문서 있음 → 서버 상태 반환
  /// - 문서 없음 → .none 반환
  /// - 조회 실패 → throw (caller가 기존 상태 유지)
  func fetchRemoteStatus() async throws -> SubscriptionStatus {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      return .none
    }

    // 1. entitlements read model 먼저 시도
    let entitlementRef = db.collection("entitlements").document(currentUserId)
    let entitlementSnapshot = try await entitlementRef.getDocument()

    if let data = entitlementSnapshot.data(),
       let hasPro = data["hasPro"] as? Bool {
      guard hasPro else { return .none }

      let source = data["source"] as? String ?? "none"
      let productIdStr = data["productId"] as? String
      let productType = productIdStr.flatMap { SubscriptionProductType(productId: $0) }
      let expirationDateStr = data["expirationDate"] as? String
      let expirationDate = expirationDateStr.flatMap { Self.parseISO8601($0) }

      switch source {
      case "subscription":
        let rawStatus = data["subscriptionStatus"] as? String ?? "subscribed"
        switch rawStatus {
        case "lifetime":
          return .lifetime
        case "gracePeriod":
          return .gracePeriod(expirationDate: expirationDate ?? .distantFuture)
        case "revoked":
          return .revoked
        case "expired":
          return .expired(expirationDate: expirationDate ?? .distantPast)
        default:
          return .subscribed(productType: productType, expirationDate: expirationDate)
        }
      case "override":
        let overrideExpiresAtStr = data["overrideExpiresAt"] as? String
        let overrideExpiresAt = overrideExpiresAtStr.flatMap { Self.parseISO8601($0) }
        return .subscribed(productType: nil, expirationDate: overrideExpiresAt)
      default:
        return .none
      }
    }

    // 2. Fallback: entitlements 문서 미존재 시 기존 subscriptions 직접 읽기
    let docRef = db.collection("subscriptions").document(currentUserId)
    let snapshot = try await docRef.getDocument()

    guard let data = snapshot.data() else {
      return .none
    }

    return Self.parseStatus(from: data)
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

  /// entitlementOverrides/{userId} 문서의 실시간 변경 스트림
  /// 쿠폰 또는 관리자 수동 부여에 의한 Pro 상태 감지
  func subscribeToOverrideStatus() -> AsyncStream<SubscriptionStatus> {
    AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        continuation.finish()
        return
      }

      let docRef = db.collection("entitlementOverrides").document(currentUserId)

      let listener = docRef.addSnapshotListener { snapshot, error in
        if error != nil { return }

        guard let data = snapshot?.data(),
              let isActive = data["isActive"] as? Bool,
              isActive else {
          continuation.yield(.none)
          return
        }

        if let expiresAtString = data["expiresAt"] as? String,
           let expiresAt = Self.parseISO8601(expiresAtString),
           expiresAt < Date() {
          continuation.yield(.expired(expirationDate: expiresAt))
          return
        }

        let expiresAtString = data["expiresAt"] as? String
        let expiresAt = expiresAtString.flatMap { Self.parseISO8601($0) }
        continuation.yield(.subscribed(productType: nil, expirationDate: expiresAt))
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  /// entitlements/{userId} 문서의 실시간 변경 스트림
  /// 서버에서 구독 + 오버라이드를 합산한 단일 Pro 판정 결과
  func subscribeToEntitlement() -> AsyncStream<SubscriptionStatus> {
    AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        continuation.finish()
        return
      }

      let docRef = db.collection("entitlements").document(currentUserId)

      let listener = docRef.addSnapshotListener { snapshot, error in
        if error != nil { return }

        guard let snapshot = snapshot else { return }

        // 문서가 아직 생성되지 않은 기존 유저 — yield하지 않고 대기
        guard snapshot.exists else { return }

        guard let data = snapshot.data(),
              let hasPro = data["hasPro"] as? Bool else {
          return
        }

        guard hasPro else {
          continuation.yield(.none)
          return
        }

        let source = data["source"] as? String ?? "none"

        switch source {
        case "subscription":
          let rawStatus = data["subscriptionStatus"] as? String ?? "subscribed"
          let productIdStr = data["productId"] as? String
          let productType = productIdStr.flatMap { SubscriptionProductType(productId: $0) }
          let expirationDateStr = data["expirationDate"] as? String
          let expirationDate = expirationDateStr.flatMap { Self.parseISO8601($0) }

          switch rawStatus {
          case "lifetime":
            continuation.yield(.lifetime)
          case "gracePeriod":
            continuation.yield(.gracePeriod(expirationDate: expirationDate ?? .distantFuture))
          default:
            continuation.yield(.subscribed(productType: productType, expirationDate: expirationDate))
          }

        case "override":
          let expiresAtString = data["overrideExpiresAt"] as? String
          let expiresAt = expiresAtString.flatMap { Self.parseISO8601($0) }
          continuation.yield(.subscribed(productType: nil, expirationDate: expiresAt))

        default:
          continuation.yield(.none)
        }
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  private static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601FormatterFallback = ISO8601DateFormatter()

  private static func parseISO8601(_ string: String) -> Date? {
    iso8601Formatter.date(from: string)
      ?? iso8601FormatterFallback.date(from: string)
  }

  private static func parseStatus(from data: [String: Any]) -> SubscriptionStatus {
    guard let statusString = data["status"] as? String else { return .none }

    let expirationDateString = data["expirationDate"] as? String
    let expirationDate = expirationDateString.flatMap { iso8601Formatter.date(from: $0) }

    switch statusString {
    case "subscribed":
      let productId = data["productId"] as? String
      let productType = productId.flatMap { SubscriptionProductType(productId: $0) }
      return .subscribed(productType: productType, expirationDate: expirationDate)
    case "lifetime":
      return .lifetime
    case "expired":
      return .expired(expirationDate: expirationDate ?? .distantPast)
    case "gracePeriod":
      return .gracePeriod(expirationDate: expirationDate ?? .distantFuture)
    case "revoked":
      return .revoked
    default:
      return .none
    }
  }
}
