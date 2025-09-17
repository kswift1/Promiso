import Foundation
import Combine

// MARK: - Promise Repository Protocol

public protocol PromiseRepositoryProtocol {
  // MARK: - CRUD Operations
  func createPromise(_ promise: Promise) async throws -> String
  func updatePromise(_ promise: Promise) async throws
  func deletePromise(id: String) async throws
  func getPromise(id: String) async throws -> Promise?
  
  // MARK: - Query Operations
  func getTodayPromises(userId: String, groupId: String?) async throws -> [Promise]
  func getUpcomingPromises(userId: String, limit: Int) async throws -> [Promise]
  func getPendingProposals(userId: String, limit: Int) async throws -> [Promise]
  func getActivePromises(groupId: String, limit: Int) async throws -> [Promise]
  
  // MARK: - Real-time Operations
  func observeTodayPromises(userId: String, groupId: String?) -> AnyPublisher<[Promise], Error>
  func observePromise(id: String) -> AnyPublisher<Promise?, Error>
}
