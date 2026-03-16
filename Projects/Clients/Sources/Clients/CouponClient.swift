import ComposableArchitecture
import FirebaseFunctions
import Foundation

// MARK: - Response Model

public struct CouponRedeemResult: Equatable, Sendable {
  public let durationDays: Int
  public let expiresAt: Date

  public init(durationDays: Int, expiresAt: Date) {
    self.durationDays = durationDays
    self.expiresAt = expiresAt
  }
}

// MARK: - Error

public enum CouponError: Error, Equatable, Sendable {
  case notFound
  case alreadyRedeemed
  case expired
  case unknown(String)

  public var localizedDescription: String {
    switch self {
    case .notFound: return "유효하지 않은 쿠폰 코드입니다"
    case .alreadyRedeemed: return "이미 사용된 쿠폰입니다"
    case .expired: return "만료된 쿠폰입니다"
    case .unknown(let msg): return msg
    }
  }
}

// MARK: - Client

@DependencyClient
public struct CouponClient: Sendable {
  public var redeemCoupon: @Sendable (_ code: String) async throws -> CouponRedeemResult
}

// MARK: - Test & Preview Values

extension CouponClient: TestDependencyKey {
  public static let testValue = Self(
    redeemCoupon: unimplemented("\(Self.self).redeemCoupon")
  )

  public static let previewValue = Self(
    redeemCoupon: { _ in
      try await Task.sleep(for: .seconds(1.0))
      return CouponRedeemResult(
        durationDays: 30,
        expiresAt: Date().addingTimeInterval(30 * 24 * 3600)
      )
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var couponClient: CouponClient {
    get { self[CouponClient.self] }
    set { self[CouponClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension CouponClient: DependencyKey {
  public static let liveValue: CouponClient = {
    let iso8601Formatter: ISO8601DateFormatter = {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return formatter
    }()
    let iso8601FormatterFallback = ISO8601DateFormatter()

    return Self(
      redeemCoupon: { code in
        let functions = DefaultFunctionsProvider().functions

        do {
          let result = try await functions.httpsCallable("redeemCoupon").call(["code": code])

          guard let data = result.data as? [String: Any],
                let durationDays = data["durationDays"] as? Int,
                let expiresAtString = data["expiresAt"] as? String,
                let expiresAt = iso8601Formatter.date(from: expiresAtString) ?? iso8601FormatterFallback.date(from: expiresAtString) else {
            throw CouponError.unknown("응답 형식이 올바르지 않습니다")
          }

          return CouponRedeemResult(durationDays: durationDays, expiresAt: expiresAt)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
          let code = FunctionsErrorCode(rawValue: error.code)
          switch code {
          case .notFound:
            throw CouponError.notFound
          case .alreadyExists:
            throw CouponError.alreadyRedeemed
          case .failedPrecondition:
            throw CouponError.expired
          default:
            throw CouponError.unknown(error.localizedDescription)
          }
        }
      }
    )
  }()
}
