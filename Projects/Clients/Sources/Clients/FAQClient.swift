//
//  FAQClient.swift
//  Clients
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import FirebaseFunctions
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
  case invalidConfiguration
}

// MARK: - Firebase Functions Response Models

private struct GetFAQsResponse: Decodable {
  let faqs: [FAQItem]
}

private struct FAQItem: Decodable {
  let id: String
  let question: String
  let answer: String
  let category: String
  let order: Int
  let createdAt: String
  let updatedAt: String
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
    let functions = DefaultFunctionsProvider().functions
    let decoder = JSONDecoder()

    return Self(
      fetchFAQs: {
        try await FAQSessionCache.shared.getFAQs {
          let databaseId = AppConstants.App.notionFAQDatabaseId

        guard databaseId != "YOUR_DATABASE_ID_HERE" else {
          throw FAQClientError.invalidConfiguration
        }

        // Firebase Functions 호출 (Notion API 프록시)
        let resultData: Any
        do {
          let callable = functions.httpsCallable("getFAQs")
          let result = try await callable.call(["databaseId": databaseId])
          resultData = result.data
        } catch {
          let code = (error as NSError).code
          throw FAQClientError.fetchFailed(
            statusCode: code,
            message: error.localizedDescription
          )
        }

        guard let data = try? JSONSerialization.data(withJSONObject: resultData) else {
          throw FAQClientError.decodingFailed("Failed to serialize response data")
        }

        let response: GetFAQsResponse
        do {
          response = try decoder.decode(GetFAQsResponse.self, from: data)
        } catch {
          throw FAQClientError.decodingFailed(error.localizedDescription)
        }

        // ISO8601 날짜 포맷터 (Notion의 created_time 형식)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let faqs = response.faqs.map { item -> FAQModel in
          let createdAt = dateFormatter.date(from: item.createdAt) ?? Date()

          return FAQModel(
            id: item.id,
            question: item.question,
            answer: item.answer,
            category: item.category,
            order: item.order,
            isActive: true, // 서버에서 Active=true만 반환
            createdAt: createdAt
          )
        }

        return faqs
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
