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

  // MARK: - Live Activity
  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  func startLiveActivity(promiseId: String) async throws

  /// ETA 업데이트 요청 (백엔드에서 APNs 브로드캐스트)
  func updateETA(promiseId: String, visibleMinutes: Int) async throws

  /// LiveActivity 종료 요청
  func endLiveActivity(promiseId: String) async throws

  /// LiveActivity Push Token 등록 (앱에서 직접 시작한 경우)
  /// - Parameters:
  ///   - promiseId: 약속 ID
  ///   - token: LiveActivity Push Token
  ///   - apnsEnvironment: APNs 환경 ("sandbox" 또는 "production")
  func registerLiveActivityToken(promiseId: String, token: String, apnsEnvironment: String) async throws
}
