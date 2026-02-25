import Testing
import Foundation
import ComposableArchitecture
@testable import Clients

// MARK: - ScheduleConflictClient Tests

@Suite("ScheduleConflictClient Tests")
struct ScheduleConflictClientTests {

  // MARK: - Test Helpers

  /// 기준 시간 (테스트 안정성을 위해 고정)
  private static let baseDate: Date = {
    var components = DateComponents()
    components.year = 2025
    components.month = 6
    components.day = 15
    components.hour = 14
    components.minute = 0
    components.second = 0
    return Calendar.current.date(from: components)!
  }()

  /// 테스트용 PromiseModel 생성 헬퍼
  private static func makePromise(
    id: String = "promise-1",
    title: String = "테스트 약속",
    emoji: String? = "📌",
    startAt: Date,
    endAt: Date? = nil,
    isConfirmed: Bool = true,
    minimumParticipants: Int = 2
  ) -> PromiseModel {
    let acceptedMembers: [String] = isConfirmed
      ? Array((0..<minimumParticipants).map { "user-\($0)" })
      : ["user-0"]
    return PromiseModel(
      id: id,
      title: title,
      emoji: emoji,
      minimumParticipants: minimumParticipants,
      votes: PromiseVotesModel(
        accepted: acceptedMembers,
        declined: [],
        until: Date.distantFuture
      ),
      startAt: startAt,
      endAt: endAt
    )
  }

