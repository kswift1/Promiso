import Foundation

// MARK: - Subscription Models

/// 구독 상품 유형
public enum SubscriptionProductType: String, Sendable {
  case monthly = "com.promiso.pro.monthly"
  case yearly = "com.promiso.pro.yearly"
  case lifetime = "com.promiso.pro.lifetime"
}

extension SubscriptionProductType {
  public var displayName: String {
    switch self {
    case .monthly: return "월간"
    case .yearly: return "연간"
    case .lifetime: return "평생"
    }
  }
}

/// 구독 상품 정보
public struct SubscriptionProduct: Equatable, Sendable, Identifiable {
  public let id: String
  public let type: SubscriptionProductType
  public let displayName: String
  public let description: String
  public let displayPrice: String
  public let price: Decimal
  public let introductoryOffer: IntroductoryOffer?

  public init(id: String, type: SubscriptionProductType, displayName: String, description: String, displayPrice: String, price: Decimal, introductoryOffer: IntroductoryOffer? = nil) {
    self.id = id
    self.type = type
    self.displayName = displayName
    self.description = description
    self.displayPrice = displayPrice
    self.price = price
    self.introductoryOffer = introductoryOffer
  }
}

/// 무료 체험 / 소개 할인 정보
public struct IntroductoryOffer: Equatable, Sendable {
  public let periodDays: Int
  public let displayPrice: String
  public let isFreeTrialOffer: Bool

  public init(periodDays: Int, displayPrice: String, isFreeTrialOffer: Bool) {
    self.periodDays = periodDays
    self.displayPrice = displayPrice
    self.isFreeTrialOffer = isFreeTrialOffer
  }
}

/// 구독 상태
public enum SubscriptionStatus: Equatable, Sendable {
  /// 구독 없음 (무료)
  case none
  /// 활성 구독
  case subscribed(productType: SubscriptionProductType?, expirationDate: Date?)
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

  public var planDisplayName: String? {
    switch self {
    case .subscribed(let productType, _):
      return productType?.displayName
    case .lifetime:
      return SubscriptionProductType.lifetime.displayName
    default:
      return nil
    }
  }
}

/// 구매 결과 (JWS 토큰 포함)
public struct PurchaseResult: Equatable, Sendable {
  public let jwsString: String
  public let localStatus: SubscriptionStatus

  public init(jwsString: String, localStatus: SubscriptionStatus) {
    self.jwsString = jwsString
    self.localStatus = localStatus
  }
}
