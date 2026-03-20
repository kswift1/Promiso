import Foundation
import Combine
import PromisoShared

// MARK: - Schedule Remote Data Source Protocol

public protocol ScheduleRemoteDataSourceProtocol {
  // MARK: - CRUD Operations
  func createSchedule(_ schedule: ScheduleModel) async throws -> String
  func respondToSchedule(scheduleId: String, status: String) async throws -> RespondScheduleResult
  func updateSchedule(_ schedule: ScheduleModel) async throws
  func deleteSchedule(id: String) async throws
  func getSchedule(id: String) async throws -> ScheduleModel?

  // MARK: - Query Operations
  func getTodaySchedules(groupIds: [String]) async throws -> [ScheduleModel]
  func getUpcomingSchedules(groupIds: [String], limit: Int) async throws -> [ScheduleModel]
  func getActiveSchedules(groupId: String, limit: Int) async throws -> [ScheduleModel]
  func getPastSchedules(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [ScheduleModel]
  func getSchedulesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [ScheduleModel]
  func getAcceptedSchedulesByDateRange(startDate: Date, endDate: Date) async throws -> [ScheduleModel]

  // MARK: - Count Operations
  func getActiveScheduleCount(groupId: String) async throws -> Int

  // MARK: - Real-time Listener
  func subscribeToActiveSchedules(groupId: String, limit: Int) -> AsyncStream<[ScheduleModel]>

  // MARK: - Home
  /// 홈화면용 일정 조회 (다중 그룹, 미래 일정)
  /// - Parameters:
  ///   - groupIds: 조회할 그룹 ID 목록
  ///   - limitPerChunk: 그룹 청크당 최대 개수 (기본 10)
  /// - Returns: 미래 일정 목록 (startAt 오름차순)
  func getHomeSchedules(groupIds: [String], limitPerChunk: Int) async throws -> [ScheduleModel]

  // MARK: - Calendar Sync
  /// 캘린더 동기화용 확정 일정 조회 (미래 일정만)
  func getConfirmedSchedulesForCalendar() async throws -> [CalendarSyncSchedule]

  // MARK: - Live Activity
  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  func startLiveActivity(scheduleId: String) async throws

  /// 투표 LiveActivity 시작 요청 (Firebase Function 호출)
  func startVoteLiveActivity(scheduleId: String) async throws

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
