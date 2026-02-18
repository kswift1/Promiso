import Foundation
import Combine
import PromisoShared

// MARK: - Personal Event Remote Data Source Protocol

public protocol PersonalEventRemoteDataSourceProtocol: Sendable {
  // MARK: - CRUD Operations
  func createEvent(_ event: PersonalEventModel) async throws -> String
  func updateEvent(_ event: PersonalEventModel) async throws
  func deleteEvent(id: String) async throws
  func getEvent(id: String) async throws -> PersonalEventModel?

  // MARK: - Query Operations
  func getActiveEvents(limit: Int) async throws -> [PersonalEventModel]
  func getPastEvents(limit: Int, lastStartAt: Date?) async throws -> [PersonalEventModel]
  func getEventsByDateRange(startDate: Date, endDate: Date) async throws -> [PersonalEventModel]

  // MARK: - Real-time Listener
  func subscribeToActiveEvents(limit: Int) -> AsyncStream<[PersonalEventModel]>
}
