//
//  PromiseDomainRuleTests.swift
//  Clients
//
//  Layer 1: 도메인 규칙 안전망 테스트
//
//  ## 목적
//  - 도메인 규칙(.ai/domain-rules/promise.md)이 코드에 올바르게 반영되었는지 검증
//  - 규칙 위반 코드가 들어오면 테스트가 실패하여 자동으로 차단
//  - 규칙 ID 태깅으로 규칙 ↔ 테스트 추적성 확보
//
//  ## 원칙
//  - 이 파일의 테스트는 도메인 규칙이 변경되지 않는 한 수정하지 않는다
//  - 테스트 이름에 반드시 [규칙ID]를 포함한다
//  - Model 레벨에서 검증 가능한 규칙만 포함 (Feature 레벨은 별도 파일)
//

import Foundation
import Testing
@testable import Clients

// MARK: - 제약 조건 (Constraints) P1~P8

@Suite("Promise 제약 조건 도메인 규칙")
struct PromiseConstraintRuleTests {

  // MARK: - [P1] 제목 필수

  @Test("[P1] 빈 제목은 무효")
  func p1_emptyTitle_isInvalid() {
    let promise = TestFactories.makePromise(title: "")
    #expect(promise.isTitleValid == false)
  }

  @Test("[P1] 공백만 있는 제목은 무효")
  func p1_whitespaceOnlyTitle_isInvalid() {
    let promise = TestFactories.makePromise(title: "   ")
    #expect(promise.isTitleValid == false)
  }

  @Test("[P1] trim 후 비어있지 않으면 유효")
  func p1_validTitle_isValid() {
    let promise = TestFactories.makePromise(title: "  약속  ")
    #expect(promise.isTitleValid == true)
  }

  // MARK: - [P4] 시작 시간 = 현재보다 미래

  @Test("[P4] 미래 시작 시간은 유효")
  func p4_futureStartTime_isValid() {
    let promise = TestFactories.makePromise(startAt: Date().addingTimeInterval(3600))
    #expect(promise.isStartTimeValid == true)
  }

  @Test("[P4] 과거 시작 시간은 무효")
  func p4_pastStartTime_isInvalid() {
    let promise = TestFactories.makePromise(startAt: Date().addingTimeInterval(-3600))
    #expect(promise.isStartTimeValid == false)
  }

  // MARK: - [P5] 종료 시간 = 시작 시간 이후

  @Test("[P5] 종료 시간이 nil이면 유효")
  func p5_nilEndTime_isValid() {
    let promise = TestFactories.makePromise(endAt: nil)
    #expect(promise.isEndTimeValid == true)
  }

  @Test("[P5] 종료 > 시작이면 유효")
  func p5_endAfterStart_isValid() {
    let start = Date().addingTimeInterval(3600)
    let end = Date().addingTimeInterval(7200)
    let promise = TestFactories.makePromise(startAt: start, endAt: end)
    #expect(promise.isEndTimeValid == true)
  }

  @Test("[P5] 종료 < 시작이면 무효")
  func p5_endBeforeStart_isInvalid() {
    let start = Date().addingTimeInterval(7200)
    let end = Date().addingTimeInterval(3600)
    let promise = TestFactories.makePromise(startAt: start, endAt: end)
    #expect(promise.isEndTimeValid == false)
  }

  @Test("[P5] 종료 == 시작이면 무효")
  func p5_endEqualsStart_isInvalid() {
    let same = Date().addingTimeInterval(3600)
    let promise = TestFactories.makePromise(startAt: same, endAt: same)
    #expect(promise.isEndTimeValid == false)
  }

  // MARK: - [P6] 최소 참여 인원 2명 이상

  @Test("[P6] 최소 인원 2명은 유효")
  func p6_minimumTwo_isValid() {
    let promise = TestFactories.makePromise(minimumParticipants: 2)
    #expect(promise.isMinimumParticipantsValid == true)
  }

  @Test("[P6] 최소 인원 1명은 무효")
  func p6_minimumOne_isInvalid() {
    let promise = TestFactories.makePromise(minimumParticipants: 1)
    #expect(promise.isMinimumParticipantsValid == false)
  }

  @Test("[P6] 최소 인원 0명은 무효")
  func p6_minimumZero_isInvalid() {
    let promise = TestFactories.makePromise(minimumParticipants: 0)
    #expect(promise.isMinimumParticipantsValid == false)
  }
}

// MARK: - 권한 (Permissions) P9~P15

@Suite("Promise 권한 도메인 규칙")
struct PromisePermissionRuleTests {

  // MARK: - [P10] 수정 권한 = 약속 호스트 또는 그룹 호스트

  @Test("[P10] 약속 호스트는 호스트로 판정")
  func p10_promiseHost_isHost() {
    let promise = TestFactories.makePromise(hostId: "user-1")
    #expect(promise.isHost(userId: "user-1") == true)
  }

  @Test("[P10] 약속 호스트가 아니면 호스트 아님")
  func p10_nonHost_isNotHost() {
    let promise = TestFactories.makePromise(hostId: "user-1")
    #expect(promise.isHost(userId: "user-2") == false)
  }

  // MARK: - [P22] 확정 = accepted >= minimumParticipants

  @Test("[P22] accepted >= minimumParticipants이면 확정")
  func p22_enoughAccepted_isConfirmed() {
    let votes = TestFactories.makeVotes(accepted: ["a", "b", "c"])
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    #expect(promise.isConfirmed == true)
  }

