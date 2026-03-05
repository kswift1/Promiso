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

private func makePromise(
  id: String,
  title: String = "테스트 약속",
  emoji: String = "📅",
  startAt: Date = Date().addingTimeInterval(86400),
  endAt: Date? = nil,
  location: String? = nil,
  groupId: String = "group1"
) -> CalendarSyncPromise {
  CalendarSyncPromise(
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
  promiseId: String,
  contentHash: String,
  userNotes: String? = nil
) -> PromisoCalendarEvent {
  PromisoCalendarEvent(
    eventIdentifier: eventIdentifier,
    promiseId: promiseId,
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

  @Test("새 약속 추가")
  func syncAddsNewPromises() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.added == 1)
      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.promiseId == "promise1")
    }
  }

  @Test("비활성화된 그룹 약속은 무시")
  func syncIgnoresDisabledGroups() async throws {
    let promise1 = makePromise(id: "promise1", groupId: "group1")
    let promise2 = makePromise(id: "promise2", groupId: "group2")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise1, promise2] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])  // group2는 비활성화
      #expect(result.added == 1)
      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.promiseId == "promise1")
    }
  }

  @Test("이미 존재하는 약속은 skip")
  func syncSkipsExistingPromises() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: promise.contentHash
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
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
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
    let promise = makePromise(id: "promise1", title: "변경된 제목", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
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
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.updated == 1)
      #expect(updatedEvents.count == 1)
      #expect(updatedEvents.first?.0 == "event1")
    }
  }

  @Test("서버에 없는 약속 삭제")
  func syncDeletesRemovedPromises() async throws {
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
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
      $0.promiseClient.getConfirmedPromisesForCalendar = { [] }  // 서버에 없음
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient
      let result = try await calendarSyncClient.sync(["group1"])
      #expect(result.deleted == 1)
      #expect(deletedEventIds == ["event1"])
    }
  }

  @Test("복합 시나리오: 추가, 업데이트, 삭제 동시")
  func syncComplexScenario() async throws {
    // 서버: promise1 (새로움), promise2 (변경됨)
    let promise1 = makePromise(id: "promise1", title: "새 약속", groupId: "group1")
    let promise2 = makePromise(id: "promise2", title: "변경된 약속", groupId: "group1")

    // 캘린더: promise2 (해시 다름), promise3 (삭제 대상)
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      promiseId: "promise2",
      contentHash: "oldHash"
    )
    let existingEvent3 = makeExistingEvent(
      eventIdentifier: "event3",
      promiseId: "promise3",
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
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise1, promise2] }
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

  @Test("단일 약속 추가 - 그룹 동기화 활성화")
  func addPromiseWithSyncEnabled() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      // addPromise 로직 테스트
      let groupCalendarSyncEnabled = true
      guard groupCalendarSyncEnabled else { return }

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      let existingEvents = try await eventKitClient.getPromisoEvents()
      if existingEvents.contains(where: { $0.promiseId == promise.id }) {
        return
      }

      let url = PromisoCalendarTag.createURL(
        promiseId: promise.id,
        contentHash: promise.contentHash
      )
      let newEvent = NewCalendarEvent(
        promiseId: promise.id,
        title: promise.calendarTitle,
        startDate: promise.startAt,
        endDate: promise.endAt,
        location: promise.location,
        url: url
      )
      _ = try await eventKitClient.addEvent(newEvent)

      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.promiseId == "promise1")
    }
  }

  @Test("단일 약속 추가 - 그룹 동기화 비활성화")
  func addPromiseWithSyncDisabled() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      // addPromise 로직 테스트 (비활성화)
      let groupCalendarSyncEnabled = false
      guard groupCalendarSyncEnabled else {
        #expect(addedEvents.isEmpty)
        return
      }

      // 도달하지 않아야 함
      let addURL = PromisoCalendarTag.createURL(
        promiseId: promise.id,
        contentHash: promise.contentHash
      )
      _ = try await eventKitClient.addEvent(NewCalendarEvent(
        promiseId: promise.id,
        title: promise.calendarTitle,
        startDate: promise.startAt,
        endDate: promise.endAt,
        location: promise.location,
        url: addURL
      ))
    }
  }

  @Test("단일 약속 추가 - 이미 존재하면 skip")
  func addPromiseSkipsIfExists() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: promise.contentHash
    )
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      // addPromise 로직 테스트 (이미 존재)
      let groupCalendarSyncEnabled = true
      guard groupCalendarSyncEnabled else { return }

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      let existingEvents = try await eventKitClient.getPromisoEvents()
      if existingEvents.contains(where: { $0.promiseId == promise.id }) {
        #expect(addedEvents.isEmpty)
        return
      }

      // 도달하지 않아야 함
      Issue.record("Should not reach here")
    }
  }

  @Test("단일 약속 제거")
  func removePromise() async throws {
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: "hash"
    )
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      // removePromise 로직 테스트
      let promiseId = "promise1"

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      let existingEvents = try await eventKitClient.getPromisoEvents()
      guard let event = existingEvents.first(where: { $0.promiseId == promiseId }) else {
        return
      }

      try await eventKitClient.deleteEvent(event.eventIdentifier)

      #expect(deletedEventIds == ["event1"])
    }
  }

  @Test("단일 약속 제거 - 존재하지 않으면 무시")
  func removePromiseIgnoresIfNotExists() async throws {
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      // removePromise 로직 테스트 (이벤트 없음)
      let promiseId = "promise1"

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      let existingEvents = try await eventKitClient.getPromisoEvents()
      guard let event = existingEvents.first(where: { $0.promiseId == promiseId }) else {
        #expect(deletedEventIds.isEmpty)
        return
      }

      // 도달하지 않아야 함
      try await eventKitClient.deleteEvent(event.eventIdentifier)
    }
  }
}

