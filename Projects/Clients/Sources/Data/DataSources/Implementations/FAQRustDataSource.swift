import Foundation
import PromisoShared

private struct RustFAQItem: Decodable {
  let id: String
  let question: String
  let answer: String
  let category: String
  let order: Int
  let createdAt: String
  let updatedAt: String
}

public actor FAQRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  public func fetchFAQs() async throws -> [FAQModel] {
    let response: [RustFAQItem] = try await api.get("/api/v1/faq")
    return response.map { item in
      FAQModel(
        id: item.id,
        question: item.question,
        answer: item.answer,
        category: item.category.isEmpty ? nil : item.category,
        order: item.order,
        isActive: true,
        createdAt: parseFlexibleISO8601(item.createdAt) ?? Date()
      )
    }
  }
}

private func parseFlexibleISO8601(_ string: String) -> Date? {
  if let date = FAQRustDateParsers.fractional.date(from: string) {
    return date
  }
  if let date = FAQRustDateParsers.standard.date(from: string) {
    return date
  }
  return nil
}

private enum FAQRustDateParsers {
  static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
