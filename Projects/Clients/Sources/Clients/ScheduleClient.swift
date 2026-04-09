//
//  ScheduleClient.swift
//  Clients
//
//  TCA Dependency Client for Schedule operations
//  Acts as an adapter between Feature layer and Shared layer
//

import ComposableArchitecture
import Foundation
import Combine
import PromisoShared

// MARK: - Error

/// 일정 API 에러
public enum ScheduleClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData(String?)
  case groupNotFound
  case notGroupMember
  case unknown(String?)

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return LocalizedStrings.Error.networkError
    case .unauthorized:
      return LocalizedStrings.Error.userAuthRequired
    case .notFound:
      return LocalizedStrings.Error.notFoundError
    case .serverError:
      return LocalizedStrings.Error.serverError
    case .invalidData(let message):
      return message ?? LocalizedStrings.Error.validationError
    case .groupNotFound:
      return LocalizedStrings.Error.notFoundError
    case .notGroupMember:
      return LocalizedStrings.Error.permissionError
    case .unknown(let message):
      return message ?? LocalizedStrings.Error.unknownError
    }
  }

  /// NSError를 ScheduleClientError로 변환
  init(from error: Error) {
    let nsError = error as NSError
    let message = nsError.localizedDescription

    guard nsError.domain == "FIRFunctionsErrorDomain" else {
      self = .networkError
      return
    }

    switch nsError.code {
    case 16: self = .unauthorized
    case 3, 9: self = .invalidData(message)
    case 5: self = .groupNotFound
    case 7: self = .notGroupMember
    case 13: self = .serverError
    default: self = .unknown(message)
    }
  }
}

// MARK: - Client

/// TCA용 일정 클라이언트
/// Feature 레이어에 최적화된 API 제공
@DependencyClient
public struct ScheduleClient: Sendable {
  /// 일정 생성
  public var createSchedule: @Sendable (_ schedule: ScheduleModel) async throws -> String = { _ in "" }

  /// 일정 수정
  public var updateSchedule: @Sendable (_ schedule: ScheduleModel) async throws -> Void

  /// 일정 삭제
  public var deleteSchedule: @Sendable (_ scheduleId: String) async throws -> Void

  /// 일정 조회
  public var getSchedule: @Sendable (_ scheduleId: String) async throws -> ScheduleModel?

  /// 오늘의 일정 조회 (사용자가 속한 그룹들의 일정)
  public var getTodaySchedules: @Sendable (_ groupIds: [String]) async throws -> [ScheduleModel]

  /// 다가오는 일정 조회 (사용자가 속한 그룹들의 일정)
  public var getUpcomingSchedules: @Sendable (_ groupIds: [String], _ limit: Int) async throws -> [ScheduleModel]

  /// 그룹의 활성 일정 조회
  public var getActiveSchedules: @Sendable (_ groupId: String, _ limit: Int) async throws -> [ScheduleModel]

  /// 그룹의 과거 일정 조회 (커서 기반 페이징)
  public var getPastSchedules: @Sendable (_ groupId: String, _ limit: Int, _ lastStartAt: Date?) async throws -> [ScheduleModel]

  /// 그룹의 활성 일정 개수 조회
  public var getActiveScheduleCount: @Sendable (_ groupId: String) async throws -> Int