  @Test("[P22] accepted < minimumParticipants이면 미확정")
  func p22_notEnoughAccepted_isNotConfirmed() {
    let votes = TestFactories.makeVotes(accepted: ["a"])
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    #expect(promise.isConfirmed == false)
  }
}

// MARK: - 확정/불발 판정 (P22~P26)

@Suite("Promise 확정/불발 판정 도메인 규칙")
struct PromiseResponseStatusRuleTests {

  // MARK: - [P23] 불발 조건 1: 투표 마감 + 미확정

  @Test("[P23] 투표 마감 + 미확정이면 불발")
  func p23_votingClosedAndNotConfirmed_isFailed() {
    let votes = TestFactories.makeVotes(
      accepted: ["a"],
      until: Date().addingTimeInterval(-60) // 이미 마감
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "a")
    #expect(status == .failed)
  }

  // MARK: - [P24] 불발 조건 2: 전원 응답 + 미확정

  @Test("[P24] 전원 응답 + 미확정이면 불발")
  func p24_allRespondedNotConfirmed_isFailed() {
    let votes = TestFactories.makeVotes(
      accepted: ["a"],
      declined: ["b", "c"]
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "a", totalGroupMembers: 3)
    #expect(status == .failed)
  }

  // MARK: - [P25] 불발 조건 3: 남은 인원 전원 수락해도 최소인원 불가

  @Test("[P25] 남은 가능 인원으로 최소인원 도달 불가시 불발")
  func p25_cannotReachMinimum_isFailed() {
    let votes = TestFactories.makeVotes(
      accepted: ["a"],
      declined: ["b", "c", "d"]
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "a", totalGroupMembers: 5)
    #expect(status == .failed)
  }

  // MARK: - [P26] 응답 상태 우선순위: failed > needResponse > confirmed > responded

  @Test("[P26] 미응답자는 확정 여부와 무관하게 needResponse")
  func p26_pendingUser_needsResponse() {
    let votes = TestFactories.makeVotes(accepted: ["a", "b", "c"])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    // "d"는 투표 안 함
    let status = promise.responseStatus(currentUserId: "d")
    #expect(status == .needResponse)
  }

  @Test("[P26] 응답 완료 + 확정이면 confirmed")
  func p26_respondedAndConfirmed_isConfirmed() {
    let votes = TestFactories.makeVotes(accepted: ["a", "b", "c"])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    let status = promise.responseStatus(currentUserId: "a")
    #expect(status == .confirmed)
  }

  @Test("[P26] 응답 완료 + 미확정이면 responded")
  func p26_respondedButNotConfirmed_isResponded() {
    let votes = TestFactories.makeVotes(accepted: ["a"])
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "a")
    #expect(status == .responded)
  }
}

// MARK: - 시간 기반 상태 (P34~P37)

@Suite("Promise 시간 기반 상태 도메인 규칙")
struct PromiseTimeStatusRuleTests {

  // MARK: - [P34] 진행 중 (isOngoing)

  @Test("[P34] 시작~종료 사이면 진행 중")
  func p34_betweenStartAndEnd_isOngoing() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(-3600),
      endAt: Date().addingTimeInterval(3600)
    )
    #expect(promise.isOngoing == true)
  }

  @Test("[P34] 종료 없으면 시작 이후 진행 중")
  func p34_noEndAfterStart_isOngoing() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(-3600),
      endAt: nil
    )
    #expect(promise.isOngoing == true)
  }

  // MARK: - [P35] 지난 약속 (isPast)

  @Test("[P35] 종료 시간 지나면 과거")
  func p35_afterEnd_isPast() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(-7200),
      endAt: Date().addingTimeInterval(-3600)
    )
    #expect(promise.isPast == true)
  }

  @Test("[P35] 종료 없으면 시작 이후가 과거")
  func p35_noEndAfterStart_isPast() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(-3600),
      endAt: nil
    )
    #expect(promise.isPast == true)
  }

  // MARK: - [P36] 다가오는 약속 (isUpcoming)

  @Test("[P36] 시작 전이면 다가오는 약속")
  func p36_beforeStart_isUpcoming() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(3600)
    )
    #expect(promise.isUpcoming == true)
  }

  @Test("[P36] 시작 후면 다가오는 약속 아님")
  func p36_afterStart_isNotUpcoming() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(-3600)
    )
    #expect(promise.isUpcoming == false)
  }
}

// MARK: - 표시 규칙 (P20, P38~P45)

@Suite("Promise 표시 도메인 규칙")
struct PromiseDisplayRuleTests {

  // MARK: - [P20] 기본 이모지 "📌"

  @Test("[P20] 이모지 설정 시 해당 이모지 표시")
  func p20_customEmoji_displaysCustom() {
    let promise = TestFactories.makePromise(emoji: "🎉")
    #expect(promise.displayEmoji == "🎉")
  }

  @Test("[P20] 이모지 nil이면 기본값 📌")
  func p20_nilEmoji_displaysDefault() {
    let promise = TestFactories.makePromise(emoji: nil)
    #expect(promise.displayEmoji == "📌")
  }

  @Test("[P20] 이모지 빈 문자열이면 기본값 📌")
  func p20_emptyEmoji_displaysDefault() {
    let promise = TestFactories.makePromise(emoji: "")
    #expect(promise.displayEmoji == "📌")
  }
}
