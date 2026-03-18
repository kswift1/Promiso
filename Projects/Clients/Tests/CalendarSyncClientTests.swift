//
//  CalendarSyncClientTests.swift
//  Clients
//
//  CalendarSyncClient 동기화 로직 테스트
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - Test Helpers

private func makeSchedule(
  id: String,
  title: String = "테스트 일정",
  emoji: String = "📅",
  startAt: Date = Date().addingTimeInterval(86400),
  endAt: Date? = nil,
  location: String? = nil,
  groupId: String = "group1"
) -> CalendarSyncSchedule {
  CalendarSyncSchedule(
    id: id,
    title: title,
    emoji: emoji,
    startAt: startAt,
    endAt: endAt,
    location: location,
    groupId: groupId
  )
}

private func makeExistingEvent(
  eventIdentifier: String,
  scheduleId: String,
  contentHash: String,
  userNotes: String? = nil
) -> PromisoCalendarEvent {
  PromisoCalendarEvent(
    eventIdentifier: eventIdentifier,
    scheduleId: scheduleId,
    contentHash: contentHash,
    userNotes: userNotes
  )
}

// MARK: - Sync Logic Tests

@Suite("CalendarSyncClient 동기화 테스트")
@MainActor
struct CalendarSyncClientTests {

  @Test("권한 없으면 에러 발생")
  func syncWithoutPermissionThrowsError() async {
    await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .denied }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient

      do {
        _ = try await calendarSyncClient.sync([])
        Issue.record("Should throw error")
      } catch let error as CalendarSyncError {
        #expect(error == .noWritePermission)
      } catch {
        Issue.record("Unexpected error: \(error)")
      }
    }
  }

  @Test("새 일정 추가")
  func syncAddsNewSchedules() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 1)
      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.scheduleId == "schedule1")
    }
  }

  @Test("비활성화된 그룹 일정은 무시")
  func syncIgnoresDisabledGroups() async throws {
    let schedule1 = makeSchedule(id: "schedule1", groupId: "group1")
    let schedule2 = makeSchedule(id: "schedule2", groupId: "group2")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule1, schedule2] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])  // group2는 비활성화
      #expect(result.added == 1)
      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.scheduleId == "schedule1")
    }
  }

  @Test("이미 존재하는 일정은 skip")
  func syncSkipsExistingSchedules() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    var addedCount = 0

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.addEvent = { _ in
        addedCount += 1
        return "event-new"
      }
      $0.eventKitClient.deleteEvent = { _ in }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 0)
      #expect(result.updated == 0)
      #expect(addedCount == 0)
    }
  }

  @Test("해시 변경 시 업데이트")
  func syncUpdatesOnHashChange() async throws {
    let schedule = makeSchedule(id: "schedule1", title: "변경된 제목", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: "oldHash"  // 다른 해시
    )
    var updatedEvents: [(String, NewCalendarEvent)] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.updateEvent = { eventId, event, _ in
        updatedEvents.append((eventId, event))
      }
      $0.eventKitClient.deleteEvent = { _ in }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.updated == 1)
      #expect(updatedEvents.count == 1)
      #expect(updatedEvents.first?.0 == "event1")
    }
  }

  @Test("서버에 없는 일정 삭제")
  func syncDeletesRemovedSchedules() async throws {
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: "hash"
    )
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [] }  // 서버에 없음
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.deleted == 1)
      #expect(deletedEventIds == ["event1"])
    }
  }

  @Test("복합 시나리오: 추가, 업데이트, 삭제 동시")
  func syncComplexScenario() async throws {
    // 서버: schedule1 (새로움), schedule2 (변경됨)
    let schedule1 = makeSchedule(id: "schedule1", title: "새 일정", groupId: "group1")
    let schedule2 = makeSchedule(id: "schedule2", title: "변경된 일정", groupId: "group1")

    // 캘린더: schedule2 (해시 다름), schedule3 (삭제 대상)
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      scheduleId: "schedule2",
      contentHash: "oldHash"
    )
    let existingEvent3 = makeExistingEvent(
      eventIdentifier: "event3",
      scheduleId: "schedule3",
      contentHash: "hash"
    )

    var addedCount = 0
    var updatedCount = 0
    var deletedCount = 0

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent2, existingEvent3] }
      $0.eventKitClient.addEvent = { _ in
        addedCount += 1
        return "new-event"
      }
      $0.eventKitClient.updateEvent = { _, _, _ in
        updatedCount += 1
      }
      $0.eventKitClient.deleteEvent = { _ in
        deletedCount += 1
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule1, schedule2] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 1)
      #expect(result.updated == 1)
      #expect(result.deleted == 1)
      #expect(addedCount == 1)
      #expect(updatedCount == 1)
      #expect(deletedCount == 1)
    }
  }
}

// MARK: - Real-time Sync Tests

@Suite("CalendarSyncClient 실시간 동기화 테스트")
@MainActor
struct RealTimeSyncTests {

