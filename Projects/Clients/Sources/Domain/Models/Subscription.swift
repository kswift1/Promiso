import Foundation

// MARK: - Subscription Models

/// 구독 상품 유형
public enum SubscriptionProductType: String, Sendable {
  case monthly = "promiso_pro_monthly"
  case yearly = "promiso_pro_yearly"
  case lifetime = "promiso_pro_lifetime"
}

/// 구독 상품 정보
public struct SubscriptionProduct: Equatable, Sendable, Identifiable {
  public let id: String
  public let type: SubscriptionProductType
  public let displayName: String
  public let description: String
  public let displayPrice: String
  public let price: Decimal

  public init(id: String, type: SubscriptionProductType, displayName: String, description: String, displayPrice: String, price: Decimal) {
    self.id = id
    self.type = type
    self.displayName = displayName
    self.description = description
    self.displayPrice = displayPrice
    self.price = price
  }
}

/// 구독 상태
public enum SubscriptionStatus: Equatable, Sendable {
  /// 구독 없음 (무료)
  case none
  /// 활성 구독
  case subscribed(expirationDate: Date?)
  /// 평생 구매 완료
  case lifetime
  /// 만료됨
  case expired(expirationDate: Date)
  /// 갱신 대기 중 (Grace period)
  case gracePeriod(expirationDate: Date)
  /// 환불됨
  case revoked

  public var isActive: Bool {
    switch self {
    case .subscribed, .lifetime, .gracePeriod:
      return true
    case .none, .expired, .revoked:
      return false
    }
  }

  public var isPro: Bool { isActive }
}
