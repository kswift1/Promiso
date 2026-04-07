//
//  MockScheduleRemoteDataSource.swift
//  Clients
//
//  ScheduleRemoteDataSourceProtocol Mock 구현
//
//  ## 사용법
//  ```swift
//  let mock = MockScheduleRemoteDataSource()
//  mock.getScheduleHandler = { id in
//    return TestFactories.makeSchedule(id: id)
//  }
//  let schedule = try await mock.getSchedule(id: "test-id")
//  #expect(mock.getScheduleCallCount == 1)
//  ```
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockScheduleRemoteDataSource

final class MockScheduleRemoteDataSource: ScheduleRemoteDataSourceProtocol {

  // MARK: - Call Counts

  private(set) var createScheduleCallCount = 0
  private(set) var respondToScheduleCallCount = 0
  private(set) var updateScheduleCallCount = 0
  private(set) var deleteScheduleCallCount = 0
  private(set) var getScheduleCallCount = 0
  private(set) var getTodaySchedulesCallCount = 0
  private(set) var getUpcomingSchedulesCallCount = 0
  private(set) var getActiveSchedulesCallCount = 0
  private(set) var getPastSchedulesCallCount = 0
  private(set) var getSchedulesByDateRangeCallCount = 0
  private(set) var getAcceptedSchedulesByDateRangeCallCount = 0
  private(set) var getActiveScheduleCountCallCount = 0
  private(set) var subscribeToActiveSchedulesCallCount = 0
  private(set) var getHomeSchedulesCallCount = 0
  private(set) var getConfirmedSchedulesForCalendarCallCount = 0
  private(set) var startLiveActivityCallCount = 0
  private(set) var startVoteLiveActivityCallCount = 0
  private(set) var finalizeVoteCallCount = 0
  private(set) var updateETACallCount = 0

  // MARK: - Captured Arguments

  private(set) var createScheduleArguments: [ScheduleModel] = []
  private(set) var respondToScheduleArguments: [(scheduleId: String, status: String)] = []
  private(set) var updateScheduleArguments: [ScheduleModel] = []
  private(set) var deleteScheduleArguments: [String] = []
  private(set) var getScheduleArguments: [String] = []

  // MARK: - Handlers

  var createScheduleHandler: ((ScheduleModel) async throws -> String)?
  var respondToScheduleHandler: ((String, String) async throws -> RespondScheduleResult)?
  var updateScheduleHandler: ((ScheduleModel) async throws -> Void)?
  var deleteScheduleHandler: ((String) async throws -> Void)?
  var getScheduleHandler: ((String) async throws -> ScheduleModel?)?
  var getTodaySchedulesHandler: (([String]) async throws -> [ScheduleModel])?
  var getUpcomingSchedulesHandler: (([String], Int) async throws -> [ScheduleModel])?
  var getActiveSchedulesHandler: ((String, Int) async throws -> [ScheduleModel])?
  var getPastSchedulesHandler: ((String, Int, Date?) async throws -> [ScheduleModel])?
  var getSchedulesByDateRangeHandler: (([String], Date, Date) async throws -> [ScheduleModel])?
  var getAcceptedSchedulesByDateRangeHandler: ((Date, Date) async throws -> [ScheduleModel])?
  var getActiveScheduleCountHandler: ((String) async throws -> Int)?
  var subscribeToActiveSchedulesHandler: ((String, Int) -> AsyncStream<[ScheduleModel]>)?
  var getHomeSchedulesHandler: (([String], Int) async throws -> [ScheduleModel])?
  var getConfirmedSchedulesForCalendarHandler: (() async throws -> [CalendarSyncSchedule])?
  var startLiveActivityHandler: ((String) async throws -> Void)?
  var startVoteLiveActivityHandler: ((String) async throws -> Void)?
  var finalizeVoteHandler: ((String) async throws -> Void)?
  var updateETAHandler: ((String, String, [ParticipantState], Int) async throws -> Void)?

  // MARK: - Reset

  /// 모든 호출 카운트와 캡처된 인자 초기화
  func reset() {
    createScheduleCallCount = 0
    respondToScheduleCallCount = 0
    updateScheduleCallCount = 0
    deleteScheduleCallCount = 0
    getScheduleCallCount = 0
    getTodaySchedulesCallCount = 0
    getUpcomingSchedulesCallCount = 0
    getActiveSchedulesCallCount = 0
    getPastSchedulesCallCount = 0
    getSchedulesByDateRangeCallCount = 0
    getAcceptedSchedulesByDateRangeCallCount = 0
    getActiveScheduleCountCallCount = 0
    subscribeToActiveSchedulesCallCount = 0
    getHomeSchedulesCallCount = 0
    getConfirmedSchedulesForCalendarCallCount = 0
    startLiveActivityCallCount = 0
    startVoteLiveActivityCallCount = 0
    finalizeVoteCallCount = 0
    updateETACallCount = 0

    createScheduleArguments = []
    respondToScheduleArguments = []
    updateScheduleArguments = []
    deleteScheduleArguments = []
    getScheduleArguments = []
  }

  // MARK: - CRUD Operations