  /// 날짜 범위로 일정 조회 (캘린더용, 사용자가 속한 그룹들의 일정)
  public var getSchedulesByDateRange: @Sendable (
    _ groupIds: [String],
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [ScheduleModel]

  /// 홈화면용 일정 조회 (다중 그룹, 미래 일정)
  /// - Parameters:
  ///   - groupIds: 조회할 그룹 ID 목록
  ///   - limitPerChunk: 그룹 청크당 최대 개수 (기본 10)
  /// - Returns: 미래 일정 목록 (startAt 오름차순)
  public var getHomeSchedules: @Sendable (_ groupIds: [String], _ limitPerChunk: Int) async throws -> [ScheduleModel]

  /// 그룹의 활성 일정 실시간 구독
  public var subscribeToSchedules: @Sendable (_ groupId: String, _ limit: Int) -> AsyncStream<[ScheduleModel]> = { _, _ in AsyncStream { _ in } }

  /// 일정 응답 (캘린더 동기화용 결과 반환)
  public var respondSchedule: @Sendable (_ scheduleId: String, _ status: ScheduleAttendanceStatus) async throws -> RespondScheduleResult

  // MARK: - Schedule Conflict

  /// 사용자가 수락한 일정을 날짜 범위로 조회 (일정 충돌 감지용)
  public var getAcceptedSchedulesByDateRange: @Sendable (
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [ScheduleModel]

  // MARK: - Calendar Sync

  /// 캘린더 동기화용 확정 일정 조회 (미래 일정만)
  public var getConfirmedSchedulesForCalendar: @Sendable () async throws -> [CalendarSyncSchedule]

  // MARK: - Live Activity

  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  public var startLiveActivity: @Sendable (_ scheduleId: String) async throws -> Void

  /// 투표 LiveActivity 시작 요청 (Firebase Function 호출)
  public var startVoteLiveActivity: @Sendable (_ scheduleId: String) async throws -> Void

  /// 투표 마감 (호스트 전용)
  public var finalizeVote: @Sendable (_ scheduleId: String) async throws -> Void

  /// ETA 업데이트 요청 (백엔드에서 APNs 브로드캐스트)
  /// Firestore 없이 클라이언트에서 전달한 데이터로 Broadcast만 전송
  public var updateETA: @Sendable (
    _ scheduleId: String,
    _ channelId: String,
    _ participants: [ParticipantState],
    _ trackingDurationMinutes: Int
  ) async throws -> Void

  // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리

  // registerLiveActivityToken 제거됨 - iOS 18 Broadcast 방식으로 전환
  // Broadcast는 채널 기반이므로 개별 토큰 관리 불필요
}

// MARK: - Test & Preview Values

extension ScheduleClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    createSchedule: { _ in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updateSchedule: { _ in
      try await Task.sleep(for: .seconds(1))
    },
    deleteSchedule: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    getSchedule: { _ in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getTodaySchedules: { _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getUpcomingSchedules: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActiveSchedules: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return ScheduleModel.examples
    },
    getPastSchedules: { _, _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActiveScheduleCount: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return 3
    },
    getSchedulesByDateRange: { _, _, _ in
      try await Task.sleep(for: .seconds(0.5))
      return ScheduleModel.examples
    },
    getHomeSchedules: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
      return ScheduleModel.examples
    },
    subscribeToSchedules: { _, _ in
      AsyncStream { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation.yield(ScheduleModel.examples)
        }
      }
    },
    respondSchedule: { scheduleId, status in
      try await Task.sleep(for: .seconds(0.3))
      return RespondScheduleResult(
        scheduleId: scheduleId,
        status: status.rawValue,
        isConfirmed: false,
        confirmedSchedule: nil
      )
    },
    getAcceptedSchedulesByDateRange: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
      return []
    },
    getConfirmedSchedulesForCalendar: {
      try await Task.sleep(for: .seconds(0.3))
      return []
    },
    startLiveActivity: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    startVoteLiveActivity: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    finalizeVote: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    updateETA: { _, _, _, _  in
      try await Task.sleep(for: .seconds(0.3))
    }
    // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var scheduleClient: ScheduleClient {
    get { self[ScheduleClient.self] }
    set { self[ScheduleClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ScheduleClient: DependencyKey {
  public static let liveValue: ScheduleClient = {
    @Dependency(\.featureFlags) var featureFlags
    let rustDataSource = ScheduleRustDataSource(
      api: RustAPIClient()
    )

    return ScheduleClient(
      createSchedule: { schedule in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.createSchedule(schedule)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          guard !schedule.groupId.isEmpty else {
            throw ScheduleClientError.invalidData(nil)
          }
          do {
            return try await dataSource.createSchedule(schedule)
          } catch {
            throw ScheduleClientError(from: error)
          }
        }
      },
      updateSchedule: { schedule in
        if featureFlags.useRustAPI(.promises) {
          try await rustDataSource.updateSchedule(schedule)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          try await dataSource.updateSchedule(schedule)
        }
      },
      deleteSchedule: { scheduleId in
        if featureFlags.useRustAPI(.promises) {
          try await rustDataSource.deleteSchedule(id: scheduleId)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          try await dataSource.deleteSchedule(id: scheduleId)
        }
      },
      getSchedule: { scheduleId in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getSchedule(id: scheduleId)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getSchedule(id: scheduleId)
        }
      },
      getTodaySchedules: { groupIds in
        if featureFlags.useRustAPI(.promises) {
          // Rust API: /home 엔드포인트로 대체 후 클라이언트에서 today 필터링
          let schedules = try await rustDataSource.getHomeSchedules(groupIds: groupIds, limitPerChunk: 20)
          let calendar = Calendar.current
          let startOfDay = calendar.startOfDay(for: Date())
          guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
          return schedules.filter { $0.startAt >= startOfDay && $0.startAt < endOfDay }
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getTodaySchedules(groupIds: groupIds)
        }
      },
      getUpcomingSchedules: { groupIds, limit in
        if featureFlags.useRustAPI(.promises) {
          // Rust API: /home 엔드포인트로 대체
          let schedules = try await rustDataSource.getHomeSchedules(groupIds: groupIds, limitPerChunk: limit)
          return Array(schedules.prefix(limit))
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getUpcomingSchedules(groupIds: groupIds, limit: limit)
        }
      },
      getActiveSchedules: { groupId, limit in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getActiveSchedules(groupId: groupId, limit: limit)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getActiveSchedules(groupId: groupId, limit: limit)
        }
      },
      getPastSchedules: { groupId, limit, lastStartAt in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getPastSchedules(groupId: groupId, limit: limit, lastStartAt: lastStartAt)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getPastSchedules(groupId: groupId, limit: limit, lastStartAt: lastStartAt)
        }
      },
      getActiveScheduleCount: { groupId in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getActiveScheduleCount(groupId: groupId)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getActiveScheduleCount(groupId: groupId)
        }
      },
      getSchedulesByDateRange: { groupIds, startDate, endDate in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getSchedulesByDateRange(
            groupIds: groupIds,
            startDate: startDate,
            endDate: endDate
          )
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getSchedulesByDateRange(
            groupIds: groupIds,
            startDate: startDate,
            endDate: endDate
          )
        }
      },
      getHomeSchedules: { groupIds, limitPerChunk in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getHomeSchedules(groupIds: groupIds, limitPerChunk: limitPerChunk)
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getHomeSchedules(groupIds: groupIds, limitPerChunk: limitPerChunk)
        }
      },
      subscribeToSchedules: { groupId, limit in
        if featureFlags.useRustAPI(.promises) {
          return AsyncStream { continuation in
            let task = Task {
              do {
                let schedules = try await rustDataSource.getActiveSchedules(groupId: groupId, limit: limit)
                continuation.yield(schedules)
              } catch {
                continuation.yield([])
              }
              continuation.finish()
            }
            continuation.onTermination = { _ in
              task.cancel()
            }
          }
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return dataSource.subscribeToActiveSchedules(groupId: groupId, limit: limit)
        }
      },
      respondSchedule: { scheduleId, status in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.respondToSchedule(
            scheduleId: scheduleId,
            status: status.rawValue
          )
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.respondToSchedule(
            scheduleId: scheduleId,
            status: status.rawValue
          )
        }
      },
      getAcceptedSchedulesByDateRange: { startDate, endDate in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getAcceptedSchedulesByDateRange(
            startDate: startDate,
            endDate: endDate
          )
        } else {
          let dataSource = ScheduleRemoteDataSource()
          do {
            return try await dataSource.getAcceptedSchedulesByDateRange(
              startDate: startDate,
              endDate: endDate
            )
          } catch {
            throw ScheduleClientError(from: error)
          }
        }
      },
      getConfirmedSchedulesForCalendar: {
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getConfirmedSchedulesForCalendar()
        } else {
          let dataSource = ScheduleRemoteDataSource()
          return try await dataSource.getConfirmedSchedulesForCalendar()
        }
      },
      // Live Activity는 Rust/APNs 경로만 유지한다.
      startLiveActivity: { scheduleId in
        try await rustDataSource.startLiveActivity(scheduleId: scheduleId)
      },
      startVoteLiveActivity: { scheduleId in
        try await rustDataSource.startVoteLiveActivity(scheduleId: scheduleId)
      },
      finalizeVote: { scheduleId in
        try await rustDataSource.finalizeVote(scheduleId: scheduleId)
      },
      updateETA: { scheduleId, channelId, participants, trackingDurationMinutes in
        try await rustDataSource.updateETA(
          scheduleId: scheduleId,
          channelId: channelId,
          participants: participants,
          trackingDurationMinutes: trackingDurationMinutes
        )
      }
      // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
    )
  }()
}

