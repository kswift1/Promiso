import ComposableArchitecture
import FirebaseAuth
import FirebaseFunctions
@preconcurrency import FirebaseFirestore
import Foundation
import StoreKit
import os.log
import PromisoShared

// MARK: - Client

@DependencyClient
public struct SubscriptionClient: Sendable {
  /// 구매 가능한 상품 목록 조회
  public var fetchProducts: @Sendable () async throws -> [SubscriptionProduct]

  /// 상품 구매
  public var purchase: @Sendable (_ productId: String) async throws -> SubscriptionStatus

  /// 구매 후 JWS 토큰을 포함한 결과 반환 (서버 검증용)
  public var purchaseWithReceipt: @Sendable (_ productId: String) async throws -> PurchaseResult

  /// 구매 복원
  public var restore: @Sendable () async throws -> SubscriptionStatus

  /// 구매 복원 후 JWS 토큰을 포함한 결과 반환 (서버 검증용)
  public var restoreWithReceipt: @Sendable () async throws -> RestoreResult

  /// 현재 구독 상태 조회
  public var fetchStatus: @Sendable () async throws -> SubscriptionStatus

  /// 서버에 구매 검증 요청
  public var verifyPurchase: @Sendable (_ transactionJWS: String, _ productId: String, _ forceTransfer: Bool) async throws -> SubscriptionStatus

  /// 무료 체험 대상 여부 확인
  public var checkIntroOfferEligibility: @Sendable () async -> Bool = { false }

  /// 통합 구독 상태 스트림 (Firestore 서버 우선 + StoreKit Transaction.updates 보조)
  /// Firestore가 SSOT — 서버가 부정 상태면 StoreKit 이벤트 무시
  public var unifiedStatusStream: @Sendable () -> AsyncStream<SubscriptionStatus> = { .finished }

  /// 최초 구매일 조회
  public var fetchPurchaseDate: @Sendable () async -> Date? = { nil }

  /// Pro 엔타이틀먼트 부가 정보 조회 (source, override 만료, 체험 상태)
  public var fetchEntitlementInfo: @Sendable () async throws -> ProEntitlementInfo = { .empty }

  /// StoreKit 기반 무료 체험 중 여부 확인
  public var checkTrialStatus: @Sendable () async -> Bool = { false }
}

// MARK: - Test & Preview Values

extension SubscriptionClient: TestDependencyKey {
  public static let testValue = Self(
    fetchProducts: unimplemented("\(Self.self).fetchProducts", placeholder: []),
    purchase: unimplemented("\(Self.self).purchase", placeholder: .none),
    purchaseWithReceipt: unimplemented("\(Self.self).purchaseWithReceipt", placeholder: PurchaseResult(jwsString: "", localStatus: .none)),
    restore: unimplemented("\(Self.self).restore", placeholder: .none),
    restoreWithReceipt: unimplemented("\(Self.self).restoreWithReceipt", placeholder: RestoreResult(jwsString: nil, productId: nil, localStatus: .none)),
    fetchStatus: unimplemented("\(Self.self).fetchStatus", placeholder: .none),
    verifyPurchase: unimplemented("\(Self.self).verifyPurchase", placeholder: .none),
    checkIntroOfferEligibility: unimplemented("\(Self.self).checkIntroOfferEligibility", placeholder: false),
    unifiedStatusStream: unimplemented("\(Self.self).unifiedStatusStream", placeholder: .finished),
    fetchPurchaseDate: unimplemented("\(Self.self).fetchPurchaseDate", placeholder: nil),
    fetchEntitlementInfo: unimplemented("\(Self.self).fetchEntitlementInfo", placeholder: .empty),
    checkTrialStatus: unimplemented("\(Self.self).checkTrialStatus", placeholder: false)
  )

