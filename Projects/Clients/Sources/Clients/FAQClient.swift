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
  case fetchFailed
  case decodingFailed
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
    return Self(
      fetchFAQs: {
        let databaseId = AppConstants.App.notionFAQDatabaseId

        // API Key는 Info.plist 또는 환경변수에서 가져옴
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

        // Active가 true인 항목만 조회, Order 순 정렬
        let body: [String: Any] = [
          "filter": [
            "property": "Active",
            "checkbox": ["equals": true]
          ],
          "sorts": [
            ["property": "Order", "direction": "ascending"]
          ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
          throw FAQClientError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
          throw FAQClientError.decodingFailed
        }

        return results.compactMap { page -> FAQModel? in
          guard let id = page["id"] as? String,
                let properties = page["properties"] as? [String: Any]
          else {
            return nil
          }

          // Question (Title)
          guard let questionProp = properties["Question"] as? [String: Any],
                let titleArray = questionProp["title"] as? [[String: Any]],
                let firstTitle = titleArray.first,
                let question = firstTitle["plain_text"] as? String
          else {
            return nil
          }

          // Answer (Rich Text)
          var answer = ""
          if let answerProp = properties["Answer"] as? [String: Any],
             let richTextArray = answerProp["rich_text"] as? [[String: Any]] {
            answer = richTextArray.compactMap { $0["plain_text"] as? String }.joined()
          }

          // Category (Select)
          var category: String?
          if let categoryProp = properties["Category"] as? [String: Any],
             let select = categoryProp["select"] as? [String: Any] {
            category = select["name"] as? String
          }

          // Order (Number)
          var order = 0
          if let orderProp = properties["Order"] as? [String: Any],
             let number = orderProp["number"] as? Int {
            order = number
          }

          // Created Time
          var createdAt = Date()
          if let createdTime = page["created_time"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdTime) ?? Date()
          }

          return FAQModel(
            id: id,
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
