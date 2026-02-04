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

public enum FAQClientError: Error, LocalizedError {
  case fetchFailed(statusCode: Int, message: String)
  case decodingFailed(String)
  case invalidConfiguration

  public var errorDescription: String? {
    switch self {
    case .fetchFailed:
      return "FAQ를 불러오는데 실패했습니다."
    case .decodingFailed:
      return "FAQ 데이터를 읽는데 실패했습니다."
    case .invalidConfiguration:
      return "FAQ 설정이 올바르지 않습니다."
    }
  }
}

// MARK: - Notion API Response Models

private struct NotionQueryResponse: Decodable {
  let results: [NotionPage]
}

private struct NotionPage: Decodable {
  let id: String
  let createdTime: String
  let properties: NotionProperties

  enum CodingKeys: String, CodingKey {
    case id
    case createdTime = "created_time"
    case properties
  }
}

private struct NotionProperties: Decodable {
  let question: NotionTitle?
  let answer: NotionRichText?
  let category: NotionSelect?
  let order: NotionNumber?

  enum CodingKeys: String, CodingKey {
    case question = "Question"
    case answer = "Answer"
    case category = "Category"
    case order = "Order"
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

private struct NotionSelect: Decodable {
  let select: NotionSelectOption?
}

private struct NotionSelectOption: Decodable {
  let name: String
}

private struct NotionNumber: Decodable {
  let number: Int?
}

private struct NotionQueryRequest: Encodable {
  let filter: NotionFilter
  let sorts: [NotionSort]
}

private struct NotionFilter: Encodable {
  let property: String
  let checkbox: NotionCheckbox
}

private struct NotionCheckbox: Encodable {
  let equals: Bool
}

private struct NotionSort: Encodable {
  let property: String
  let direction: String
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

// MARK: - Live

extension FAQClient: DependencyKey {
  public static let liveValue: FAQClient = {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    return Self(
      fetchFAQs: {
        let databaseId = AppConstants.App.notionFAQDatabaseId

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "NOTION_API_KEY") as? String,
              !apiKey.isEmpty,
              databaseId != "YOUR_DATABASE_ID_HERE"
        else {
          throw FAQClientError.invalidConfiguration
        }

        let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = NotionQueryRequest(
          filter: NotionFilter(
            property: "Active",
            checkbox: NotionCheckbox(equals: true)
          ),
          sorts: [NotionSort(property: "Order", direction: "ascending")]
        )

        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
          throw FAQClientError.fetchFailed(statusCode: 0, message: "Invalid response")
        }

        if httpResponse.statusCode != 200 {
          let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
          throw FAQClientError.fetchFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let notionResponse: NotionQueryResponse
        do {
          notionResponse = try decoder.decode(NotionQueryResponse.self, from: data)
        } catch {
          throw FAQClientError.decodingFailed(error.localizedDescription)
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return notionResponse.results.compactMap { page -> FAQModel? in
          guard let question = page.properties.question?.title.first?.plainText else {
            return nil
          }

          let answer = page.properties.answer?.richText.map(\.plainText).joined() ?? ""
          let category = page.properties.category?.select?.name
          let order = page.properties.order?.number ?? 0
          let createdAt = dateFormatter.date(from: page.createdTime) ?? Date()

          return FAQModel(
            id: page.id,
            question: question,
            answer: answer,
            category: category,
            order: order,
            isActive: true,
            createdAt: createdAt
          )
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
