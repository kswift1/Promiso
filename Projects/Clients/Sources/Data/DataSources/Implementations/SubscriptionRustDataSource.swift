import Foundation

private struct RustSubscriptionStatusResponse: Decodable {
  let status: String
  let productId: String?
  let expirationDate: Date?
}

private struct RustEntitlementResponse: Decodable {
  let hasPro: Bool
  let source: String
  let subscriptionStatus: String?
  let productId: String?
  let expirationDate: Date?
  let overrideActive: Bool
  let overrideExpiresAt: Date?
  let overrideType: String?
  let lastOfferType: Int?
}

private struct RustVerifyPurchaseBody: Encodable {
  let transactionJWS: String
  let productId: String
  let forceTransfer: Bool?
}

private struct RustVerifyPurchaseResponse: Decodable {
  let success: Bool
  let subscriptionStatus: RustSubscriptionStatusResponse
}

public actor SubscriptionRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  public func fetchStatus() async throws -> SubscriptionStatus {
    let response: RustSubscriptionStatusResponse = try await api.get("/api/v1/subscriptions/status")
    return Self.mapStatus(response)
  }

  public func fetchEntitlementInfo() async throws -> ProEntitlementInfo {
    let response: RustEntitlementResponse = try await api.get("/api/v1/subscriptions/entitlement")
    return Self.mapEntitlement(response).1
  }

  public func verifyPurchase(
    transactionJWS: String,
    productId: String,
    forceTransfer: Bool
  ) async throws -> SubscriptionStatus {
    do {
      let body = RustVerifyPurchaseBody(
        transactionJWS: transactionJWS,
        productId: productId,
        forceTransfer: forceTransfer ? true : nil
      )
      let response: RustVerifyPurchaseResponse = try await api.post(
        "/api/v1/subscriptions/verify-purchase",
        body: body
      )
      return Self.mapStatus(response.subscriptionStatus)
    } catch let error as RustAPIError {
      switch error {
      case .serverError(let code, _) where code == "already-exists":
        throw SubscriptionError.alreadyOwnedByOther
      default:
        throw error
      }
    }
  }

  public func fetchEntitlementStatus() async throws -> SubscriptionStatus {
    let response: RustEntitlementResponse = try await api.get("/api/v1/subscriptions/entitlement")
    return Self.mapEntitlement(response).0
  }

  private static func mapStatus(_ response: RustSubscriptionStatusResponse) -> SubscriptionStatus {
    let productType = response.productId.flatMap { SubscriptionProductType(productId: $0) }

    switch response.status {
    case "subscribed":
      return .subscribed(productType: productType, expirationDate: response.expirationDate)
    case "lifetime":
      return .lifetime
    case "expired":
      return .expired(expirationDate: response.expirationDate ?? .distantPast)
    case "gracePeriod":
      return .gracePeriod(expirationDate: response.expirationDate ?? .distantFuture)
    case "revoked":
      return .revoked
    default:
      return .none
    }
  }

  private static func mapEntitlement(
    _ response: RustEntitlementResponse
  ) -> (SubscriptionStatus, ProEntitlementInfo) {
    let productType = response.productId.flatMap { SubscriptionProductType(productId: $0) }

    let entitlementSource: ProEntitlementInfo.Source = {
      switch response.source {
      case "subscription":
        return response.lastOfferType == 3 ? .offerCode : .subscription
      case "override":
        return response.overrideType == "coupon_redeem" ? .coupon : .admin
      default:
        return .none
      }
    }()

    let entitlementInfo = ProEntitlementInfo(
      source: entitlementSource,
      overrideExpiresAt: response.overrideExpiresAt,
      isInTrialPeriod: false
    )

    if response.hasPro {
      switch response.source {
      case "subscription":
        switch response.subscriptionStatus {
        case "lifetime":
          return (.lifetime, entitlementInfo)
        case "gracePeriod":
          return (.gracePeriod(expirationDate: response.expirationDate ?? .distantFuture), entitlementInfo)
        default:
          return (.subscribed(productType: productType, expirationDate: response.expirationDate), entitlementInfo)
        }
      case "override":
        return (.subscribed(productType: nil, expirationDate: response.overrideExpiresAt), entitlementInfo)
      default:
        return (.subscribed(productType: productType, expirationDate: response.expirationDate), entitlementInfo)
      }
    }

    switch response.subscriptionStatus {
    case "expired":
      return (.expired(expirationDate: response.expirationDate ?? .distantPast), entitlementInfo)
    case "revoked":
      return (.revoked, entitlementInfo)
    default:
      return (.none, entitlementInfo)
    }
  }
}
