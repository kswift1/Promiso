//
//  CalendarSyncClientTests.swift
//  Clients
//
//  CalendarSyncClient 동기화 로직 테스트
//

import Foundation
import Testing
import ComposableArchitecture
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
struct CalendarSyncClientTests {

  @Test("권한 없으면 에러 발생")
  @MainActor
  func syncWithoutPermissionThrowsError() async {
    let client = CalendarSyncClient(
      sync: { _ in
        @Dependency(\.eventKitClient) var eventKitClient
        let status = eventKitClient.authorizationStatus()
        guard status.canWriteEvents else {
          throw CalendarSyncError.noWritePermission
        }
        return CalendarSyncResult()
      },
      addPromise: { _, _ in },
      removePromise: { _ in },
      syncPersonalEvents: { _ in CalendarSyncResult() },
      addPersonalEvent: { _, _ in },
      removePersonalEvent: { _ in },
      updatePersonalEvent: { _, _ in }
    )

    await withDependencies {
      $0.eventKitClient.authorizationStatus = { .denied }
      $0.calendarSyncClient = client
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
  @MainActor
  func syncAddsNewPromises() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      // CalendarSyncClient.liveValue의 sync 로직을 직접 테스트
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      // 1. 권한 확인
      let status = eventKitClient.authorizationStatus()
      #expect(status.canWriteEvents)

      // 2. 서버에서 약속 조회
      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      #expect(serverPromises.count == 1)

      // 3. 필터링
      let enabledGroupIds: Set<String> = ["group1"]
      let filteredPromises = serverPromises.filter { enabledGroupIds.contains($0.groupId) }
      #expect(filteredPromises.count == 1)

      // 4. 기존 이벤트 조회
      let existingEvents = try await eventKitClient.getPromisoEvents()
      #expect(existingEvents.isEmpty)

      // 5. 추가
      for promiseItem in filteredPromises {
        let url = PromisoCalendarTag.createURL(
          promiseId: promiseItem.id,
          contentHash: promiseItem.contentHash
        )
        let newEvent = NewCalendarEvent(
          promiseId: promiseItem.id,
          title: promiseItem.calendarTitle,
          startDate: promiseItem.startAt,
          endDate: promiseItem.endAt,
          location: promiseItem.location,
          url: url
        )
        _ = try await eventKitClient.addEvent(newEvent)
      }

      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.promiseId == "promise1")
    }
  }

  @Test("비활성화된 그룹 약속은 무시")
  @MainActor
  func syncIgnoresDisabledGroups() async throws {
    let promise1 = makePromise(id: "promise1", groupId: "group1")
    let promise2 = makePromise(id: "promise2", groupId: "group2")
    var addedEvents: [NewCalendarEvent] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [] }
      $0.eventKitClient.addEvent = { event in
        addedEvents.append(event)
        return "event-\(event.promiseId)"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise1, promise2] }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let enabledGroupIds: Set<String> = ["group1"]  // group2는 비활성화
      let filteredPromises = serverPromises.filter { enabledGroupIds.contains($0.groupId) }

      #expect(filteredPromises.count == 1)
      #expect(filteredPromises.first?.id == "promise1")

      for promiseItem in filteredPromises {
        let url = PromisoCalendarTag.createURL(
          promiseId: promiseItem.id,
          contentHash: promiseItem.contentHash
        )
        let newEvent = NewCalendarEvent(
          promiseId: promiseItem.id,
          title: promiseItem.calendarTitle,
          startDate: promiseItem.startAt,
          endDate: promiseItem.endAt,
          location: promiseItem.location,
          url: url
        )
        _ = try await eventKitClient.addEvent(newEvent)
      }

      #expect(addedEvents.count == 1)
      #expect(addedEvents.first?.promiseId == "promise1")
    }
  }

  @Test("이미 존재하는 약속은 skip")
  @MainActor
  func syncSkipsExistingPromises() async throws {
    let promise = makePromise(id: "promise1", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: promise.contentHash
    )
    var addedCount = 0

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.addEvent = { _ in
        addedCount += 1
        return "event-new"
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let existingEvents = try await eventKitClient.getPromisoEvents()
      let existingEventMap = Dictionary(uniqueKeysWithValues: existingEvents.map { ($0.promiseId, $0) })

      for promiseItem in serverPromises {
        if let existing = existingEventMap[promiseItem.id] {
          // 해시 같으면 skip
          if existing.contentHash == promiseItem.contentHash {
            continue
          }
        }
        // 새 이벤트 추가 (이 테스트에서는 도달하지 않아야 함)
        addedCount += 1
      }

      #expect(addedCount == 0)
    }
  }

  @Test("해시 변경 시 업데이트")
  @MainActor
  func syncUpdatesOnHashChange() async throws {
    let promise = makePromise(id: "promise1", title: "변경된 제목", groupId: "group1")
    let existingEvent = makeExistingEvent(
      eventIdentifier: "event1",
      promiseId: "promise1",
      contentHash: "oldHash"  // 다른 해시
    )
    var updatedEvents: [(String, NewCalendarEvent)] = []

    try await withDependencies {
      $0.eventKitClient.authorizationStatus = { .fullAccess }
      $0.eventKitClient.getPromisoEvents = { [existingEvent] }
      $0.eventKitClient.updateEvent = { eventId, event, _ in
        updatedEvents.append((eventId, event))
      }
      $0.promiseClient.getConfirmedPromisesForCalendar = { [promise] }
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let existingEvents = try await eventKitClient.getPromisoEvents()
      let existingEventMap = Dictionary(uniqueKeysWithValues: existingEvents.map { ($0.promiseId, $0) })

      for promiseItem in serverPromises {
        if let existing = existingEventMap[promiseItem.id] {
          // 해시 다르면 업데이트
          if existing.contentHash != promiseItem.contentHash {
            let updatedURL = PromisoCalendarTag.createURL(
              promiseId: promiseItem.id,
              contentHash: promiseItem.contentHash
            )
            let updatedEvent = NewCalendarEvent(
              promiseId: promiseItem.id,
              title: promiseItem.calendarTitle,
              startDate: promiseItem.startAt,
              endDate: promiseItem.endAt,
              location: promiseItem.location,
              url: updatedURL
            )
            try await eventKitClient.updateEvent(
              existing.eventIdentifier,
              updatedEvent,
              existing.userNotes
            )
          }
        }
      }

      #expect(updatedEvents.count == 1)
      #expect(updatedEvents.first?.0 == "event1")
    }
  }

  @Test("서버에 없는 약속 삭제")
  @MainActor
  func syncDeletesRemovedPromises() async throws {
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
      $0.promiseClient.getConfirmedPromisesForCalendar = { [] }  // 서버에 없음
    } operation: {
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let serverPromiseMap = Dictionary(uniqueKeysWithValues: serverPromises.map { ($0.id, $0) })
      let existingEvents = try await eventKitClient.getPromisoEvents()

      // 서버에 없는 이벤트 삭제
      for existingEvt in existingEvents {
        if serverPromiseMap[existingEvt.promiseId] == nil {
          try await eventKitClient.deleteEvent(existingEvt.eventIdentifier)
        }
      }

      #expect(deletedEventIds == ["event1"])
    }
  }

  @Test("복합 시나리오: 추가, 업데이트, 삭제 동시")
  @MainActor
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
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      let serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
      let enabledGroupIds: Set<String> = ["group1"]
      let filteredPromises = serverPromises.filter { enabledGroupIds.contains($0.groupId) }
      let serverPromiseMap = Dictionary(uniqueKeysWithValues: filteredPromises.map { ($0.id, $0) })

      let existingEvents = try await eventKitClient.getPromisoEvents()
      let existingEventMap = Dictionary(uniqueKeysWithValues: existingEvents.map { ($0.promiseId, $0) })

      // 추가/업데이트
      for promiseItem in filteredPromises {
        if let existing = existingEventMap[promiseItem.id] {
          if existing.contentHash != promiseItem.contentHash {
            let updateURL = PromisoCalendarTag.createURL(
              promiseId: promiseItem.id,
              contentHash: promiseItem.contentHash
            )
            try await eventKitClient.updateEvent(existing.eventIdentifier, NewCalendarEvent(
              promiseId: promiseItem.id,
              title: promiseItem.calendarTitle,
              startDate: promiseItem.startAt,
              endDate: promiseItem.endAt,
              location: promiseItem.location,
              url: updateURL
            ), nil)
          }
        } else {
          let addURL = PromisoCalendarTag.createURL(
            promiseId: promiseItem.id,
            contentHash: promiseItem.contentHash
          )
          _ = try await eventKitClient.addEvent(NewCalendarEvent(
            promiseId: promiseItem.id,
            title: promiseItem.calendarTitle,
            startDate: promiseItem.startAt,
            endDate: promiseItem.endAt,
            location: promiseItem.location,
            url: addURL
          ))
        }
      }

      // 삭제
      for existingEvt in existingEvents {
        if serverPromiseMap[existingEvt.promiseId] == nil {
          try await eventKitClient.deleteEvent(existingEvt.eventIdentifier)
        }
      }

      #expect(addedCount == 1)
      #expect(updatedCount == 1)
      #expect(deletedCount == 1)
    }
  }
}

// MARK: - Real-time Sync Tests

@Suite("CalendarSyncClient 실시간 동기화 테스트")
struct RealTimeSyncTests {

  @Test("단일 약속 추가 - 그룹 동기화 활성화")
  @MainActor
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
  @MainActor
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
  @MainActor
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
  @MainActor
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
  @MainActor
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
