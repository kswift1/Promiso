//
//  MockPromiseRemoteDataSource.swift
//  Clients
//
//  PromiseRemoteDataSourceProtocol Mock 구현
//
//  ## 사용법
//  ```swift
//  let mock = MockPromiseRemoteDataSource()
//  mock.getPromiseHandler = { id in
//    return TestFactories.makePromise(id: id)
//  }
//  let promise = try await mock.getPromise(id: "test-id")
//  #expect(mock.getPromiseCallCount == 1)
//  ```
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockPromiseRemoteDataSource

final class MockPromiseRemoteDataSource: PromiseRemoteDataSourceProtocol, @unchecked Sendable {

  // MARK: - Call Counts

  private(set) var createPromiseCallCount = 0
  private(set) var respondToPromiseCallCount = 0
  private(set) var updatePromiseCallCount = 0
  private(set) var deletePromiseCallCount = 0
  private(set) var getPromiseCallCount = 0
  private(set) var getTodayPromisesCallCount = 0
  private(set) var getUpcomingPromisesCallCount = 0
  private(set) var getActivePromisesCallCount = 0
  private(set) var getPastPromisesCallCount = 0
  private(set) var getPromisesByDateRangeCallCount = 0
  private(set) var getAcceptedPromisesByDateRangeCallCount = 0
  private(set) var getActivePromiseCountCallCount = 0
  private(set) var subscribeToActivePromisesCallCount = 0
  private(set) var getHomePromisesCallCount = 0
  private(set) var getConfirmedPromisesForCalendarCallCount = 0
  private(set) var startLiveActivityCallCount = 0
  private(set) var updateETACallCount = 0

  // MARK: - Captured Arguments

  private(set) var createPromiseArguments: [PromiseModel] = []
  private(set) var respondToPromiseArguments: [(promiseId: String, status: String)] = []
  private(set) var updatePromiseArguments: [PromiseModel] = []
  private(set) var deletePromiseArguments: [String] = []
  private(set) var getPromiseArguments: [String] = []

  // MARK: - Handlers

  var createPromiseHandler: ((PromiseModel) async throws -> String)?
  var respondToPromiseHandler: ((String, String) async throws -> RespondPromiseResult)?
  var updatePromiseHandler: ((PromiseModel) async throws -> Void)?
  var deletePromiseHandler: ((String) async throws -> Void)?
  var getPromiseHandler: ((String) async throws -> PromiseModel?)?
  var getTodayPromisesHandler: (([String]) async throws -> [PromiseModel])?
  var getUpcomingPromisesHandler: (([String], Int) async throws -> [PromiseModel])?
  var getActivePromisesHandler: ((String, Int) async throws -> [PromiseModel])?
  var getPastPromisesHandler: ((String, Int, Date?) async throws -> [PromiseModel])?
  var getPromisesByDateRangeHandler: (([String], Date, Date) async throws -> [PromiseModel])?
  var getAcceptedPromisesByDateRangeHandler: ((Date, Date) async throws -> [PromiseModel])?
  var getActivePromiseCountHandler: ((String) async throws -> Int)?
  var subscribeToActivePromisesHandler: ((String, Int) -> AsyncStream<[PromiseModel]>)?
  var getHomePromisesHandler: (([String], Int) async throws -> [PromiseModel])?
  var getConfirmedPromisesForCalendarHandler: (() async throws -> [CalendarSyncPromise])?
  var startLiveActivityHandler: ((String) async throws -> Void)?
  var updateETAHandler: ((String, [ParticipantState], Int) async throws -> Void)?

  // MARK: - Reset

  /// 모든 호출 카운트와 캡처된 인자 초기화
  func reset() {
    createPromiseCallCount = 0
    respondToPromiseCallCount = 0
    updatePromiseCallCount = 0
    deletePromiseCallCount = 0
    getPromiseCallCount = 0
    getTodayPromisesCallCount = 0
    getUpcomingPromisesCallCount = 0
    getActivePromisesCallCount = 0
    getPastPromisesCallCount = 0
    getPromisesByDateRangeCallCount = 0
    getAcceptedPromisesByDateRangeCallCount = 0
    getActivePromiseCountCallCount = 0
    subscribeToActivePromisesCallCount = 0
    getHomePromisesCallCount = 0
    getConfirmedPromisesForCalendarCallCount = 0
    startLiveActivityCallCount = 0
    updateETACallCount = 0

    createPromiseArguments = []
    respondToPromiseArguments = []
    updatePromiseArguments = []
    deletePromiseArguments = []
    getPromiseArguments = []
  }

