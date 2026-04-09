import ComposableArchitecture
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

  /// 로컬 StoreKit 상태만 조회 (AppStore.sync() 없이 Transaction.currentEntitlements 사용)
  public var fetchLocalStatus: @Sendable () async throws -> SubscriptionStatus

  /// 서버에 구매 검증 요청
  public var verifyPurchase: @Sendable (_ transactionJWS: String, _ productId: String, _ forceTransfer: Bool) async throws -> SubscriptionStatus

  /// 무료 체험 대상 여부 확인
  public var checkIntroOfferEligibility: @Sendable () async -> Bool = { false }

  /// 통합 구독 상태 스트림 (Rust entitlement authority + StoreKit Transaction.updates 보조)
  /// 서버가 부정 상태면 StoreKit 이벤트 무시
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
    fetchLocalStatus: unimplemented("\(Self.self).fetchLocalStatus", placeholder: .none),
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
    fetchLocalStatus: { .subscribed(productType: .yearly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600)) },
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
    let logger = Logger(subsystem: "com.promiso", category: "SubscriptionClient")
    let dataSource = StoreKitDataSource()
    let rustDataSource = SubscriptionRustDataSource(
      api: RustAPIClient()
    )

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
        return try await rustDataSource.fetchStatus()
      },
      fetchLocalStatus: {
        try await dataSource.fetchCurrentStatus()
      },
      verifyPurchase: { jwsString, productId, forceTransfer in
        return try await rustDataSource.verifyPurchase(
          transactionJWS: jwsString,
          productId: productId,
          forceTransfer: forceTransfer
        )
      },
      checkIntroOfferEligibility: {
        await dataSource.checkIntroOfferEligibility()
      },
      unifiedStatusStream: {
        actor StatusCache {
          private var lastStatus: SubscriptionStatus?

          func update(_ status: SubscriptionStatus) -> SubscriptionStatus? {
            guard lastStatus != status else { return nil }
            lastStatus = status
            return status
          }
        }

        let statusCache = StatusCache()

        return AsyncStream { continuation in
          let task = Task {
            do {
              let initialStatus = try await rustDataSource.fetchEntitlementStatus()
              if let statusToYield = await statusCache.update(initialStatus) {
                continuation.yield(statusToYield)
              }
            } catch {
              logger.error("Initial Rust entitlement status fetch failed: \(error.localizedDescription, privacy: .public)")
              if let fallbackStatus = await statusCache.update(.none) {
                continuation.yield(fallbackStatus)
              }
            }

            await withTaskGroup(of: Void.self) { group in
              // StoreKit 트랜잭션 변경 시 entitlement authority를 다시 조회
              group.addTask {
                for await _ in dataSource.statusStream() {
                  guard !Task.isCancelled else { return }
                  if let refreshedStatus = try? await rustDataSource.fetchEntitlementStatus(),
                     let statusToYield = await statusCache.update(refreshedStatus) {
                    continuation.yield(statusToYield)
                  }
                }
              }

              // Webhook/백엔드 상태 반영을 위해 주기적으로 entitlement 상태를 폴링
              group.addTask {
                while !Task.isCancelled {
                  try? await Task.sleep(for: .seconds(30))
                  guard !Task.isCancelled else { return }
                  if let refreshedStatus = try? await rustDataSource.fetchEntitlementStatus(),
                     let statusToYield = await statusCache.update(refreshedStatus) {
                    continuation.yield(statusToYield)
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
        return try await rustDataSource.fetchEntitlementInfo()
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
}
