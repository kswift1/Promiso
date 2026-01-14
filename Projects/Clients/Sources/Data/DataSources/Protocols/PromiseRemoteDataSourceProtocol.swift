import Foundation
import Combine

// MARK: - Promise Remote Data Source Protocol

public protocol PromiseRemoteDataSourceProtocol {
  // MARK: - CRUD Operations
  func createPromise(_ promise: PromiseModel) async throws -> String
  func respondToPromise(promiseId: String, status: String) async throws
  func updatePromise(_ promise: PromiseModel) async throws
  func deletePromise(id: String) async throws
  func getPromise(id: String) async throws -> PromiseModel?

  // MARK: - Query Operations
  func getTodayPromises(groupIds: [String]) async throws -> [PromiseModel]
  func getUpcomingPromises(groupIds: [String], limit: Int) async throws -> [PromiseModel]
  func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel]
  func getPastPromises(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [PromiseModel]
  func getPromisesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [PromiseModel]

  // MARK: - Count Operations
  func getActivePromiseCount(groupId: String) async throws -> Int

  // MARK: - Real-time Listener
  func subscribeToActivePromises(groupId: String, limit: Int) -> AsyncStream<[PromiseModel]>
}