// MARK: - Example Data

extension ScheduleModel {
  /// Preview용 현재 유저 ID
  public static let previewCurrentUserId = "preview-user"

  /// 다양한 상태의 일정 예시 (그룹 탭 UI 테스트용)
  public static let examples: [ScheduleModel] = [
    // 1. 응답 필요 (needResponse) - 미응답 상태
    ScheduleModel(
      id: "schedule-need-response-1",
      title: "주말 러닝",
      emoji: "🏃",
      description: "한강에서 5km 뛰어요!",
      hostId: "user123",
      groupId: "g1",
      minimumParticipants: 2,
      votes: ScheduleVotesModel(
        accepted: ["user123"],  // 호스트만 수락
        declined: [],
        until: Date().addingTimeInterval(86400)  // 내일까지
      ),
      startAt: Date().addingTimeInterval(172800),  // 2일 후
      location: LocationInfoModel(name: "여의도 한강공원")
    ),
    // 2. 응답 필요 (needResponse) - 급한 마감
    ScheduleModel(
      id: "schedule-need-response-2",
      title: "긴급 회식",
      emoji: "🍻",
      description: "오늘 저녁 회식입니다",
      hostId: "user456",
      groupId: "g1",
      minimumParticipants: 3,
      votes: ScheduleVotesModel(
        accepted: ["user456", "user789"],
        declined: [],
        until: Date().addingTimeInterval(3600)  // 1시간 후 마감
      ),
      startAt: Date().addingTimeInterval(21600),  // 6시간 후
      location: LocationInfoModel(name: "강남역 고기집")
    ),
    // 3. 확정됨 (confirmed) - 오늘 일정
    ScheduleModel(
      id: "schedule-confirmed-1",
      title: "점심 일정",
      emoji: "🍜",
      description: "맛있는 라멘 먹으러 가요",
      hostId: "preview-user",
      groupId: "g1",
      minimumParticipants: 2,
      votes: ScheduleVotesModel(
        accepted: ["preview-user", "user123", "user456"],
        declined: [],
        until: Date().addingTimeInterval(-3600)  // 이미 마감
      ),
      startAt: Date().addingTimeInterval(7200),  // 2시간 후
      location: LocationInfoModel(name: "이치란 라멘")
    ),
    // 4. 확정됨 (confirmed) - 내일 일정
    ScheduleModel(
      id: "schedule-confirmed-2",
      title: "영화 보기",
      emoji: "🎬",
      description: "신작 영화 같이 봐요",
      hostId: "user789",
      groupId: "g2",
      minimumParticipants: 2,
      votes: ScheduleVotesModel(
        accepted: ["preview-user", "user789"],
        declined: ["user123"],
        until: Date().addingTimeInterval(-7200)
      ),
      startAt: Date().addingTimeInterval(108000),  // 30시간 후
      location: LocationInfoModel(name: "CGV 용산")
    ),
    // 5. 응답 완료 (responded) - 대기 중
    ScheduleModel(
      id: "schedule-responded-1",
      title: "독서 모임",
      emoji: "📚",
      description: "이번 달 책 토론해요",
      hostId: "user123",
      groupId: "g3",
      minimumParticipants: 4,
      votes: ScheduleVotesModel(
        accepted: ["preview-user", "user123"],  // 2명만 수락, 4명 필요
        declined: [],
        until: Date().addingTimeInterval(172800)
      ),
      startAt: Date().addingTimeInterval(259200),  // 3일 후
      location: LocationInfoModel(name: "교보문고 카페")
    )
  ]

  /// 그룹별 일정 필터링 (Preview용)
  public static func examples(for groupId: String) -> [ScheduleModel] {
    examples.filter { $0.groupId == groupId }
  }

  /// 응답 필요 일정만 필터링 (Preview용)
  public static func needResponseExamples(currentUserId: String = previewCurrentUserId) -> [ScheduleModel] {
    examples.filter { $0.responseStatus(currentUserId: currentUserId) == .needResponse }
  }

  /// 확정된 일정만 필터링 (Preview용)
  public static var confirmedExamples: [ScheduleModel] {
    examples.filter { $0.isConfirmed }
  }
}
