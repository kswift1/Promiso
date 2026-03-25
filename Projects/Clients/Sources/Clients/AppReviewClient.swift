import Foundation
import Dependencies
import DependenciesMacros
import PromisoShared
import StoreKit
import UIKit

// MARK: - Client

@DependencyClient
public struct AppReviewClient: Sendable {
  /// 앱 최초 실행일 기록 (이미 기록된 경우 무시)
  public var recordFirstLaunchIfNeeded: @Sendable () -> Void
  /// 세션 카운트 증가
  public var incrementSessionCount: @Sendable () -> Void
  /// 리뷰 요청 적격 여부 판단 (적격이면 요청일 기록 후 리뷰 요청)
  public var requestReviewIfEligible: @Sendable () async -> Void
}

// MARK: - Test / Preview

extension AppReviewClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension AppReviewClient: DependencyKey {
  private enum Eligibility {
    static let minDaysSinceFirstLaunch: TimeInterval = 7 * 24 * 3600
    static let minSessionCount = 3
    static let cooldownInterval: TimeInterval = 90 * 24 * 3600
  }

  public static let liveValue: AppReviewClient = {
    let defaults = UserDefaults.standard

    return AppReviewClient(
      recordFirstLaunchIfNeeded: {
        let key = AppConstants.UserDefaults.firstLaunchDate
        if defaults.double(forKey: key) == 0 {
          defaults.set(Date().timeIntervalSince1970, forKey: key)
        }
      },
      incrementSessionCount: {
        let key = AppConstants.UserDefaults.sessionCount
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
      },
      requestReviewIfEligible: {
        let now = Date()

        // 조건 1: 첫 실행 후 7일
        let firstLaunch = defaults.double(forKey: AppConstants.UserDefaults.firstLaunchDate)
        guard firstLaunch > 0,
              now.timeIntervalSince1970 - firstLaunch >= Eligibility.minDaysSinceFirstLaunch else {
          return
        }

        // 조건 2: 세션 3회 이상
        let sessions = defaults.integer(forKey: AppConstants.UserDefaults.sessionCount)
        guard sessions >= Eligibility.minSessionCount else { return }

        // 조건 3: 마지막 요청 후 90일
        let lastRequest = defaults.double(forKey: AppConstants.UserDefaults.lastReviewRequestDate)
        if lastRequest > 0 {
          guard now.timeIntervalSince1970 - lastRequest >= Eligibility.cooldownInterval else {
            return
          }
        }

        // 적격 → 요청일 기록 + 리뷰 요청
        defaults.set(now.timeIntervalSince1970, forKey: AppConstants.UserDefaults.lastReviewRequestDate)

        await MainActor.run {
          guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
          }
          SKStoreReviewController.requestReview(in: scene)
        }
      }
    )
  }()
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var appReviewClient: AppReviewClient {
    get { self[AppReviewClient.self] }
    set { self[AppReviewClient.self] = newValue }
  }
}