  // MARK: - CRUD Operations

  func createPromise(_ promise: PromiseModel) async throws -> String {
    createPromiseCallCount += 1
    createPromiseArguments.append(promise)
    if let handler = createPromiseHandler {
      return try await handler(promise)
    }
    return "created-promise-id"
  }

  func respondToPromise(promiseId: String, status: String) async throws -> RespondPromiseResult {
    respondToPromiseCallCount += 1
    respondToPromiseArguments.append((promiseId, status))
    if let handler = respondToPromiseHandler {
      return try await handler(promiseId, status)
    }
    return RespondPromiseResult(
      promiseId: promiseId,
      status: status,
      isConfirmed: false
    )
  }

  func updatePromise(_ promise: PromiseModel) async throws {
    updatePromiseCallCount += 1
    updatePromiseArguments.append(promise)
    if let handler = updatePromiseHandler {
      try await handler(promise)
    }
  }

  func deletePromise(id: String) async throws {
    deletePromiseCallCount += 1
    deletePromiseArguments.append(id)
    if let handler = deletePromiseHandler {
      try await handler(id)
    }
  }

  func getPromise(id: String) async throws -> PromiseModel? {
    getPromiseCallCount += 1
    getPromiseArguments.append(id)
    if let handler = getPromiseHandler {
      return try await handler(id)
    }
    return nil
  }

  // MARK: - Query Operations

  func getTodayPromises(groupIds: [String]) async throws -> [PromiseModel] {
    getTodayPromisesCallCount += 1
    if let handler = getTodayPromisesHandler {
      return try await handler(groupIds)
    }
    return []
  }

  func getUpcomingPromises(groupIds: [String], limit: Int) async throws -> [PromiseModel] {
    getUpcomingPromisesCallCount += 1
    if let handler = getUpcomingPromisesHandler {
      return try await handler(groupIds, limit)
    }
    return []
  }

  func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    getActivePromisesCallCount += 1
    if let handler = getActivePromisesHandler {
      return try await handler(groupId, limit)
    }
    return []
  }

  func getPastPromises(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [PromiseModel] {
    getPastPromisesCallCount += 1
    if let handler = getPastPromisesHandler {
      return try await handler(groupId, limit, lastStartAt)
    }
    return []
  }

  func getPromisesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [PromiseModel] {
    getPromisesByDateRangeCallCount += 1
    if let handler = getPromisesByDateRangeHandler {
      return try await handler(groupIds, startDate, endDate)
    }
    return []
  }

  func getAcceptedPromisesByDateRange(startDate: Date, endDate: Date) async throws -> [PromiseModel] {
    getAcceptedPromisesByDateRangeCallCount += 1
    if let handler = getAcceptedPromisesByDateRangeHandler {
      return try await handler(startDate, endDate)
    }
    return []
  }

  // MARK: - Count Operations

  func getActivePromiseCount(groupId: String) async throws -> Int {
    getActivePromiseCountCallCount += 1
    if let handler = getActivePromiseCountHandler {
      return try await handler(groupId)
    }
    return 0
  }

  // MARK: - Real-time Listener

  func subscribeToActivePromises(groupId: String, limit: Int) -> AsyncStream<[PromiseModel]> {
    subscribeToActivePromisesCallCount += 1
    if let handler = subscribeToActivePromisesHandler {
      return handler(groupId, limit)
    }
    return AsyncStream { continuation in
      continuation.finish()
    }
  }

  // MARK: - Home

  func getHomePromises(groupIds: [String], limitPerChunk: Int) async throws -> [PromiseModel] {
    getHomePromisesCallCount += 1
    if let handler = getHomePromisesHandler {
      return try await handler(groupIds, limitPerChunk)
    }
    return []
  }

  // MARK: - Calendar Sync

  func getConfirmedPromisesForCalendar() async throws -> [CalendarSyncPromise] {
    getConfirmedPromisesForCalendarCallCount += 1
    if let handler = getConfirmedPromisesForCalendarHandler {
      return try await handler()
    }
    return []
  }

  // MARK: - Live Activity

  func startLiveActivity(promiseId: String) async throws {
    startLiveActivityCallCount += 1
    if let handler = startLiveActivityHandler {
      try await handler(promiseId)
    }
  }

  func updateETA(
    channelId: String,
    participants: [ParticipantState],
    trackingDurationMinutes: Int
  ) async throws {
    updateETACallCount += 1
    if let handler = updateETAHandler {
      try await handler(channelId, participants, trackingDurationMinutes)
    }
  }
}
