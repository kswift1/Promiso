import Foundation
import PromisoShared

// MARK: - Recurring Personal Event Remote Data Source Protocol

public protocol RecurringPersonalEventRemoteDataSourceProtocol: Sendable {
  func createEvent(_ event: RecurringPersonalEventModel) async throws -> String
  func updateEvent(_ event: RecurringPersonalEventModel) async throws
  func deleteEvent(id: String) async throws
  func getEvent(id: String) async throws -> RecurringPersonalEventModel?
  func getAllEvents() async throws -> [RecurringPersonalEventModel]
}
