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
  func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel]
  func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel]
  func getPendingProposals(userId: String, limit: Int) async throws -> [PromiseModel]
  func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel]
  func getPastPromises(groupId: String, limit: Int) async throws -> [PromiseModel]

  // MARK: - Real-time Listener
  func subscribeToActivePromises(groupId: String, limit: Int) -> AsyncStream<[PromiseModel]>
}
