import ComposableArchitecture
import Foundation

// MARK: - Client

@DependencyClient
public struct SubscriptionClient: Sendable {
  /// 구매 가능한 상품 목록 조회
  public var fetchProducts: @Sendable () async throws -> [SubscriptionProduct]

  /// 상품 구매
  public var purchase: @Sendable (_ productId: String) async throws -> SubscriptionStatus

  /// 구매 복원
  public var restore: @Sendable () async throws -> SubscriptionStatus

  /// 현재 구독 상태 조회
  public var fetchStatus: @Sendable () async throws -> SubscriptionStatus

  /// 구독 상태 실시간 스트림
  public var statusStream: @Sendable () -> AsyncStream<SubscriptionStatus> = { .finished }
}

// MARK: - Test & Preview Values

extension SubscriptionClient: TestDependencyKey {
  public static let testValue = Self(
    fetchProducts: unimplemented("\(Self.self).fetchProducts", placeholder: []),
    purchase: unimplemented("\(Self.self).purchase", placeholder: .none),
    restore: unimplemented("\(Self.self).restore", placeholder: .none),
    fetchStatus: unimplemented("\(Self.self).fetchStatus", placeholder: .none),
    statusStream: unimplemented("\(Self.self).statusStream", placeholder: .finished)
  )

  public static let previewValue = Self(
    fetchProducts: {
      try await Task.sleep(for: .seconds(0.5))
      return [
        SubscriptionProduct(id: "promiso_pro_monthly", type: .monthly, displayName: "월간 프로", description: "매월 자동 갱신", displayPrice: "₩4,900", price: 4900),
        SubscriptionProduct(id: "promiso_pro_yearly", type: .yearly, displayName: "연간 프로", description: "매년 자동 갱신", displayPrice: "₩39,000", price: 39000),
        SubscriptionProduct(id: "promiso_pro_lifetime", type: .lifetime, displayName: "평생 프로", description: "한 번 결제, 영구 사용", displayPrice: "₩99,000", price: 99000)
      ]
    },
    purchase: { _ in
      try await Task.sleep(for: .seconds(1.0))
      return .subscribed(expirationDate: Date().addingTimeInterval(30 * 24 * 3600))
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

    return Self(
      fetchProducts: {
        try await dataSource.fetchProducts()
      },
      purchase: { productId in
        try await dataSource.purchase(productId: productId)
      },
      restore: {
        try await dataSource.restore()
      },
      fetchStatus: {
        try await dataSource.fetchCurrentStatus()
      },
      statusStream: {
        dataSource.statusStream()
      }
    )
  }()
}
