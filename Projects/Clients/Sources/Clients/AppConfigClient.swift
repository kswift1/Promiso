//
//  AppConfigClient.swift
//  Clients
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import FirebaseRemoteConfig
import Foundation
import PromisoShared

// MARK: - Model

/// 버전 체크 결과
public enum VersionCheckResult: Equatable, Sendable {
  case upToDate
  case forceUpdate(currentVersion: String, requiredVersion: String)
  case recommendUpdate(currentVersion: String, recommendedVersion: String)
}

// MARK: - Client

/// Firebase Remote Config에서 앱 설정 정보를 가져오는 클라이언트
@DependencyClient
public struct AppConfigClient: Sendable {
  /// 앱 설정 조회
  public var fetchConfig: @Sendable () async throws -> AppConfigModel
  /// 현재 앱 버전과 비교하여 업데이트 필요 여부 확인
  public var checkVersion: @Sendable () async -> VersionCheckResult = { .upToDate }
  /// 캐시 초기화 후 버전 체크 (앱스토어 복귀 시 사용)
  public var checkVersionForced: @Sendable () async -> VersionCheckResult = { .upToDate }
}

// MARK: - Error

public enum AppConfigClientError: Error {
  case fetchFailed(String)
  case invalidVersion(String)
}

// MARK: - Remote Config Keys

private enum RemoteConfigKeys {
  static let forceUpdateVersion = "forceUpdateVersion"
  static let recommendedVersion = "recommendedVersion"
  static let appStoreURL = "appStoreURL"
  static let privacyPolicyURL = "privacyPolicyURL"
  static let termsOfServiceURL = "termsOfServiceURL"
  static let supportEmail = "supportEmail"
  static let notionFAQDatabaseId = "notionFAQDatabaseId"
}

// MARK: - Version Validation & Comparison

private extension String {
  /// 버전 문자열 검증 (x.y.z 형식)
  func isValidVersion() -> Bool {
    let pattern = #"^\d+\.\d+\.\d+$"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(self.startIndex..., in: self)
    return regex.firstMatch(in: self, range: range) != nil
  }

  /// 버전 문자열 비교 (예: "1.0.0" < "1.1.0")
  func isVersionLessThan(_ other: String) -> Bool {
    let lhs = self.split(separator: ".").compactMap { Int($0) }
    let rhs = other.split(separator: ".").compactMap { Int($0) }

    let maxCount = max(lhs.count, rhs.count)
    for i in 0..<maxCount {
      let l = i < lhs.count ? lhs[i] : 0
      let r = i < rhs.count ? rhs[i] : 0
      if l < r { return true }
      if l > r { return false }
    }
    return false
  }
}

// MARK: - Test / Preview

extension AppConfigClient: TestDependencyKey {
  public static let previewValue = Self(
    fetchConfig: {
      .defaultConfig
    },
    checkVersion: {
      .upToDate
    },
    checkVersionForced: {
      .upToDate
    }
  )

  public static let testValue = Self(
    fetchConfig: unimplemented("\(Self.self).fetchConfig", placeholder: .defaultConfig),
    checkVersion: unimplemented("\(Self.self).checkVersion", placeholder: .upToDate),
    checkVersionForced: unimplemented("\(Self.self).checkVersionForced", placeholder: .upToDate)
  )
}

// MARK: - Live