  /// 테스트용 PersonalEventModel 생성 헬퍼
  private static func makeEvent(
    id: String = "event-1",
    title: String = "테스트 일정",
    emoji: String? = "📅",
    startAt: Date,
    endAt: Date? = nil
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      startAt: startAt,
      endAt: endAt
    )
  }

  // MARK: - Test 1: 겹치는 일정이 없으면 빈 배열 반환

  @Test("겹치는 일정이 없으면 빈 배열 반환")
  func noConflictsReturnsEmpty() async throws {
    let newStart = Self.baseDate
    // 기존 약속은 새 약속보다 훨씬 이전에 끝남 (겹침 없음)
    let existingPromise = Self.makePromise(
      startAt: Self.baseDate.addingTimeInterval(-10 * 3600),
      endAt: Self.baseDate.addingTimeInterval(-8 * 3600)
    )
    let existingEvent = Self.makeEvent(
      startAt: Self.baseDate.addingTimeInterval(-10 * 3600),
      endAt: Self.baseDate.addingTimeInterval(-8 * 3600)
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [existingPromise]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        [existingEvent]
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, nil)
    }

    #expect(result.isEmpty)
  }

  // MARK: - Test 2: 확정된 그룹 약속 겹침 감지

  @Test("확정된 그룹 약속 겹침 감지")
  func confirmedPromiseConflictDetected() async throws {
    let newStart = Self.baseDate
    let newEnd = Self.baseDate.addingTimeInterval(2 * 3600) // 14:00 ~ 16:00

    // 기존 확정 약속: 15:00 ~ 17:00 (1시간 겹침)
    let existingPromise = Self.makePromise(
      id: "confirmed-promise",
      title: "확정된 약속",
      startAt: Self.baseDate.addingTimeInterval(1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(3 * 3600),
      isConfirmed: true
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [existingPromise]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        []
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 1)

    let conflict = try #require(result.first)
    #expect(conflict.id == "confirmed-promise")
    #expect(conflict.source == .promise)
    #expect(conflict.severity == .confirmed)
    #expect(conflict.title == "확정된 약속")
    #expect(conflict.overlapMinutes == 60)
  }

  // MARK: - Test 3: 미확정 그룹 약속 겹침 감지 - pending severity

  @Test("미확정 그룹 약속 겹침 감지 - pending severity")
  func pendingPromiseConflictHasPendingSeverity() async throws {
    let newStart = Self.baseDate
    let newEnd = Self.baseDate.addingTimeInterval(2 * 3600) // 14:00 ~ 16:00

    // 기존 미확정 약속: 13:00 ~ 15:00 (1시간 겹침)
    let existingPromise = Self.makePromise(
      id: "pending-promise",
      title: "미확정 약속",
      startAt: Self.baseDate.addingTimeInterval(-1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(1 * 3600),
      isConfirmed: false
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [existingPromise]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        []
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 1)

    let conflict = try #require(result.first)
    #expect(conflict.id == "pending-promise")
    #expect(conflict.source == .promise)
    #expect(conflict.severity == .pending)
  }

  // MARK: - Test 4: 개인 일정 겹침 - 항상 confirmed severity

  @Test("개인 일정 겹침 - 항상 confirmed severity")
  func personalEventConflictAlwaysConfirmed() async throws {
    let newStart = Self.baseDate
    let newEnd = Self.baseDate.addingTimeInterval(2 * 3600) // 14:00 ~ 16:00

    // 기존 개인 일정: 15:00 ~ 18:00 (1시간 겹침)
    let existingEvent = Self.makeEvent(
      id: "personal-event-1",
      title: "개인 일정",
      emoji: "🏃",
      startAt: Self.baseDate.addingTimeInterval(1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(4 * 3600)
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        []
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        [existingEvent]
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 1)

    let conflict = try #require(result.first)
    #expect(conflict.id == "personal-event-1")
    #expect(conflict.source == .personalEvent)
    #expect(conflict.severity == .confirmed)
    #expect(conflict.title == "개인 일정")
    #expect(conflict.emoji == "🏃")
  }

  // MARK: - Test 5: endAt nil일 때 기본 2시간 적용

  @Test("endAt nil일 때 기본 2시간 적용")
  func nilEndAtUsesDefaultTwoHours() async throws {
    let newStart = Self.baseDate // 14:00, endAt = nil -> effectiveEnd = 16:00

    // 기존 약속: 15:30 ~ 17:00 (30분 겹침: 15:30 ~ 16:00)
    let existingPromise = Self.makePromise(
      id: "overlap-with-default",
      title: "기본시간 약속",
      startAt: Self.baseDate.addingTimeInterval(1.5 * 3600),
      endAt: Self.baseDate.addingTimeInterval(3 * 3600),
      isConfirmed: true
    )

    // endAt = nil -> effectiveEnd = baseDate + 2h
    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [existingPromise]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        []
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, nil)
    }

    #expect(result.count == 1)

    let conflict = try #require(result.first)
    // 겹침: max(15:30, 14:00)=15:30 ~ min(17:00, 16:00)=16:00 = 30분
    #expect(conflict.overlapMinutes == 30)
  }

  // MARK: - Test 6: overlapMinutes 정확히 계산

  @Test("overlapMinutes 정확히 계산")
  func overlapMinutesCalculatedCorrectly() async throws {
    let newStart = Self.baseDate // 14:00
    let newEnd = Self.baseDate.addingTimeInterval(3 * 3600) // 17:00

    // 기존 약속: 15:00 ~ 16:30 (완전히 새 범위 안에 포함, 90분 겹침)
    let fullyContained = Self.makePromise(
      id: "fully-contained",
      title: "완전 포함 약속",
      startAt: Self.baseDate.addingTimeInterval(1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(2.5 * 3600),
      isConfirmed: true
    )

    // 기존 약속: 13:00 ~ 15:00 (부분 겹침, 60분)
    let partialBefore = Self.makePromise(
      id: "partial-before",
      title: "앞부분 겹침",
      startAt: Self.baseDate.addingTimeInterval(-1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(1 * 3600),
      isConfirmed: true
    )

    // 기존 약속: 16:00 ~ 18:00 (부분 겹침, 60분)
    let partialAfter = Self.makePromise(
      id: "partial-after",
      title: "뒷부분 겹침",
      startAt: Self.baseDate.addingTimeInterval(2 * 3600),
      endAt: Self.baseDate.addingTimeInterval(4 * 3600),
      isConfirmed: true
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [fullyContained, partialBefore, partialAfter]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        []
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 3)

    // 결과는 overlapMinutes 내림차순 정렬
    let minutesList = result.map(\.overlapMinutes)
    #expect(minutesList == [90, 60, 60])

    // 각 개별 검증
    let contained = result.first { $0.id == "fully-contained" }
    #expect(contained?.overlapMinutes == 90) // min(16:30,17:00)-max(15:00,14:00) = 16:30-15:00 = 90m

    let before = result.first { $0.id == "partial-before" }
    #expect(before?.overlapMinutes == 60) // min(15:00,17:00)-max(13:00,14:00) = 15:00-14:00 = 60m

    let after = result.first { $0.id == "partial-after" }
    #expect(after?.overlapMinutes == 60) // min(18:00,17:00)-max(16:00,14:00) = 17:00-16:00 = 60m
  }

  // MARK: - Test 7: 결과 overlapMinutes 내림차순 정렬

  @Test("결과 overlapMinutes 내림차순 정렬")
  func resultsSortedByOverlapMinutesDescending() async throws {
    let newStart = Self.baseDate // 14:00
    let newEnd = Self.baseDate.addingTimeInterval(4 * 3600) // 18:00

    // 30분 겹침: 17:30 ~ 19:00 (17:30~18:00 = 30분)
    let small = Self.makePromise(
      id: "small-overlap",
      title: "작은 겹침",
      startAt: Self.baseDate.addingTimeInterval(3.5 * 3600),
      endAt: Self.baseDate.addingTimeInterval(5 * 3600),
      isConfirmed: true
    )

    // 120분 겹침: 14:00 ~ 16:00 (완전 겹침 = 120분)
    let large = Self.makeEvent(
      id: "large-overlap",
      title: "큰 겹침",
      startAt: Self.baseDate,
      endAt: Self.baseDate.addingTimeInterval(2 * 3600)
    )

    // 60분 겹침: 15:00 ~ 16:00 (완전 겹침 = 60분)
    let medium = Self.makeEvent(
      id: "medium-overlap",
      title: "중간 겹침",
      startAt: Self.baseDate.addingTimeInterval(1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(2 * 3600)
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [small]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        [large, medium]
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 3)

    // 내림차순 정렬 확인
    let minutesList = result.map(\.overlapMinutes)
    #expect(minutesList == [120, 60, 30])

    #expect(result[0].id == "large-overlap")
    #expect(result[1].id == "medium-overlap")
    #expect(result[2].id == "small-overlap")
  }

  // MARK: - Test 8: 그룹 약속과 개인 일정 혼합 충돌 감지

  @Test("그룹 약속과 개인 일정 혼합 충돌 감지")
  func mixedPromiseAndPersonalEventConflicts() async throws {
    let newStart = Self.baseDate // 14:00
    let newEnd = Self.baseDate.addingTimeInterval(3 * 3600) // 17:00

    // 확정 그룹 약속: 15:00 ~ 16:00 (60분 겹침)
    let confirmedPromise = Self.makePromise(
      id: "mix-confirmed-promise",
      title: "확정 약속",
      emoji: "🎉",
      startAt: Self.baseDate.addingTimeInterval(1 * 3600),
      endAt: Self.baseDate.addingTimeInterval(2 * 3600),
      isConfirmed: true
    )

    // 미확정 그룹 약속: 16:00 ~ 18:00 (60분 겹침)
    let pendingPromise = Self.makePromise(
      id: "mix-pending-promise",
      title: "미확정 약속",
      emoji: "⏳",
      startAt: Self.baseDate.addingTimeInterval(2 * 3600),
      endAt: Self.baseDate.addingTimeInterval(4 * 3600),
      isConfirmed: false
    )

    // 개인 일정: 13:30 ~ 14:30 (30분 겹침)
    let personalEvent = Self.makeEvent(
      id: "mix-personal-event",
      title: "개인 일정",
      emoji: "🏃",
      startAt: Self.baseDate.addingTimeInterval(-0.5 * 3600),
      endAt: Self.baseDate.addingTimeInterval(0.5 * 3600)
    )

    let result = try await withDependencies {
      $0.promiseClient.getAcceptedPromisesByDateRange = { _, _ in
        [confirmedPromise, pendingPromise]
      }
      $0.personalEventClient.getEventsByDateRange = { _, _ in
        [personalEvent]
      }
    } operation: {
      try await ScheduleConflictClient.liveValue.checkConflicts("user1", newStart, newEnd)
    }

    #expect(result.count == 3)

    // 내림차순 정렬: 60, 60, 30
    #expect(result[0].overlapMinutes == 60)
    #expect(result[1].overlapMinutes == 60)
    #expect(result[2].overlapMinutes == 30)

    // 소스 타입 확인
    let promiseConflicts = result.filter { $0.source == .promise }
    let eventConflicts = result.filter { $0.source == .personalEvent }
    #expect(promiseConflicts.count == 2)
    #expect(eventConflicts.count == 1)

    // severity 확인
    let confirmed = result.first { $0.id == "mix-confirmed-promise" }
    #expect(confirmed?.severity == .confirmed)

    let pending = result.first { $0.id == "mix-pending-promise" }
    #expect(pending?.severity == .pending)

    let personal = result.first { $0.id == "mix-personal-event" }
    #expect(personal?.severity == .confirmed) // 개인 일정은 항상 confirmed
    #expect(personal?.emoji == "🏃")
  }
}