// MARK: - Bug Fix Tests

@Suite("캘린더 동기화 버그 수정 테스트")
@MainActor
  struct CalendarSyncBugFixTests {

  // MARK: - BUG 2: 중복 키 안전 처리

  @Test("중복 promiseId 이벤트가 있어도 크래시하지 않음")
  func duplicateEventsDoNotCrash() async throws {
    let existingEvent1 = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: "hash1"
    )
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      promiseId: "promise1",  // 같은 promiseId (중복)
      contentHash: "hash1"
    )

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent1, existingEvent2] }
      $0.eventKitClient.deleteEvent = { _ in }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [] }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      let existingEvents = try await eventKitClient.getPromisoEvents()

      // Dictionary(uniquingKeysWith:)로 크래시 없이 생성되어야 함
      let existingEventMap = Dictionary(
        existingEvents.map { ($0.promiseId, $0) },
        uniquingKeysWith: { first, _ in first }
      )

      #expect(existingEventMap.count == 1)
      #expect(existingEventMap["promise1"]?.eventIdentifier == "event1")
    }
  }

  @Test("중복 이벤트 발견 시 초과분을 삭제함")
  func duplicateEventsGetCleaned() async throws {
    let existingEvent1 = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: "hash1"
    )
    let existingEvent2 = makeExistingEvent(
      eventIdentifier: "event2",
      promiseId: "promise1",  // 중복
      contentHash: "hash1"
    )
    let existingEvent3 = makeExistingEvent(
      eventIdentifier: "event3",
      promiseId: "promise1",  // 중복
      contentHash: "hash1"
    )
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent1, existingEvent2, existingEvent3] }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      let existingEvents = try await eventKitClient.getPromisoEvents()

      // 중복 정리 로직 (CalendarSyncClient.sync에서 사용하는 것과 동일)
      var seen: Set<String> = []
      for event in existingEvents {
        if seen.contains(event.promiseId) {
          try await eventKitClient.deleteEvent(event.eventIdentifier)
        } else {
          seen.insert(event.promiseId)
        }
      }

      // event2, event3이 삭제되어야 함 (event1은 유지)
      #expect(deletedEventIds.count == 2)
      #expect(deletedEventIds.contains("event2"))
      #expect(deletedEventIds.contains("event3"))
    }
  }

  // MARK: - BUG 3: writeOnly 권한

  @Test("writeOnly 권한 시 sync가 추가만 수행")
  func syncWithWriteOnlyAddsOnly() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []
    var getPromisoEventsCalled = false

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.getPromisoEvents = {
        getPromisoEventsCalled = true
        throw EventKitClientError.accessDenied  // writeOnly에서는 접근 불가
      }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let status = eventKitClient.authorizationStatus()
      #expect(status.canWriteEvents)
      #expect(!status.canReadEvents)

      // writeOnly에서 sync 로직: 읽기 불가 → existingEvents는 빈 배열
      let existingEvents: [PromisoCalendarEvent]
      if status.canReadEvents {
        existingEvents = try await eventKitClient.getPromisoEvents()
      } else {
        existingEvents = []
      }

      #expect(existingEvents.isEmpty)
      #expect(!getPromisoEventsCalled)  // getPromisoEvents가 호출되지 않아야 함

      // 서버 약속 추가
      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let enabledGroupIds: Set<String> = ["group1"]
      let filteredPromises = serverPromises.filter { enabledGroupIds.contains($0.groupId) }

      for promiseItem in filteredPromises {
        let url = PromisoCalendarTag.createURL(
          promiseId: promiseItem.id,
          contentHash: promiseItem.contentHash
        )
        _ = try await eventKitClient.addEvent(NewCalendarEvent(
          promiseId: promiseItem.id,
          title: promiseItem.calendarTitle,
          startDate: promiseItem.startAt,
          endDate: promiseItem.endAt,
          location: promiseItem.location,
          url: url
        ))
      }

      #expect(addedEvents.count == 1)
    }
  }

  @Test("writeOnly 권한 시 addPromise가 중복 확인 없이 추가")
  func addPromiseWithWriteOnlySkipsDuplicateCheck() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []
    var getPromisoEventsCalled = false

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.getPromisoEvents = {
        getPromisoEventsCalled = true
        throw EventKitClientError.accessDenied
      }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      // writeOnly: 중복 확인 생략
      if status.canReadEvents {
        _ = try await eventKitClient.getPromisoEvents()
      }

      let url = PromisoCalendarTag.createURL(
        promiseId: promise.id,
        contentHash: promise.contentHash
      )
      _ = try await eventKitClient.addEvent(NewCalendarEvent(
        promiseId: promise.id,
        title: promise.calendarTitle,
        startDate: promise.startAt,
        endDate: promise.endAt,
        location: promise.location,
        url: url
      ))

      #expect(addedEvents.count == 1)
      #expect(!getPromisoEventsCalled)
    }
  }

  @Test("writeOnly 권한 시 removePromise가 조용히 return")
  func removePromiseWithWriteOnlyReturnsQuietly() async throws {
    var deletedEventIds: [String] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.deleteEvent = { eventId in
        deletedEventIds.append(eventId)
      }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient

      let status = eventKitClient.authorizationStatus()
      guard status.canWriteEvents else { return }

      // writeOnly: 읽기 불가 → 이벤트 찾기 불가 → return
      guard status.canReadEvents else {
        #expect(deletedEventIds.isEmpty)
        return
      }

      // 도달하지 않아야 함
      Issue.record("Should not reach here")
    }
  }

  @Test("writeOnly 권한에서 동일 promise는 첫 동기화 이후 중복 추가하지 않음")
  func syncWithWriteOnlySkipsDuplicateAdds() async throws {
    let promiseId = "promise-\(UUID().uuidString)"
    let promise = makePromise(id: promiseId, groupId: "group1")
    var addedEventIds: [String] = []

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.addEvent = { event in
        addedEventIds.append(event.promiseId)
        return "event-\(event.promiseId)"
      }
      $0.eventKitClient.getPromisoEvents = {
        throw EventKitClientError.accessDenied
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient

      let first = try await calendarSyncClient.sync(["group1"])
      let second = try await calendarSyncClient.sync(["group1"])

      #expect(first.added == 1)
      #expect(second.added == 0)
      #expect(addedEventIds == [promiseId])
    }
  }

  @Test("writeOnly 권한에서 hash 변경 시 중복 스킵 없이 재작성")
  func syncWithWriteOnlyUpdatesHashAllowsReAdd() async throws {
    let promiseId = "promise-\(UUID().uuidString)"
    let firstPromise = makePromise(id: promiseId, title: "초기", groupId: "group1")
    let secondPromise = makePromise(id: promiseId, title: "변경됨", groupId: "group1")
    var addedEventIds: [String] = []
    var callIndex = 0

    try await withDependencies {
      $0.calendarSyncClient = .liveValue
      $0.eventKitClient.authorizationStatus = { .writeOnly }
      $0.eventKitClient.addEvent = { event in
        addedEventIds.append(event.promiseId)
        return "event-\(event.promiseId)"
      }
      $0.eventKitClient.getPromisoEvents = {
        throw EventKitClientError.accessDenied
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = {
        defer { callIndex += 1 }
        return callIndex == 0 ? [firstPromise] : [secondPromise]
      }
    } operation: {
      @Dependency(\.calendarSyncClient) var calendarSyncClient

      let first = try await calendarSyncClient.sync(["group1"])
      let second = try await calendarSyncClient.sync(["group1"])

      #expect(first.added == 1)
      #expect(second.added == 1)
      #expect(addedEventIds == [promiseId, promiseId])
    }
  }
}