extension AppConfigClient: DependencyKey {
  public static let liveValue: AppConfigClient = {
    let remoteConfig = RemoteConfig.remoteConfig()

    // Remote Config 설정
    let settings = RemoteConfigSettings()
    #if DEBUG
    settings.minimumFetchInterval = 0  // 개발용: 즉시 fetch
    #else
    settings.minimumFetchInterval = 3600  // 프로덕션: 1시간
    #endif
    remoteConfig.configSettings = settings

    // 기본값 설정
    let defaults: [String: NSObject] = [
      RemoteConfigKeys.forceUpdateVersion: "0.0.0" as NSString,
      RemoteConfigKeys.recommendedVersion: "0.0.0" as NSString,
      RemoteConfigKeys.appStoreURL: AppConfigModel.defaultConfig.appStoreURL as NSString,
      RemoteConfigKeys.privacyPolicyURL: "https://www.notion.so/3029e497067580beb0aaf485a0dd4a02" as NSString,
      RemoteConfigKeys.termsOfServiceURL: "https://www.notion.so/3029e4970675802ab781e282bb92d63b" as NSString,
      RemoteConfigKeys.supportEmail: "kswen0203@icloud.com" as NSString,
      RemoteConfigKeys.notionFAQDatabaseId: "3029e4970675812ca3d6c852867858a2" as NSString
    ]
    remoteConfig.setDefaults(defaults)

    // 캐시된 설정 (한 세션에 한 번만 조회)
    actor ConfigCache {
      var cachedConfig: AppConfigModel?

      func get() -> AppConfigModel? { cachedConfig }
      func set(_ config: AppConfigModel) { cachedConfig = config }
      func clear() { cachedConfig = nil }
    }
    let cache = ConfigCache()

    @Sendable
    func fetchConfigFromRemoteConfig() async throws -> AppConfigModel {
      // 캐시 확인
      if let cached = await cache.get() {
        return cached
      }

      // Remote Config fetch
      do {
        let status = try await remoteConfig.fetchAndActivate()

        // 값 가져오기 (setDefaults에서 기본값 설정됨)
        let config = AppConfigModel(
          forceUpdateVersion: remoteConfig.configValue(forKey: RemoteConfigKeys.forceUpdateVersion).stringValue,
          recommendedVersion: remoteConfig.configValue(forKey: RemoteConfigKeys.recommendedVersion).stringValue,
          appStoreURL: remoteConfig.configValue(forKey: RemoteConfigKeys.appStoreURL).stringValue,
          privacyPolicyURL: remoteConfig.configValue(forKey: RemoteConfigKeys.privacyPolicyURL).stringValue,
          termsOfServiceURL: remoteConfig.configValue(forKey: RemoteConfigKeys.termsOfServiceURL).stringValue,
          supportEmail: remoteConfig.configValue(forKey: RemoteConfigKeys.supportEmail).stringValue,
          notionFAQDatabaseId: remoteConfig.configValue(forKey: RemoteConfigKeys.notionFAQDatabaseId).stringValue
        )

        await cache.set(config)
        return config
      } catch {
        // Fetch 실패 시 기본값 반환
        return .defaultConfig
      }
    }

    @Sendable
    func performVersionCheck(forcingFetch: Bool) async -> VersionCheckResult {
      if forcingFetch {
        await cache.clear()
      }

      do {
        let config = try await fetchConfigFromRemoteConfig()
        let currentVersion = AppConstants.App.version

        // 버전 검증
        guard config.forceUpdateVersion.isValidVersion(),
              config.recommendedVersion.isValidVersion() else {
          // 유효하지 않은 버전은 무시하고 업데이트 불필요로 처리
          return .upToDate
        }

        // 1. 강제 업데이트 체크
        if currentVersion.isVersionLessThan(config.forceUpdateVersion) {
          return .forceUpdate(
            currentVersion: currentVersion,
            requiredVersion: config.forceUpdateVersion
          )
        }

        // 2. 권장 업데이트 체크
        if currentVersion.isVersionLessThan(config.recommendedVersion) {
          return .recommendUpdate(
            currentVersion: currentVersion,
            recommendedVersion: config.recommendedVersion
          )
        }

        return .upToDate
      } catch {
        // 네트워크 오류 시 업데이트 체크 스킵
        return .upToDate
      }
    }

    return Self(
      fetchConfig: fetchConfigFromRemoteConfig,
      checkVersion: {
        await performVersionCheck(forcingFetch: false)
      },
      checkVersionForced: {
        await performVersionCheck(forcingFetch: true)
      }
    )
  }()
}

// MARK: - Dependency Values

extension DependencyValues {
  public var appConfigClient: AppConfigClient {
    get { self[AppConfigClient.self] }
    set { self[AppConfigClient.self] = newValue }
  }
}
