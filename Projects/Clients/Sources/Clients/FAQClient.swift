//
//  FAQClient.swift
//  Clients
//
//  Created by Claude on 2026-02-04.
//

import ComposableArchitecture
import FirebaseFirestore
import Foundation
import PromisoShared

// MARK: - Client

/// FAQ 데이터를 Firestore에서 가져오는 클라이언트
public struct FAQClient: Sendable {
  /// 활성화된 FAQ 목록 조회 (order 순 정렬)
  public var fetchFAQs: @Sendable () async throws -> [FAQModel]
}

// MARK: - Error

public enum FAQClientError: Error, LocalizedError {
  case fetchFailed
  case decodingFailed

  public var errorDescription: String? {
    switch self {
    case .fetchFailed:
      return "FAQ를 불러오는데 실패했습니다."
    case .decodingFailed:
      return "FAQ 데이터를 읽는데 실패했습니다."
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
    let db = Firestore.firestore()

    return Self(
      fetchFAQs: {
        let snapshot = try await db.collection("faqs")
          .whereField("isActive", isEqualTo: true)
          .order(by: "order", descending: false)
          .getDocuments()

        return snapshot.documents.compactMap { document -> FAQModel? in
          let data = document.data()
          guard
            let question = data["question"] as? String,
            let answer = data["answer"] as? String
          else {
            return nil
          }

          let category = data["category"] as? String
          let order = data["order"] as? Int ?? 0
          let isActive = data["isActive"] as? Bool ?? true
          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

          return FAQModel(
            id: document.documentID,
            question: question,
            answer: answer,
            category: category,
            order: order,
            isActive: isActive,
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