  @Test("단일 일정 추가 - 그룹 동기화 활성화")
  func addScheduleWithSyncEnabled() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.addSchedule(schedule, true)
      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.scheduleId == "schedule1")
    }
  }

  @Test("단일 일정 추가 - 그룹 동기화 비활성화")
  func addScheduleWithSyncDisabled() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.addSchedule(schedule, false)
      #expect(addedEvents.isEmpty)
    }
  }

  @Test("단일 일정 추가 - 이미 존재하면 skip")
  func addScheduleSkipsIfExists() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.addSchedule(schedule, true)
      #expect(addedEvents.isEmpty)
    }
  }

  @Test("단일 일정 제거")
  func removeSchedule() async throws {
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: "hash"
    )
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.removeSchedule("schedule1")
      #expect(deletedEventIds == ["event1"])
    }
  }

  @Test("단일 일정 제거 - 존재하지 않으면 무시")
  func removeScheduleIgnoresIfNotExists() async throws {
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.removeSchedule("schedule1")
      #expect(deletedEventIds.isEmpty)
    }
  }
}

// MARK: - Bug Fix Tests

@Suite("캘린더 동기화 버그 수정 테스트")
@MainActor
struct CalendarSyncBugFixTests {

  // MARK: - BUG 2: 중복 키 안전 처리

  @Test("중복 scheduleId 이벤트가 있어도 크래시하지 않음")
  func duplicateEventsDoNotCrash() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    let existingEvent1 = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent1, existingEvent2] }
      $0.eventKitClient.deleteEvent = { _ in }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      // 크래시 없이 완료되어야 함
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 0)
    }
  }

  @Test("중복 이벤트 발견 시 초과분을 삭제함")
  func duplicateEventsGetCleaned() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    let existingEvent1 = makeExistingEvent(
      eventIdentifier: "event1",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    let existingEvent3 = makeExistingEvent(
      eventIdentifier: "event3",
      scheduleId: "schedule1",
      contentHash: schedule.contentHash
    )
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent1, existingEvent2, existingEvent3] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      _ = try await calendarSyncClient.sync(["group1"])
      // event2, event3이 중복 삭제됨
      #expect(deletedEventIds.contains("event2"))
      #expect(deletedEventIds.contains("event3"))
    }
  }

  // MARK: - BUG 3: writeOnly 권한

  @Test("writeOnly 권한 시 sync가 추가만 수행")
  func syncWithWriteOnlyAddsOnly() async throws {
    let schedule = makeSchedule(id: "schedule1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []
    var getPromisoEventsCalled = false

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.getPromisoEvents = {
        getPromisoEventsCalled = true
        throw EventKitClientError.accessDenied
      }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 1)
      #expect(!getPromisoEventsCalled)
      #expect(addedEvents.count == 1)
    }
  }

  @Test("writeOnly 권한 시 addSchedule가 중복 확인 없이 추가")
  func addScheduleWithWriteOnlySkipsDuplicateCheck() async throws {
    let schedule = makeSchedule(id: "schedule-wo-\(UUID().uuidString)", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []
    var getPromisoEventsCalled = false

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.getPromisoEvents = {
        getPromisoEventsCalled = true
        throw EventKitClientError.accessDenied
      }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.scheduleId)"
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.addSchedule(schedule, true)
      #expect(addedEvents.count == 1)
      #expect(!getPromisoEventsCalled)
    }
  }

  @Test("writeOnly 권한 시 removeSchedule가 조용히 return")
  func removeScheduleWithWriteOnlyReturnsQuietly() async throws {
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      try await calendarSyncClient.removeSchedule("schedule1")
      #expect(deletedEventIds.isEmpty)
    }
  }

  @Test("writeOnly 권한에서 동일 schedule는 첫 동기화 이후 중복 추가하지 않음")
  func syncWithWriteOnlySkipsDuplicateAdds() async throws {
    let scheduleId = "schedule-\(UUID().uuidString)"
    let schedule = makeSchedule(id: scheduleId, groupId: "group1")
    var addedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.addEvent = { event in
        addedEventIds.append(event.scheduleId)
        return "event-\(event.scheduleId)"
      }
      $0.eventKitClient.getPromisoEvents = {
        throw EventKitClientError.accessDenied
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = { [schedule] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient

      let first = try await calendarSyncClient.sync(["group1"])
      let second = try await calendarSyncClient.sync(["group1"])

      #expect(first.added == 1)
      #expect(second.added == 0)
      #expect(addedEventIds == [scheduleId])
    }
  }

  @Test("writeOnly 권한에서 hash 변경 시 중복 스킵 없이 재작성")
  func syncWithWriteOnlyUpdatesHashAllowsReAdd() async throws {
    let scheduleId = "schedule-\(UUID().uuidString)"
    let firstSchedule = makeSchedule(id: scheduleId, title: "초기", groupId: "group1")
    let secondSchedule = makeSchedule(id: scheduleId, title: "변경됨", groupId: "group1")
    var addedEventIds: [String] = []
    var callIndex = 0

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.addEvent = { event in
        addedEventIds.append(event.scheduleId)
        return "event-\(event.scheduleId)"
      }
      $0.eventKitClient.getPromisoEvents = {
        throw EventKitClientError.accessDenied
      }
      $0.scheduleClient.getConfirmedSchedulesForCalendar = {
        defer { callIndex += 1 }
        return callIndex == 0 ? [firstSchedule] : [secondSchedule]
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient

      let first = try await calendarSyncClient.sync(["group1"])
      let second = try await calendarSyncClient.sync(["group1"])

      #expect(first.added == 1)
      #expect(second.added == 1)
      #expect(addedEventIds == [scheduleId, scheduleId])
    }
  }
}
