import Foundation
import Combine
import PromisoShared

// MARK: - Promise Remote Data Source Protocol

public protocol PromiseRemoteDataSourceProtocol {
  // MARK: - CRUD Operations
  func createPromise(_ promise: PromiseModel) async throws -> String
  func respondToPromise(promiseId: String, status: String) async throws -> RespondPromiseResult
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

  // MARK: - Home Snapshot
  /// 홈화면 스냅샷 조회 (캐시된 데이터)
  func getHomeSnapshot() async throws -> HomeSnapshotDocument

  /// 홈화면 스냅샷 갱신 (Firebase Functions 호출)
  /// 하루 첫 진입 시 또는 Pull-to-refresh 시 호출
  func refreshHomeSnapshot() async throws -> HomeSnapshotDocument

  // MARK: - Calendar Sync
  /// 캘린더 동기화용 확정 약속 조회 (미래 약속만)
  func getConfirmedPromisesForCalendar() async throws -> [CalendarSyncPromise]

  // MARK: - Live Activity
  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  func startLiveActivity(promiseId: String) async throws

  /// ETA 업데이트 요청 (백엔드에서 APNs 브로드캐스트)
  /// Firestore 없이 클라이언트에서 전달한 데이터로 Broadcast만 전송
  func updateETA(
    channelId: String,
    participants: [ParticipantState],
    trackingDurationMinutes: Int
  ) async throws

  // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
  // registerLiveActivityToken 제거됨 - iOS 18 Broadcast 방식으로 전환
}
