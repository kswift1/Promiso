//
//  CalendarSyncScheduleTests.swift
//  PromisoShared
//
//  CalendarSyncSchedule 해시 및 태그 파싱 테스트
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - Content Hash Tests

@Suite("CalendarSyncSchedule contentHash 테스트")
struct ContentHashTests {

  @Test("동일한 데이터는 동일한 해시 생성")
  func sameDataProducesSameHash() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let endDate = Date(timeIntervalSince1970: 1700003600)

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "테스트 일정",
      emoji: "📅",
      startAt: date,
      endAt: endDate,
      location: "강남역",
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id2", // ID가 달라도
      title: "테스트 일정",
      emoji: "🎉", // 이모지가 달라도
      startAt: date,
      endAt: endDate,
      location: "강남역",
      groupId: "group2" // 그룹이 달라도
    )

    // title, location, startAt, endAt이 같으면 해시는 같음
    #expect(schedule1.contentHash == schedule2.contentHash)
  }

  @Test("title 변경 시 해시 변경")
  func titleChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "일정 A",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id1",
      title: "일정 B",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(schedule1.contentHash != schedule2.contentHash)
  }

  @Test("location 변경 시 해시 변경")
  func locationChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "강남역",
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "홍대입구",
      groupId: "group1"
    )

    #expect(schedule1.contentHash != schedule2.contentHash)
  }

  @Test("startAt 변경 시 해시 변경")
  func startAtChangeProducesDifferentHash() {
    let date1 = Date(timeIntervalSince1970: 1700000000)
    let date2 = Date(timeIntervalSince1970: 1700000001) // 1초 차이

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date1,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date2,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(schedule1.contentHash != schedule2.contentHash)
  }

  @Test("endAt 변경 시 해시 변경")
  func endAtChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let endDate1 = Date(timeIntervalSince1970: 1700003600)
    let endDate2 = Date(timeIntervalSince1970: 1700007200)

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: endDate1,
      location: nil,
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: endDate2,
      location: nil,
      groupId: "group1"
    )

    #expect(schedule1.contentHash != schedule2.contentHash)
  }

  @Test("nil location과 빈 문자열은 같은 해시")
  func nilAndEmptyLocationProduceSameHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let schedule1 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let schedule2 = CalendarSyncSchedule(
      id: "id1",
      title: "일정",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "",
      groupId: "group1"
    )

    #expect(schedule1.contentHash == schedule2.contentHash)
  }

  @Test("calendarTitle은 이모지 + 제목")
  func calendarTitleFormat() {
    let schedule = CalendarSyncSchedule(
      id: "id1",
      title: "저녁 식사",
      emoji: "🍽️",
      startAt: Date(),
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(schedule.calendarTitle == "🍽️ 저녁 식사")
  }
}

// MARK: - URL Parsing Tests

@Suite("PromisoCalendarTag URL 테스트")
struct URLTests {

  @Test("URL 생성")
  func createURL() {
    let url = PromisoCalendarTag.createURL(scheduleId: "abc123", contentHash: "12345678")
    #expect(url?.absoluteString == "promiso://promise/abc123?hash=12345678")
  }

  @Test("URL 파싱 성공")
  func parseURLSuccess() {
    let url = URL(string: "promiso://promise/abc123?hash=12345678")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed?.id == "abc123")
    #expect(parsed?.contentHash == "12345678")
  }

  @Test("legacy schedule host도 파싱 성공")
  func parseLegacyScheduleHostSuccess() {
    let url = URL(string: "promiso://schedule/abc123?hash=12345678")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed?.id == "abc123")
    #expect(parsed?.contentHash == "12345678")
  }

  @Test("잘못된 스킴 파싱 실패")
  func parseWrongScheme() {
    let url = URL(string: "https://schedule/abc123?hash=12345678")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed == nil)
  }

  @Test("잘못된 호스트 파싱 실패")
  func parseWrongHost() {
    let url = URL(string: "promiso://other/abc123?hash=12345678")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed == nil)
  }

  @Test("hash 없는 URL 파싱 실패")
  func parseURLWithoutHash() {
    let url = URL(string: "promiso://promise/abc123")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed == nil)
  }

  @Test("nil URL 파싱 실패")
  func parseNilURL() {
    let parsed = PromisoCalendarTag.parse(from: nil)
    #expect(parsed == nil)
  }

  @Test("빈 scheduleId 파싱 실패")
  func parseEmptyScheduleId() {
    let url = URL(string: "promiso://promise/?hash=12345678")
    let parsed = PromisoCalendarTag.parse(from: url)

    #expect(parsed == nil)
  }
}
