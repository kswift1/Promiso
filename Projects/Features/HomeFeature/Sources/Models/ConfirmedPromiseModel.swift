import Foundation
import Domain

struct ConfirmedPromiseModel: Equatable, Identifiable, Hashable {
  let id: String
  let emoji: String?
  let title: String
  let description: String?
  
  // MARK: - 시간
  let startAt: Date
  let endAt: Date?
}
