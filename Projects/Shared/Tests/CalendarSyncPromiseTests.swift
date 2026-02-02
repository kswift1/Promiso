//
//  CalendarSyncPromiseTests.swift
//  PromisoShared
//
//  CalendarSyncPromise 해시 및 태그 파싱 테스트
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - Content Hash Tests

@Suite("CalendarSyncPromise contentHash 테스트")
struct ContentHashTests {

  @Test("동일한 데이터는 동일한 해시 생성")
  func sameDataProducesSameHash() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let endDate = Date(timeIntervalSince1970: 1700003600)

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "테스트 약속",
      emoji: "📅",
      startAt: date,
      endAt: endDate,
      location: "강남역",
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id2", // ID가 달라도
      title: "테스트 약속",
      emoji: "🎉", // 이모지가 달라도
      startAt: date,
      endAt: endDate,
      location: "강남역",
      groupId: "group2" // 그룹이 달라도
    )

    // title, location, startAt, endAt이 같으면 해시는 같음
    #expect(promise1.contentHash == promise2.contentHash)
  }

  @Test("title 변경 시 해시 변경")
  func titleChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "약속 A",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id1",
      title: "약속 B",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(promise1.contentHash != promise2.contentHash)
  }

  @Test("location 변경 시 해시 변경")
  func locationChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "강남역",
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "홍대입구",
      groupId: "group1"
    )

    #expect(promise1.contentHash != promise2.contentHash)
  }

  @Test("startAt 변경 시 해시 변경")
  func startAtChangeProducesDifferentHash() {
    let date1 = Date(timeIntervalSince1970: 1700000000)
    let date2 = Date(timeIntervalSince1970: 1700000001) // 1초 차이

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date1,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date2,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(promise1.contentHash != promise2.contentHash)
  }

  @Test("endAt 변경 시 해시 변경")
  func endAtChangeProducesDifferentHash() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let endDate1 = Date(timeIntervalSince1970: 1700003600)
    let endDate2 = Date(timeIntervalSince1970: 1700007200)

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: endDate1,
      location: nil,
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: endDate2,
      location: nil,
      groupId: "group1"
    )

    #expect(promise1.contentHash != promise2.contentHash)
  }

  @Test("nil location과 빈 문자열은 같은 해시")
  func nilAndEmptyLocationProduceSameHash() {
    let date = Date(timeIntervalSince1970: 1700000000)

    let promise1 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    let promise2 = CalendarSyncPromise(
      id: "id1",
      title: "약속",
      emoji: "📅",
      startAt: date,
      endAt: nil,
      location: "",
      groupId: "group1"
    )

    #expect(promise1.contentHash == promise2.contentHash)
  }

  @Test("calendarTitle은 이모지 + 제목")
  func calendarTitleFormat() {
    let promise = CalendarSyncPromise(
      id: "id1",
      title: "저녁 식사",
      emoji: "🍽️",
      startAt: Date(),
      endAt: nil,
      location: nil,
      groupId: "group1"
    )

    #expect(promise.calendarTitle == "🍽️ 저녁 식사")
  }
}

// MARK: - Tag Parsing Tests

@Suite("PromisoCalendarTag 파싱 테스트")
struct TagParsingTests {

  @Test("태그 생성")
  func createTag() {
    let tag = PromisoCalendarTag.createTag(promiseId: "abc123", contentHash: "12345678")
    #expect(tag == "[Promiso:abc123:12345678]")
  }

  @Test("태그 파싱 성공")
  func parseTagSuccess() {
    let notes = "[Promiso:abc123:12345678]"
    let parsed = PromisoCalendarTag.parse(from: notes)

    #expect(parsed?.promiseId == "abc123")
    #expect(parsed?.contentHash == "12345678")
  }

  @Test("사용자 메모와 함께 있는 태그 파싱")
  func parseTagWithUserNotes() {
    let notes = "사용자 메모입니다.\n준비물: 노트북\n\n[Promiso:abc123:12345678]"
    let parsed = PromisoCalendarTag.parse(from: notes)

    #expect(parsed?.promiseId == "abc123")
    #expect(parsed?.contentHash == "12345678")
  }

  @Test("태그 없는 notes 파싱 실패")
  func parseTagFailure() {
    let notes = "일반 메모입니다."
    let parsed = PromisoCalendarTag.parse(from: notes)

    #expect(parsed == nil)
  }

  @Test("nil notes 파싱 실패")
  func parseNilNotes() {
    let parsed = PromisoCalendarTag.parse(from: nil)
    #expect(parsed == nil)
  }

  @Test("빈 notes 파싱 실패")
  func parseEmptyNotes() {
    let parsed = PromisoCalendarTag.parse(from: "")
    #expect(parsed == nil)
  }
}

// MARK: - Tag Update Tests

@Suite("PromisoCalendarTag 업데이트 테스트")
struct TagUpdateTests {

  @Test("빈 notes에 태그 추가")
  func updateEmptyNotes() {
    let result = PromisoCalendarTag.updateNotes(
      existingNotes: nil,
      promiseId: "abc123",
      contentHash: "12345678"
    )

    #expect(result == "[Promiso:abc123:12345678]")
  }

  @Test("기존 태그 교체")
  func replaceExistingTag() {
    let existingNotes = "[Promiso:abc123:oldHash]"
    let result = PromisoCalendarTag.updateNotes(
      existingNotes: existingNotes,
      promiseId: "abc123",
      contentHash: "newHash1"
    )

    #expect(result == "[Promiso:abc123:newHash1]")
  }

  @Test("사용자 메모 보존하며 태그 교체")
  func replaceTagPreservingUserNotes() {
    let existingNotes = "사용자 메모\n\n[Promiso:abc123:oldHash]"
    let result = PromisoCalendarTag.updateNotes(
      existingNotes: existingNotes,
      promiseId: "abc123",
      contentHash: "newHash1"
    )

    #expect(result == "사용자 메모\n\n[Promiso:abc123:newHash1]")
  }

  @Test("태그 없는 notes에 태그 추가")
  func addTagToExistingNotes() {
    let existingNotes = "사용자 메모"
    let result = PromisoCalendarTag.updateNotes(
      existingNotes: existingNotes,
      promiseId: "abc123",
      contentHash: "12345678"
    )

    #expect(result == "사용자 메모\n\n[Promiso:abc123:12345678]")
  }
}

// MARK: - User Notes Extraction Tests

@Suite("사용자 메모 추출 테스트")
struct UserNotesExtractionTests {

  @Test("태그만 있는 notes에서 사용자 메모 추출")
  func extractFromTagOnly() {
    let notes = "[Promiso:abc123:12345678]"
    let userNotes = PromisoCalendarTag.extractUserNotes(from: notes)

    #expect(userNotes == nil)
  }

  @Test("사용자 메모와 태그가 있는 notes에서 추출")
  func extractFromNotesWithTag() {
    let notes = "준비물: 노트북\n회의 안건 정리\n\n[Promiso:abc123:12345678]"
    let userNotes = PromisoCalendarTag.extractUserNotes(from: notes)

    #expect(userNotes == "준비물: 노트북\n회의 안건 정리")
  }

  @Test("태그 없는 notes는 그대로 반환")
  func extractFromNotesWithoutTag() {
    let notes = "일반 메모입니다."
    let userNotes = PromisoCalendarTag.extractUserNotes(from: notes)

    #expect(userNotes == "일반 메모입니다.")
  }

  @Test("nil notes에서 추출")
  func extractFromNilNotes() {
    let userNotes = PromisoCalendarTag.extractUserNotes(from: nil)
    #expect(userNotes == nil)
  }
}
