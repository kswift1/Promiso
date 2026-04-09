//
//  FAQClient.swift
//  Clients
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

/// FAQ 데이터를 Notion에서 가져오는 클라이언트
public struct FAQClient: Sendable {
  /// 활성화된 FAQ 목록 조회 (order 순 정렬)
  public var fetchFAQs: @Sendable () async throws -> [FAQModel]
}

// MARK: - Error

public enum FAQClientError: Error {
  case fetchFailed(statusCode: Int, message: String)
  case decodingFailed(String)
}

// MARK: - Test / Preview

extension FAQClient: TestDependencyKey {
  public static let previewValue = Self(
    fetchFAQs: { FAQModel.examples }
  )

  public static let testValue = Self(
    fetchFAQs: unimplemented("\(Self.self).fetchFAQs", placeholder: [])
  )
}

// MARK: - Session Cache

private actor FAQSessionCache {
  static let shared = FAQSessionCache()
  private var cached: [FAQModel]?
  private var activeTask: Task<[FAQModel], Error>?

  func getFAQs(fetch: @escaping @Sendable () async throws -> [FAQModel]) async throws -> [FAQModel] {
    if let cached {
      return cached
    }

    if let activeTask {
      return try await activeTask.value
    }

    let task = Task {
      defer { activeTask = nil }
      let faqs = try await fetch()
      cached = faqs
      return faqs
    }

    activeTask = task
    return try await task.value
  }
}

// MARK: - Live

extension FAQClient: DependencyKey {
  public static let liveValue: FAQClient = {
    let rustDataSource = FAQRustDataSource(
      api: RustAPIClient(getAuthToken: nil)
    )

    return Self(
      fetchFAQs: {
        try await FAQSessionCache.shared.getFAQs {
          do {
            return try await rustDataSource.fetchFAQs()
          } catch let error as RustAPIError {
            switch error {
            case .httpError(let statusCode):
              throw FAQClientError.fetchFailed(
                statusCode: statusCode,
                message: error.localizedDescription
              )
            case .serverError(let code, let message):
              throw FAQClientError.fetchFailed(statusCode: 0, message: "[\(code)] \(message)")
            default:
              throw FAQClientError.decodingFailed(error.localizedDescription)
            }
          } catch {
            throw FAQClientError.decodingFailed(error.localizedDescription)
          }
        }
      }
    )
  }()
}

// MARK: - Dependency Values

extension DependencyValues {
  public var faqClient: FAQClient {
    get { self[FAQClient.self] }
    set { self[FAQClient.self] = newValue }
  }
}