  public static let previewValue = Self(
    fetchProducts: {
      try await Task.sleep(for: .seconds(0.5))
      return [
        SubscriptionProduct(
          id: SubscriptionProductType.monthly.productId,
          type: .monthly,
          displayName: SubscriptionProductType.monthly.displayName,
          description: SubscriptionProductType.monthly.paywallDescription,
          displayPrice: "₩3,900",
          price: 3900
        ),
        SubscriptionProduct(
          id: SubscriptionProductType.yearly.productId,
          type: .yearly,
          displayName: SubscriptionProductType.yearly.displayName,
          description: SubscriptionProductType.yearly.paywallDescription,
          displayPrice: "₩39,000",
          price: 39000
        ),
        SubscriptionProduct(
          id: SubscriptionProductType.lifetime.productId,
          type: .lifetime,
          displayName: SubscriptionProductType.lifetime.displayName,
          description: SubscriptionProductType.lifetime.paywallDescription,
          displayPrice: "₩59,000",
          price: 59000
        )
      ]
    },
    purchase: { _ in
      try await Task.sleep(for: .seconds(1.0))
      return .subscribed(productType: .monthly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600))
    },
    purchaseWithReceipt: { _ in
      try await Task.sleep(for: .seconds(1.0))
      return PurchaseResult(jwsString: "mock-jws-token", localStatus: .subscribed(productType: .monthly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600)))
    },
    restore: {
      try await Task.sleep(for: .seconds(0.5))
      return .none
    },
    restoreWithReceipt: {
      try await Task.sleep(for: .seconds(0.5))
      return RestoreResult(jwsString: nil, productId: nil, localStatus: .none)
    },
    fetchStatus: {
      return .none
    },
    verifyPurchase: { _, _, _ in
      try await Task.sleep(for: .seconds(1.0))
      return .subscribed(productType: .monthly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600))
    },
    checkIntroOfferEligibility: { true },
    unifiedStatusStream: {
      AsyncStream { continuation in
        continuation.yield(.none)
        continuation.finish()
      }
    },
    fetchPurchaseDate: { Date().addingTimeInterval(-90 * 24 * 3600) },
    fetchEntitlementInfo: { .empty },
    checkTrialStatus: { false }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var subscriptionClient: SubscriptionClient {
    get { self[SubscriptionClient.self] }
    set { self[SubscriptionClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension SubscriptionClient: DependencyKey {
  public static let liveValue: SubscriptionClient = {
    let dataSource = StoreKitDataSource()
    let remoteDataSource = SubscriptionRemoteDataSource()

    return Self(
      fetchProducts: {
        try await dataSource.fetchProducts()
      },
      purchase: { productId in
        try await dataSource.purchase(productId: productId)
      },
      purchaseWithReceipt: { productId in
        try await dataSource.purchaseWithReceipt(productId: productId)
      },
      restore: {
        try await dataSource.restore()
      },
      restoreWithReceipt: {
        try await dataSource.restoreWithReceipt()
      },
      fetchStatus: {
        try await remoteDataSource.fetchRemoteStatus()
      },
      verifyPurchase: { jwsString, productId, forceTransfer in
        try await verifyPurchaseOnServer(transactionJWS: jwsString, productId: productId, forceTransfer: forceTransfer)
      },
      checkIntroOfferEligibility: {
        await dataSource.checkIntroOfferEligibility()
      },
      unifiedStatusStream: {
        // Actor로 서버/StoreKit 상태 병합 시 공유 상태 보호
        actor StatusMerger {
          private var lastServerStatus: SubscriptionStatus?

          func updateServer(_ status: SubscriptionStatus) -> SubscriptionStatus {
            lastServerStatus = status
            return status
          }

          func filterStoreKit(_ status: SubscriptionStatus) -> SubscriptionStatus? {
            guard let server = lastServerStatus else {
              return nil
            }
            switch server {
            case .none, .expired, .revoked:
              return nil
            case .subscribed, .lifetime, .gracePeriod:
              // 서버가 Pro인데 StoreKit이 만료/취소면 무시 (서버 SSOT)
              guard status.isActive else {
                return nil
              }
              return status
            }
          }
        }

        let merger = StatusMerger()

        return AsyncStream { continuation in
          let task = Task {
            await withTaskGroup(of: Void.self) { group in
              // Firestore entitlements/{userId} listener (서버 합산 Pro 상태)
              group.addTask {
                for await status in remoteDataSource.subscribeToEntitlement() {
                  let merged = await merger.updateServer(status)
                  continuation.yield(merged)
                }
              }
              // StoreKit Transaction.updates (서버 상태 기준으로 필터링)
              group.addTask {
                for await status in dataSource.statusStream() {
                  if let filtered = await merger.filterStoreKit(status) {
                    continuation.yield(filtered)
                  }
                }
              }
              await group.waitForAll()
            }
            continuation.finish()
          }
          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      },
      fetchPurchaseDate: {
        await dataSource.fetchPurchaseDate()
      },
      fetchEntitlementInfo: {
        guard let uid = Auth.auth().currentUser?.uid else {
          return .empty
        }
        let db = Firestore.firestore()
        let snapshot = try await db.collection("entitlements").document(uid).getDocument()
        guard let data = snapshot.data() else {
          return .empty
        }
        return SubscriptionRemoteDataSource.parseEntitlement(from: data).1
      },
      checkTrialStatus: {
        for await result in StoreKit.Transaction.currentEntitlements {
          guard case .verified(let transaction) = result else { continue }
          if transaction.offerType == .introductory {
            return true
          }
        }
        return false
      }
    )
  }()

  private static let iso8601Formatter = ISO8601DateFormatter()

  private static func verifyPurchaseOnServer(transactionJWS: String, productId: String, forceTransfer: Bool = false) async throws -> SubscriptionStatus {
    AppLogger.subscription.debug("verifyPurchaseOnServer called: productId=\(productId), forceTransfer=\(forceTransfer)")
    let functions = DefaultFunctionsProvider().functions

    do {
      var callData: [String: Any] = [
        "transactionJWS": transactionJWS,
        "productId": productId,
      ]
      if forceTransfer {
        callData["forceTransfer"] = true
      }
      AppLogger.subscription.debug("Calling Firebase Function: verifyPurchase")
      let result = try await functions.httpsCallable("verifyPurchase").call(callData)

      guard let data = result.data as? [String: Any],
            let statusData = data["subscriptionStatus"] as? [String: Any],
            let statusString = statusData["status"] as? String else {
        throw SubscriptionError.verificationFailed
      }

      let expirationDateRaw = statusData["expirationDate"] as? String
      AppLogger.subscription.debug("Server response: status=\(statusString), expirationDate=\(expirationDateRaw ?? "nil")")

      let finalStatus: SubscriptionStatus
      switch statusString {
      case "subscribed":
        let expirationDate = expirationDateRaw.flatMap { iso8601Formatter.date(from: $0) }
        let productType = SubscriptionProductType(productId: productId)
        finalStatus = .subscribed(productType: productType, expirationDate: expirationDate)
      case "lifetime":
        finalStatus = .lifetime
      case "expired":
        let expirationDate = expirationDateRaw.flatMap { iso8601Formatter.date(from: $0) }
        finalStatus = .expired(expirationDate: expirationDate ?? .distantPast)
      case "gracePeriod":
        let expirationDate = expirationDateRaw.flatMap { iso8601Formatter.date(from: $0) } ?? .distantFuture
        finalStatus = .gracePeriod(expirationDate: expirationDate)
      case "revoked":
        finalStatus = .revoked
      default:
        finalStatus = .none
      }
      AppLogger.subscription.debug("Parsed SubscriptionStatus: \(String(describing: finalStatus))")
      return finalStatus
    } catch let error as NSError where error.domain == FunctionsErrorDomain {
      AppLogger.subscription.error("Firebase Function error: domain=\(error.domain), code=\(error.code), message=\(error.localizedDescription)")
      let code = FunctionsErrorCode(rawValue: error.code)
      if code == .alreadyExists {
        throw SubscriptionError.alreadyOwnedByOther
      }
      throw error
    }
  }
}