  func createSchedule(_ schedule: ScheduleModel) async throws -> String {
    createScheduleCallCount += 1
    createScheduleArguments.append(schedule)
    if let handler = createScheduleHandler {
      return try await handler(schedule)
    }
    return "created-schedule-id"
  }

  func respondToSchedule(scheduleId: String, status: String) async throws -> RespondScheduleResult {
    respondToScheduleCallCount += 1
    respondToScheduleArguments.append((scheduleId, status))
    if let handler = respondToScheduleHandler {
      return try await handler(scheduleId, status)
    }
    return RespondScheduleResult(
      scheduleId: scheduleId,
      status: status,
      isConfirmed: false
    )
  }

  func updateSchedule(_ schedule: ScheduleModel) async throws {
    updateScheduleCallCount += 1
    updateScheduleArguments.append(schedule)
    if let handler = updateScheduleHandler {
      try await handler(schedule)
    }
  }

  func deleteSchedule(id: String) async throws {
    deleteScheduleCallCount += 1
    deleteScheduleArguments.append(id)
    if let handler = deleteScheduleHandler {
      try await handler(id)
    }
  }

  func getSchedule(id: String) async throws -> ScheduleModel? {
    getScheduleCallCount += 1
    getScheduleArguments.append(id)
    if let handler = getScheduleHandler {
      return try await handler(id)
    }
    return nil
  }

  // MARK: - Query Operations

  func getTodaySchedules(groupIds: [String]) async throws -> [ScheduleModel] {
    getTodaySchedulesCallCount += 1
    if let handler = getTodaySchedulesHandler {
      return try await handler(groupIds)
    }
    return []
  }

  func getUpcomingSchedules(groupIds: [String], limit: Int) async throws -> [ScheduleModel] {
    getUpcomingSchedulesCallCount += 1
    if let handler = getUpcomingSchedulesHandler {
      return try await handler(groupIds, limit)
    }
    return []
  }

  func getActiveSchedules(groupId: String, limit: Int) async throws -> [ScheduleModel] {
    getActiveSchedulesCallCount += 1
    if let handler = getActiveSchedulesHandler {
      return try await handler(groupId, limit)
    }
    return []
  }

  func getPastSchedules(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [ScheduleModel] {
    getPastSchedulesCallCount += 1
    if let handler = getPastSchedulesHandler {
      return try await handler(groupId, limit, lastStartAt)
    }
    return []
  }

  func getSchedulesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [ScheduleModel] {
    getSchedulesByDateRangeCallCount += 1
    if let handler = getSchedulesByDateRangeHandler {
      return try await handler(groupIds, startDate, endDate)
    }
    return []
  }

  func getAcceptedSchedulesByDateRange(startDate: Date, endDate: Date) async throws -> [ScheduleModel] {
    getAcceptedSchedulesByDateRangeCallCount += 1
    if let handler = getAcceptedSchedulesByDateRangeHandler {
      return try await handler(startDate, endDate)
    }
    return []
  }

  // MARK: - Count Operations

  func getActiveScheduleCount(groupId: String) async throws -> Int {
    getActiveScheduleCountCallCount += 1
    if let handler = getActiveScheduleCountHandler {
      return try await handler(groupId)
    }
    return 0
  }

  // MARK: - Real-time Listener

  func subscribeToActiveSchedules(groupId: String, limit: Int) -> AsyncStream<[ScheduleModel]> {
    subscribeToActiveSchedulesCallCount += 1
    if let handler = subscribeToActiveSchedulesHandler {
      return handler(groupId, limit)
    }
    return AsyncStream { continuation in
      continuation.finish()
    }
  }

  // MARK: - Home

  func getHomeSchedules(groupIds: [String], limitPerChunk: Int) async throws -> [ScheduleModel] {
    getHomeSchedulesCallCount += 1
    if let handler = getHomeSchedulesHandler {
      return try await handler(groupIds, limitPerChunk)
    }
    return []
  }

  // MARK: - Calendar Sync

  func getConfirmedSchedulesForCalendar() async throws -> [CalendarSyncSchedule] {
    getConfirmedSchedulesForCalendarCallCount += 1
    if let handler = getConfirmedSchedulesForCalendarHandler {
      return try await handler()
    }
    return []
  }

  // MARK: - Live Activity

  func startLiveActivity(scheduleId: String) async throws {
    startLiveActivityCallCount += 1
    if let handler = startLiveActivityHandler {
      try await handler(scheduleId)
    }
  }

  func startVoteLiveActivity(scheduleId: String) async throws {
    startVoteLiveActivityCallCount += 1
    if let handler = startVoteLiveActivityHandler {
      try await handler(scheduleId)
    }
  }

  func finalizeVote(scheduleId: String) async throws {
    finalizeVoteCallCount += 1
    if let handler = finalizeVoteHandler {
      try await handler(scheduleId)
    }
  }

  func updateETA(
    scheduleId: String,
    channelId: String,
    participants: [ParticipantState],
    trackingDurationMinutes: Int
  ) async throws {
    updateETACallCount += 1
    if let handler = updateETAHandler {
      try await handler(scheduleId, channelId, participants, trackingDurationMinutes)
    }
  }
}
