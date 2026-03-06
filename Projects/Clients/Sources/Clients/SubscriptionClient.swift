import ComposableArchitecture
import Foundation
import FirebaseFunctions

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

  /// 현재 구독 상태 조회
  public var fetchStatus: @Sendable () async throws -> SubscriptionStatus

  /// 구독 상태 실시간 스트림
  public var statusStream: @Sendable () -> AsyncStream<SubscriptionStatus> = { .finished }

  /// 서버에 구매 검증 요청
  public var verifyPurchase: @Sendable (_ transactionJWS: String, _ productId: String) async throws -> SubscriptionStatus

  /// 무료 체험 대상 여부 확인
  public var checkIntroOfferEligibility: @Sendable () async -> Bool = { false }

  /// 통합 구독 상태 스트림 (StoreKit Transaction.updates + Firestore subscriptions/{userId} 병합)
  /// 앱 레벨에서 구독 상태 변경을 실시간 감지
  public var unifiedStatusStream: @Sendable () -> AsyncStream<SubscriptionStatus> = { .finished }
}

// MARK: - Test & Preview Values

extension SubscriptionClient: TestDependencyKey {
  public static let testValue = Self(
    fetchProducts: unimplemented("\(Self.self).fetchProducts", placeholder: []),
    purchase: unimplemented("\(Self.self).purchase", placeholder: .none),
    purchaseWithReceipt: unimplemented("\(Self.self).purchaseWithReceipt", placeholder: PurchaseResult(jwsString: "", localStatus: .none)),
    restore: unimplemented("\(Self.self).restore", placeholder: .none),
    fetchStatus: unimplemented("\(Self.self).fetchStatus", placeholder: .none),
    statusStream: unimplemented("\(Self.self).statusStream", placeholder: .finished),
    verifyPurchase: unimplemented("\(Self.self).verifyPurchase", placeholder: .none),
    checkIntroOfferEligibility: unimplemented("\(Self.self).checkIntroOfferEligibility", placeholder: false),
    unifiedStatusStream: unimplemented("\(Self.self).unifiedStatusStream", placeholder: .finished)
  )

  public static let previewValue = Self(
    fetchProducts: {
      try await Task.sleep(for: .seconds(0.5))
      return [
        SubscriptionProduct(id: "com.promiso.pro.monthly", type: .monthly, displayName: "월간 프로", description: "매월 자동 갱신", displayPrice: "₩2,900", price: 2900),
        SubscriptionProduct(id: "com.promiso.pro.yearly", type: .yearly, displayName: "연간 프로", description: "매년 자동 갱신 (월 ₩2,075)", displayPrice: "₩24,900", price: 24900),
        SubscriptionProduct(id: "com.promiso.pro.lifetime", type: .lifetime, displayName: "평생 프로", description: "한 번 결제, 영구 사용", displayPrice: "₩54,000", price: 54000)
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
    fetchStatus: {
      return .none
    },
    statusStream: {
      AsyncStream { continuation in
        continuation.yield(.none)
        continuation.finish()
      }
    },
    verifyPurchase: { _, _ in
      try await Task.sleep(for: .seconds(1.0))
      return .subscribed(productType: .monthly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600))
    },
    checkIntroOfferEligibility: { true },
    unifiedStatusStream: {
      AsyncStream { continuation in
        continuation.yield(.none)
        continuation.finish()
      }
    }
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
      fetchStatus: {
        try await dataSource.fetchCurrentStatus()
      },
      statusStream: {
        dataSource.statusStream()
      },
      verifyPurchase: { jwsString, productId in
        try await verifyPurchaseOnServer(transactionJWS: jwsString, productId: productId)
      },
      checkIntroOfferEligibility: {
        await dataSource.checkIntroOfferEligibility()
      },
      unifiedStatusStream: {
        AsyncStream { continuation in
          let task = Task {
            await withTaskGroup(of: Void.self) { group in
              // StoreKit Transaction.updates
              group.addTask {
                for await status in dataSource.statusStream() {
                  continuation.yield(status)
                }
              }
              // Firestore subscriptions/{userId} listener
              group.addTask {
                for await status in remoteDataSource.subscribeToStatus() {
                  continuation.yield(status)
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
      }
    )
  }()

  private static let iso8601Formatter = ISO8601DateFormatter()

  private static func verifyPurchaseOnServer(transactionJWS: String, productId: String) async throws -> SubscriptionStatus {
    let functions = DefaultFunctionsProvider().functions

    let result = try await functions.httpsCallable("verifyPurchase").call([
      "transactionJWS": transactionJWS,
      "productId": productId,
    ])

    guard let data = result.data as? [String: Any],
          let statusData = data["subscriptionStatus"] as? [String: Any],
          let statusString = statusData["status"] as? String else {
      throw SubscriptionError.verificationFailed
    }

    switch statusString {
    case "subscribed":
      let expirationString = statusData["expirationDate"] as? String
      let expirationDate = expirationString.flatMap { iso8601Formatter.date(from: $0) }
      let productType = SubscriptionProductType(rawValue: productId) ?? .monthly
      return .subscribed(productType: productType, expirationDate: expirationDate)
    case "lifetime":
      return .lifetime
    case "expired":
      let expirationString = statusData["expirationDate"] as? String
      let expirationDate = expirationString.flatMap { iso8601Formatter.date(from: $0) }
      return .expired(expirationDate: expirationDate ?? .distantPast)
    case "gracePeriod":
      let expirationString = statusData["expirationDate"] as? String
      let expirationDate = expirationString.flatMap { iso8601Formatter.date(from: $0) } ?? .distantFuture
      return .gracePeriod(expirationDate: expirationDate)
    case "revoked":
      return .revoked
    default:
      return .none
    }
  }
}
