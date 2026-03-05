import Testing
import Foundation
import ComposableArchitecture
@testable import Clients

// MARK: - ScheduleConflictClient Tests

@Suite("ScheduleConflictClient Tests")
struct ScheduleConflictClientTests {

  // MARK: - Test Helpers

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

  private static func makeConflict(
    id: String,
    source: ScheduleConflict.Source = .promise,
    severity: ScheduleConflict.Severity = .confirmed,
    title: String = "테스트",
    emoji: String? = nil,
    startAt: Date = baseDate,
    endAt: Date? = nil,
    overlapMinutes: Int = 60,
    gapMinutes: Int = 0
  ) -> ScheduleConflict {
    ScheduleConflict(
      id: id,
      source: source,
      severity: severity,
      title: title,
      emoji: emoji,
      startAt: startAt,
      endAt: endAt,
      overlapMinutes: overlapMinutes,
      gapMinutes: gapMinutes
    )
  }

  // MARK: - Test 1: 빈 충돌 결과 반환

  @Test("충돌 없으면 빈 배열 반환")
  func noConflictsReturnsEmpty() async throws {
    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, _, _ in [] }
    )

    let result = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    #expect(result.isEmpty)
  }

  // MARK: - Test 2: 확정된 그룹 약속 충돌

  @Test("확정된 그룹 약속 충돌 반환")
  func confirmedPromiseConflict() async throws {
    let expected = Self.makeConflict(
      id: "confirmed-promise",
      source: .promise,
      severity: .confirmed,
      title: "확정 약속",
      emoji: "🎉",
      overlapMinutes: 60
    )

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, _, _ in [expected] }
    )

    let result = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    #expect(result.count == 1)

    let conflict = try #require(result.first)
    #expect(conflict.id == "confirmed-promise")
    #expect(conflict.source == .promise)
    #expect(conflict.severity == .confirmed)
    #expect(conflict.title == "확정 약속")
    #expect(conflict.overlapMinutes == 60)
  }

  // MARK: - Test 3: 미확정 그룹 약속 - pending severity

  @Test("미확정 그룹 약속은 pending severity")
  func pendingPromiseConflict() async throws {
    let expected = Self.makeConflict(
      id: "pending-promise",
      source: .promise,
      severity: .pending,
      title: "미확정 약속"
    )

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, _, _ in [expected] }
    )

    let result = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    let conflict = try #require(result.first)
    #expect(conflict.severity == .pending)
  }

  // MARK: - Test 4: 개인 일정 - 항상 confirmed

  @Test("개인 일정 충돌은 항상 confirmed")
  func personalEventAlwaysConfirmed() async throws {
    let expected = Self.makeConflict(
      id: "event-1",
      source: .personalEvent,
      severity: .confirmed,
      title: "개인 일정",
      emoji: "🏃"
    )

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, _, _ in [expected] }
    )

    let result = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    let conflict = try #require(result.first)
    #expect(conflict.source == .personalEvent)
    #expect(conflict.severity == .confirmed)
    #expect(conflict.emoji == "🏃")
  }

  // MARK: - Test 5: excludeIds 전달 확인

  @Test("excludeIds가 클라이언트에 올바르게 전달됨")
  func excludeIdsPassedCorrectly() async throws {
    var receivedExcludeIds: Set<String>?

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, excludeIds, _ in
        receivedExcludeIds = excludeIds
        return []
      }
    )

    _ = try await client.checkConflicts("user1", Self.baseDate, nil, ["self-event", "other-event"], 0)
    #expect(receivedExcludeIds == ["self-event", "other-event"])
  }

  // MARK: - Test 6: endAt nil 전달 확인

  @Test("endAt nil이 올바르게 전달됨")
  func nilEndAtPassedCorrectly() async throws {
    var receivedEndAt: Date?
    var endAtWasCalled = false

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, endAt, _, _ in
        endAtWasCalled = true
        receivedEndAt = endAt
        return []
      }
    )

    _ = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    #expect(endAtWasCalled)
    #expect(receivedEndAt == nil)
  }

  // MARK: - Test 7: 혼합 충돌 결과

  @Test("그룹 약속과 개인 일정 혼합 충돌")
  func mixedConflicts() async throws {
    let conflicts = [
      Self.makeConflict(id: "promise-1", source: .promise, severity: .confirmed, overlapMinutes: 90),
      Self.makeConflict(id: "promise-2", source: .promise, severity: .pending, overlapMinutes: 60),
      Self.makeConflict(id: "event-1", source: .personalEvent, severity: .confirmed, overlapMinutes: 30),
    ]

    let client = ScheduleConflictClient(
      checkConflicts: { _, _, _, _, _ in conflicts }
    )

    let result = try await client.checkConflicts("user1", Self.baseDate, nil, [], 0)
    #expect(result.count == 3)

    let promiseConflicts = result.filter { $0.source == .promise }
    let eventConflicts = result.filter { $0.source == .personalEvent }
    #expect(promiseConflicts.count == 2)
    #expect(eventConflicts.count == 1)
  }

  // MARK: - Test 8: startAt/endAt 전달 확인

  @Test("startAt과 endAt이 올바르게 전달됨")
  func startAtEndAtPassedCorrectly() async throws {
    var receivedStartAt: Date?
    var receivedEndAt: Date?

    let endDate = Self.baseDate.addingTimeInterval(2 * 3600)

    let client = ScheduleConflictClient(
      checkConflicts: { _, startAt, endAt, _, _ in
        receivedStartAt = startAt
        receivedEndAt = endAt
        return []
      }
    )

    _ = try await client.checkConflicts("user1", Self.baseDate, endDate, [], 0)
    #expect(receivedStartAt == Self.baseDate)
    #expect(receivedEndAt == endDate)
  }

  // MARK: - Test 9: TCA Dependency 등록 확인

  @Test("testValue는 unimplemented")
  func testValueIsUnimplemented() async {
    let client = ScheduleConflictClient.testValue
    #expect(client.checkConflicts != nil)
  }

  // MARK: - Test 10: previewValue는 빈 배열 반환

  @Test("previewValue는 빈 배열 반환")
  func previewValueReturnsEmpty() async throws {
    let result = try await ScheduleConflictClient.previewValue.checkConflicts("user1", Self.baseDate, nil, [], 0)
    #expect(result.isEmpty)
  }
}
