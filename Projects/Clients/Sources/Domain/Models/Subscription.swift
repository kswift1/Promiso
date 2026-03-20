import Foundation
import PromisoShared

// MARK: - Subscription Models

/// 구독 상품 유형
public enum SubscriptionProductType: String, Sendable, CaseIterable {
  case monthly
  case yearly
  case lifetime

  /// 현재 앱 환경에 맞는 Product ID
  /// - dev: com.promiso.dev.pro.monthly
  /// - stage: com.promiso.stage.pro.monthly
  /// - prod: com.promiso.pro.monthly
  public var productId: String {
    "\(Self.bundleIdPrefix).pro.\(rawValue)"
  }

  /// 모든 Product ID 목록 (StoreKit 조회용)
  public static var allProductIds: Set<String> {
    Set(allCases.map(\.productId))
  }

  /// Product ID로부터 타입 역매핑
  public init?(productId: String) {
    guard let match = Self.allCases.first(where: { $0.productId == productId }) else {
      return nil
    }
    self = match
  }

  /// 앱 번들 ID prefix (com.promiso / com.promiso.dev / com.promiso.stage)
  /// 테스트 환경에서도 안정적으로 동작하도록 알려진 번들 ID만 허용
  private static let bundleIdPrefix: String = {
    let knownPrefixes = ["com.promiso.dev", "com.promiso.stage", "com.promiso"]
    if let bundleId = Bundle.main.bundleIdentifier,
       knownPrefixes.contains(bundleId) {
      return bundleId
    }
    return "com.promiso"
  }()
}

extension SubscriptionProductType {
  public var displayName: String {
    switch self {
    case .monthly: return String(localized: "proPlan.product.monthly", bundle: LocalizedStrings.bundle)
    case .yearly: return String(localized: "proPlan.product.yearly", bundle: LocalizedStrings.bundle)
    case .lifetime: return String(localized: "proPlan.product.lifetime", bundle: LocalizedStrings.bundle)
    }
  }

  public var paywallDescription: String {
    switch self {
    case .monthly: return LocalizedStrings.ProPlan.productMonthlyDescription
    case .yearly: return LocalizedStrings.ProPlan.productYearlyDescription
    case .lifetime: return LocalizedStrings.ProPlan.productLifetimeDescription
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

/// Pro 엔타이틀먼트 부가 정보 (source, override 만료, 체험 상태)
public struct ProEntitlementInfo: Equatable, Sendable {
  public enum Source: String, Equatable, Sendable {
    case subscription
    case offerCode
    case coupon
    case admin
    case none
  }

  public var source: Source
  public var overrideExpiresAt: Date?
  public var isInTrialPeriod: Bool

  public init(source: Source, overrideExpiresAt: Date?, isInTrialPeriod: Bool) {
    self.source = source
    self.overrideExpiresAt = overrideExpiresAt
    self.isInTrialPeriod = isInTrialPeriod
  }

  public static let empty = ProEntitlementInfo(source: .none, overrideExpiresAt: nil, isInTrialPeriod: false)
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

/// 복원 결과 (JWS 토큰 포함, 서버 검증용)
public struct RestoreResult: Equatable, Sendable {
  public let jwsString: String?
  public let productId: String?
  public let localStatus: SubscriptionStatus

  public init(jwsString: String?, productId: String?, localStatus: SubscriptionStatus) {
    self.jwsString = jwsString
    self.productId = productId
    self.localStatus = localStatus
  }
}
