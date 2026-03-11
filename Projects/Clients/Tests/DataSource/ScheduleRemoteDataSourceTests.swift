//
//  ScheduleRemoteDataSourceTests.swift
//  Clients
//
//  Mock 기반 ScheduleRemoteDataSource 로직 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Data/DataSources/Protocols/ScheduleRemoteDataSourceProtocol.swift`
//  - `Clients/Tests/Mocks/MockScheduleRemoteDataSource.swift`
//
//  ## 테스트 목적
//  - Mock DataSource의 호출 카운트 및 인자 캡처 검증
//  - 커스텀 핸들러 동작 검증
//  - 에러 전파 검증
//  - reset 기능 검증
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockScheduleRemoteDataSource 동작 테스트

@Suite("ScheduleRemoteDataSource Mock 기반 테스트")
struct ScheduleRemoteDataSourceTests {

  // MARK: - CRUD 호출 카운트 및 인자 캡처 테스트

  @Test("createSchedule 호출 시 callCount 증가 및 인자 캡처")
  func createSchedule_incrementsCallCountAndCapturesArguments() async throws {
    let mock = MockScheduleRemoteDataSource()
    let schedule = TestFactories.makeSchedule(title: "새 일정", groupId: "g1")

    let result = try await mock.createSchedule(schedule)

    #expect(mock.createScheduleCallCount == 1)
    #expect(mock.createScheduleArguments.count == 1)
    #expect(mock.createScheduleArguments.first?.title == "새 일정")
    #expect(mock.createScheduleArguments.first?.groupId == "g1")
    #expect(result == "created-schedule-id")
  }

  @Test("createSchedule 커스텀 핸들러가 반환값 오버라이드")
  func createSchedule_customHandler_overridesDefaultReturn() async throws {
    let mock = MockScheduleRemoteDataSource()
    mock.createScheduleHandler = { schedule in
      return "custom-id-\(schedule.groupId)"
    }

    let schedule = TestFactories.makeSchedule(groupId: "my-group")
    let result = try await mock.createSchedule(schedule)

    #expect(result == "custom-id-my-group")
    #expect(mock.createScheduleCallCount == 1)
  }

  @Test("getSchedule 기본 핸들러는 nil 반환, 커스텀 핸들러 설정 시 일정 반환")
  func getSchedule_defaultReturnsNil_customHandlerReturnsSchedule() async throws {
    let mock = MockScheduleRemoteDataSource()

    // 기본 핸들러: nil 반환
    let nilResult = try await mock.getSchedule(id: "schedule-1")
    #expect(nilResult == nil)
    #expect(mock.getScheduleCallCount == 1)
    #expect(mock.getScheduleArguments == ["schedule-1"])

    // 커스텀 핸들러: 일정 반환
    mock.getScheduleHandler = { id in
      return TestFactories.makeSchedule(id: id, title: "조회된 일정")
    }

    let result = try await mock.getSchedule(id: "schedule-2")
    #expect(result?.id == "schedule-2")
    #expect(result?.title == "조회된 일정")
    #expect(mock.getScheduleCallCount == 2)
  }

  // MARK: - 에러 전파 테스트

  @Test("핸들러에서 에러 발생 시 에러가 정상적으로 전파")
  func handler_throwsError_propagatesCorrectly() async {
    let mock = MockScheduleRemoteDataSource()
    mock.deleteScheduleHandler = { _ in
      throw ScheduleClientError.notFound
    }

    do {
      try await mock.deleteSchedule(id: "nonexistent")
      #expect(Bool(false), "에러가 발생해야 합니다")
    } catch {
      #expect(error is ScheduleClientError)
      #expect(mock.deleteScheduleCallCount == 1)
      #expect(mock.deleteScheduleArguments == ["nonexistent"])
    }
  }

  // MARK: - 쿼리 Operations 테스트

  @Test("getActiveSchedules 빈 그룹에서 빈 배열 반환, 핸들러 설정 시 데이터 반환")
  func getActiveSchedules_defaultEmpty_customHandlerReturnsData() async throws {
    let mock = MockScheduleRemoteDataSource()

    // 기본: 빈 배열
    let emptyResult = try await mock.getActiveSchedules(groupId: "g1", limit: 10)
    #expect(emptyResult.isEmpty)
    #expect(mock.getActiveSchedulesCallCount == 1)

    // 커스텀 핸들러: 데이터 반환
    mock.getActiveSchedulesHandler = { groupId, limit in
      return [
        TestFactories.makeSchedule(id: "p1", groupId: groupId),
        TestFactories.makeSchedule(id: "p2", groupId: groupId),
      ]
    }

    let result = try await mock.getActiveSchedules(groupId: "g1", limit: 10)
    #expect(result.count == 2)
    #expect(result.first?.groupId == "g1")
    #expect(mock.getActiveSchedulesCallCount == 2)
  }

  // MARK: - reset 테스트

  @Test("reset 호출 시 모든 카운트와 캡처 인자 초기화")
  func reset_clearsAllCountsAndArguments() async throws {
    let mock = MockScheduleRemoteDataSource()

    // 몇 가지 호출 수행
    _ = try await mock.createSchedule(TestFactories.makeSchedule())
    _ = try await mock.getSchedule(id: "p1")
    try await mock.deleteSchedule(id: "p2")

    #expect(mock.createScheduleCallCount == 1)
    #expect(mock.getScheduleCallCount == 1)
    #expect(mock.deleteScheduleCallCount == 1)

    // reset
    mock.reset()

    #expect(mock.createScheduleCallCount == 0)
    #expect(mock.getScheduleCallCount == 0)
    #expect(mock.deleteScheduleCallCount == 0)
    #expect(mock.createScheduleArguments.isEmpty)
    #expect(mock.getScheduleArguments.isEmpty)
    #expect(mock.deleteScheduleArguments.isEmpty)
  }
}
