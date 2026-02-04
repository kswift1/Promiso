//
//  AppConfigClient.swift
//  Clients
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Model

/// 앱 설정 정보 (버전 체크 등)
public struct AppConfigModel: Equatable, Sendable {
  public let forceUpdateVersion: String
  public let recommendedVersion: String

  public init(forceUpdateVersion: String, recommendedVersion: String) {
    self.forceUpdateVersion = forceUpdateVersion
    self.recommendedVersion = recommendedVersion
  }
}

/// 버전 체크 결과
public enum VersionCheckResult: Equatable, Sendable {
  case upToDate
  case forceUpdate(currentVersion: String, requiredVersion: String)
  case recommendUpdate(currentVersion: String, recommendedVersion: String)
}

// MARK: - Client

/// Notion에서 앱 설정 정보를 가져오는 클라이언트
public struct AppConfigClient: Sendable {
  /// 앱 설정 조회
  public var fetchConfig: @Sendable () async throws -> AppConfigModel
  /// 현재 앱 버전과 비교하여 업데이트 필요 여부 확인
  public var checkVersion: @Sendable () async -> VersionCheckResult
  /// 캐시 초기화 후 버전 체크 (앱스토어 복귀 시 사용)
  public var checkVersionForced: @Sendable () async -> VersionCheckResult
}

// MARK: - Error

public enum AppConfigClientError: Error, LocalizedError {
  case fetchFailed(statusCode: Int, message: String)
  case decodingFailed(String)
  case invalidConfiguration

  public var errorDescription: String? {
    switch self {
    case .fetchFailed:
      return "앱 설정을 불러오는데 실패했습니다."
    case .decodingFailed:
      return "앱 설정 데이터를 읽는데 실패했습니다."
    case .invalidConfiguration:
      return "앱 설정이 올바르지 않습니다."
    }
  }
}

// MARK: - Notion API Response Models

private struct NotionQueryResponse: Decodable {
  let results: [NotionPage]
}

private struct NotionPage: Decodable {
  let id: String
  let properties: NotionProperties
}

private struct NotionProperties: Decodable {
  let key: NotionTitle?
  let value: NotionRichText?

  enum CodingKeys: String, CodingKey {
    case key = "Key"
    case value = "Value"
  }
}

private struct NotionTitle: Decodable {
  let title: [NotionTextContent]
}

private struct NotionRichText: Decodable {
  let richText: [NotionTextContent]

  enum CodingKeys: String, CodingKey {
    case richText = "rich_text"
  }
}

private struct NotionTextContent: Decodable {
  let plainText: String

  enum CodingKeys: String, CodingKey {
    case plainText = "plain_text"
  }
}

// MARK: - Version Comparison

private extension String {
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
      AppConfigModel(forceUpdateVersion: "1.0.0", recommendedVersion: "1.0.0")
    },
    checkVersion: {
      .upToDate
    },
    checkVersionForced: {
      .upToDate
    }
  )

  public static let testValue = Self(
    fetchConfig: unimplemented("\(Self.self).fetchConfig", placeholder: AppConfigModel(forceUpdateVersion: "0.0.0", recommendedVersion: "0.0.0")),
    checkVersion: unimplemented("\(Self.self).checkVersion", placeholder: .upToDate),
    checkVersionForced: unimplemented("\(Self.self).checkVersionForced", placeholder: .upToDate)
  )
}

// MARK: - Live

extension AppConfigClient: DependencyKey {
  public static let liveValue: AppConfigClient = {
    let decoder = JSONDecoder()

    // 캐시된 설정 (한 세션에 한 번만 조회)
    actor ConfigCache {
      var cachedConfig: AppConfigModel?

      func get() -> AppConfigModel? { cachedConfig }
      func set(_ config: AppConfigModel) { cachedConfig = config }
      func clear() { cachedConfig = nil }
    }
    let cache = ConfigCache()

    @Sendable
    func fetchConfigFromNotion() async throws -> AppConfigModel {
      // 캐시 확인
      if let cached = await cache.get() {
        return cached
      }

      let databaseId = AppConstants.App.notionAppConfigDatabaseId
      let apiKey = Bundle.main.object(forInfoDictionaryKey: "NOTION_API_KEY") as? String

      guard let apiKey = apiKey,
            !apiKey.isEmpty,
            !databaseId.isEmpty
      else {
        return AppConfigModel(forceUpdateVersion: "0.0.0", recommendedVersion: "0.0.0")
      }

      guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query") else {
        throw AppConfigClientError.invalidConfiguration
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
      request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = "{}".data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw AppConfigClientError.fetchFailed(statusCode: 0, message: "Invalid response")
      }

      if httpResponse.statusCode != 200 {
        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AppConfigClientError.fetchFailed(statusCode: httpResponse.statusCode, message: errorBody)
      }

      let notionResponse: NotionQueryResponse
      do {
        notionResponse = try decoder.decode(NotionQueryResponse.self, from: data)
      } catch {
        throw AppConfigClientError.decodingFailed(error.localizedDescription)
      }

      // Key-Value 파싱
      var configDict: [String: String] = [:]
      for page in notionResponse.results {
        guard let key = page.properties.key?.title.first?.plainText,
              let value = page.properties.value?.richText.first?.plainText
        else { continue }
        configDict[key] = value
      }

      let config = AppConfigModel(
        forceUpdateVersion: configDict["forceUpdateVersion"] ?? "0.0.0",
        recommendedVersion: configDict["recommendedVersion"] ?? "0.0.0"
      )

      await cache.set(config)
      return config
    }

    return Self(
      fetchConfig: fetchConfigFromNotion,
      checkVersion: {
        let currentVersion = AppConstants.App.version

        do {
          let config = try await fetchConfigFromNotion()

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
      },
      checkVersionForced: {
        await cache.clear()
        let currentVersion = AppConstants.App.version

        do {
          let config = try await fetchConfigFromNotion()

          if currentVersion.isVersionLessThan(config.forceUpdateVersion) {
            return .forceUpdate(
              currentVersion: currentVersion,
              requiredVersion: config.forceUpdateVersion
            )
          }

          if currentVersion.isVersionLessThan(config.recommendedVersion) {
            return .recommendUpdate(
              currentVersion: currentVersion,
              recommendedVersion: config.recommendedVersion
            )
          }

          return .upToDate
        } catch {
          return .upToDate
        }
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
