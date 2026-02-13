//
//  PromiseModelTests.swift
//  Clients
//
//  PromiseModel 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/PromiseModel.swift`
//
//  ## 테스트 목적
//  - responseStatus, isConfirmed, isOngoing 등 computed property 검증
//  - displayEmoji, 날짜 처리, 시간 텍스트 검증
//  - isHost, myVoteStatus, isVotingClosed 등 비즈니스 로직 검증
//  - shareText, locationText, deadlineText 등 UI 표시용 속성 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - PromiseModel Computed Properties 테스트

@Suite("PromiseModel computed property 테스트")
struct PromiseModelComputedTests {

  // MARK: - isConfirmed 테스트

  @Test("[P22] accepted >= minimumParticipants 이면 확정")
  func isConfirmed_whenAcceptedMeetsMinimum_returnsTrue() {
    let votes = TestFactories.makeVotes(accepted: ["user1", "user2"])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    #expect(promise.isConfirmed == true)
  }

  @Test("[P22] accepted > minimumParticipants 이면 확정")
  func isConfirmed_whenAcceptedExceedsMinimum_returnsTrue() {
    let votes = TestFactories.makeVotes(accepted: ["user1", "user2", "user3"])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    #expect(promise.isConfirmed == true)
  }

  @Test("[P22] accepted < minimumParticipants 이면 미확정")
  func isConfirmed_whenAcceptedBelowMinimum_returnsFalse() {
    let votes = TestFactories.makeVotes(accepted: ["user1"])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    #expect(promise.isConfirmed == false)
  }

  @Test("[P22] accepted 비어있으면 미확정")
  func isConfirmed_whenNoAccepted_returnsFalse() {
    let votes = TestFactories.makeVotes(accepted: [])
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    #expect(promise.isConfirmed == false)
  }

  // MARK: - isHost 테스트

  @Test("[P10] 호스트 ID와 일치하면 호스트")
  func isHost_whenUserIdMatchesHostId_returnsTrue() {
    let promise = TestFactories.makePromise(hostId: "host-user")
    #expect(promise.isHost(userId: "host-user") == true)
  }

  @Test("[P10] 호스트 ID와 불일치하면 호스트 아님")
  func isHost_whenUserIdDoesNotMatch_returnsFalse() {
    let promise = TestFactories.makePromise(hostId: "host-user")
    #expect(promise.isHost(userId: "other-user") == false)
  }

  // MARK: - myVoteStatus 테스트

  @Test("accepted 목록에 포함되면 accepted 상태")
  func myVoteStatus_whenInAccepted_returnsAccepted() {
    let votes = TestFactories.makeVotes(accepted: ["user1", "user2"])
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.myVoteStatus(userId: "user1") == .accepted)
  }

  @Test("declined 목록에 포함되면 declined 상태")
  func myVoteStatus_whenInDeclined_returnsDeclined() {
    let votes = TestFactories.makeVotes(declined: ["user1"])
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.myVoteStatus(userId: "user1") == .declined)
  }

  @Test("어디에도 포함되지 않으면 pending 상태")
  func myVoteStatus_whenNotInAnyList_returnsPending() {
    let votes = TestFactories.makeVotes(accepted: ["user1"], declined: ["user2"])
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.myVoteStatus(userId: "user3") == .pending)
  }

  // MARK: - isVotingClosed 테스트

  @Test("투표 마감 시각이 과거면 마감됨")
  func isVotingClosed_whenDeadlinePassed_returnsTrue() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(-60))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.isVotingClosed == true)
  }

  @Test("투표 마감 시각이 미래면 마감 안됨")
  func isVotingClosed_whenDeadlineInFuture_returnsFalse() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(3600))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.isVotingClosed == false)
  }
}

// MARK: - PromiseModel Time-based Properties 테스트

@Suite("PromiseModel 시간 기반 속성 테스트")
struct PromiseModelTimeTests {

  // MARK: - isOngoing 테스트

  @Test("[P34] 시작 시간 이후이고 종료 시간 전이면 진행 중")
  func isOngoing_whenBetweenStartAndEnd_returnsTrue() {
    let startAt = Date().addingTimeInterval(-3600)  // 1시간 전
    let endAt = Date().addingTimeInterval(3600)      // 1시간 후
    let promise = TestFactories.makePromise(startAt: startAt, endAt: endAt)
    #expect(promise.isOngoing == true)
  }

  @Test("[P34] 시작 시간 전이면 진행 중 아님")
  func isOngoing_whenBeforeStart_returnsFalse() {
    let startAt = Date().addingTimeInterval(3600)
    let endAt = Date().addingTimeInterval(7200)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: endAt)
    #expect(promise.isOngoing == false)
  }

  @Test("[P34] 종료 시간 후이면 진행 중 아님")
  func isOngoing_whenAfterEnd_returnsFalse() {
    let startAt = Date().addingTimeInterval(-7200)
    let endAt = Date().addingTimeInterval(-3600)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: endAt)
    #expect(promise.isOngoing == false)
  }

  @Test("[P34] 종료 시간 없으면 시작 이후 진행 중")
  func isOngoing_whenNoEndAtAndAfterStart_returnsTrue() {
    let startAt = Date().addingTimeInterval(-3600)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: nil)
    #expect(promise.isOngoing == true)
  }

  @Test("[P34] 종료 시간 없고 시작 전이면 진행 중 아님")
  func isOngoing_whenNoEndAtAndBeforeStart_returnsFalse() {
    let startAt = Date().addingTimeInterval(3600)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: nil)
    #expect(promise.isOngoing == false)
  }

  // MARK: - isPast 테스트

  @Test("[P35] 종료 시간이 있고 지났으면 과거 약속")
  func isPast_whenEndAtPassed_returnsTrue() {
    let startAt = Date().addingTimeInterval(-7200)
    let endAt = Date().addingTimeInterval(-3600)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: endAt)
    #expect(promise.isPast == true)
  }

  @Test("[P35] 종료 시간 없고 시작 시간 지났으면 과거 약속")
  func isPast_whenNoEndAtAndStartPassed_returnsTrue() {
    let startAt = Date().addingTimeInterval(-3600)
    let promise = TestFactories.makePromise(startAt: startAt, endAt: nil)
    #expect(promise.isPast == true)
  }

  @Test("[P35] 시작 시간이 미래면 과거 약속 아님")
  func isPast_whenStartInFuture_returnsFalse() {
    let startAt = Date().addingTimeInterval(3600)
    let promise = TestFactories.makePromise(startAt: startAt)
    #expect(promise.isPast == false)
  }

  // MARK: - isUpcoming 테스트

  @Test("[P36] 시작 시간이 미래면 다가오는 약속")
  func isUpcoming_whenStartInFuture_returnsTrue() {
    let startAt = Date().addingTimeInterval(3600)
    let promise = TestFactories.makePromise(startAt: startAt)
    #expect(promise.isUpcoming == true)
  }

  @Test("[P36] 시작 시간이 과거면 다가오는 약속 아님")
  func isUpcoming_whenStartInPast_returnsFalse() {
    let startAt = Date().addingTimeInterval(-3600)
    let promise = TestFactories.makePromise(startAt: startAt)
    #expect(promise.isUpcoming == false)
  }

  // MARK: - isRealtimeShareable 테스트

  @Test("[L7] trackingStartMinutesBefore가 nil이면 공유 불가")
  func isRealtimeShareable_whenNoTracking_returnsFalse() {
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(600),
      trackingStartMinutesBefore: nil
    )
    #expect(promise.isRealtimeShareable == false)
  }

  @Test("[L7] 시작 시간 이전 tracking 범위 내이면 공유 가능")
  func isRealtimeShareable_whenWithinTrackingWindow_returnsTrue() {
    // 10분 후 시작, 30분 전부터 tracking
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(600),
      trackingStartMinutesBefore: 30
    )
    #expect(promise.isRealtimeShareable == true)
  }

  @Test("[L7] 시작 시간이 tracking 범위 밖이면 공유 불가")
  func isRealtimeShareable_whenOutsideTrackingWindow_returnsFalse() {
    // 2시간 후 시작, 30분 전부터 tracking
    let promise = TestFactories.makePromise(
      startAt: Date().addingTimeInterval(7200),
      trackingStartMinutesBefore: 30
    )
    #expect(promise.isRealtimeShareable == false)
  }
}

// MARK: - PromiseModel UI Display 테스트

@Suite("PromiseModel UI 표시 속성 테스트")
struct PromiseModelDisplayTests {

  // MARK: - displayEmoji 테스트

  @Test("[P20] 이모지가 있으면 해당 이모지 반환")
  func displayEmoji_whenEmojiSet_returnsEmoji() {
    let promise = TestFactories.makePromise(emoji: "🎉")
    #expect(promise.displayEmoji == "🎉")
  }

  @Test("[P20] 이모지가 nil이면 기본 이모지 반환")
  func displayEmoji_whenEmojiNil_returnsDefault() {
    let promise = TestFactories.makePromise(emoji: nil)
    #expect(promise.displayEmoji == "📌")
  }

  @Test("[P20] 이모지가 빈 문자열이면 기본 이모지 반환")
  func displayEmoji_whenEmojiEmpty_returnsDefault() {
    let promise = TestFactories.makePromise(emoji: "")
    #expect(promise.displayEmoji == "📌")
  }

  // MARK: - locationText 테스트

  @Test("위치가 있으면 장소 이름 반환")
  func locationText_whenLocationSet_returnsName() {
    let location = TestFactories.makeLocation(name: "강남역")
    let promise = TestFactories.makePromise(location: location)
    #expect(promise.locationText == "강남역")
  }

  @Test("위치가 nil이면 기본 텍스트 반환")
  func locationText_whenLocationNil_returnsDefault() {
    let promise = TestFactories.makePromise(location: nil)
    #expect(promise.locationText == "장소 미정")
  }

  // MARK: - dateText 테스트

  @Test("오늘 날짜면 '오늘' 반환")
  func dateText_whenToday_returnsToday() {
    // 오늘 시간으로 약속 생성
    let promise = TestFactories.makePromise(startAt: Date())
    #expect(promise.dateText == "오늘")
  }

  @Test("내일 날짜면 '내일' 반환")
  func dateText_whenTomorrow_returnsTomorrow() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let promise = TestFactories.makePromise(startAt: tomorrow)
    #expect(promise.dateText == "내일")
  }

  @Test("그 외 날짜면 'M월 d일' 형식 반환")
  func dateText_whenOtherDate_returnsFormattedDate() {
    // 10일 후의 날짜
    let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
    let promise = TestFactories.makePromise(startAt: futureDate)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    let expected = formatter.string(from: futureDate)

    #expect(promise.dateText == expected)
  }

  // MARK: - timeRangeText 테스트

  @Test("종료 시간 없으면 시작 시간만 반환")
  func timeRangeText_whenNoEndAt_returnsTimeTextOnly() {
    let promise = TestFactories.makePromise(endAt: nil)
    #expect(promise.timeRangeText == promise.timeText)
  }

  // MARK: - deadlineText 테스트

  @Test("투표 마감이 지났으면 nil 반환")
  func deadlineText_whenPastDeadline_returnsNil() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(-3600))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.deadlineText == nil)
  }

  @Test("투표 마감까지 일 단위 남으면 'N일 후' 반환")
  func deadlineText_whenDaysRemaining_returnsDaysText() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(86400 + 3600))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.deadlineText == "1일 후")
  }

  @Test("투표 마감까지 시간 단위 남으면 'N시간 후' 반환")
  func deadlineText_whenHoursRemaining_returnsHoursText() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(7200 + 60))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.deadlineText == "2시간 후")
  }

  @Test("투표 마감까지 분 단위 남으면 'N분 후' 반환")
  func deadlineText_whenMinutesRemaining_returnsMinutesText() {
    let votes = TestFactories.makeVotes(until: Date().addingTimeInterval(1530))
    let promise = TestFactories.makePromise(votes: votes)
    #expect(promise.deadlineText == "25분 후")
  }

  // MARK: - shareText 테스트

  @Test("기본 공유 텍스트에 이모지, 제목, 날짜, 시간 포함")
  func shareText_containsBasicInfo() {
    let promise = TestFactories.makePromise(
      title: "점심 모임",
      emoji: "🍕"
    )
    #expect(promise.shareText.contains("🍕"))
    #expect(promise.shareText.contains("점심 모임"))
    #expect(promise.shareText.contains("📅"))
  }

  @Test("위치 있으면 공유 텍스트에 장소 포함")
  func shareText_withLocation_containsLocation() {
    let location = TestFactories.makeLocation(name: "강남역")
    let promise = TestFactories.makePromise(
      title: "저녁 모임",
      location: location
    )
    #expect(promise.shareText.contains("📍"))
    #expect(promise.shareText.contains("강남역"))
  }

  @Test("설명 있으면 공유 텍스트에 설명 포함")
  func shareText_withDescription_containsDescription() {
    let promise = TestFactories.makePromise(
      title: "회의",
      description: "월간 정기 회의"
    )
    #expect(promise.shareText.contains("월간 정기 회의"))
  }

  @Test("위치 없으면 공유 텍스트에 장소 미포함")
  func shareText_withoutLocation_doesNotContainLocationPin() {
    let promise = TestFactories.makePromise(
      title: "온라인 모임",
      location: nil
    )
    #expect(!promise.shareText.contains("📍"))
  }

  // MARK: - static empty 테스트

  @Test("empty 팩토리는 빈 제목을 가짐")
  func empty_hasEmptyTitle() {
    let promise = PromiseModel.empty
    #expect(promise.title == "")
  }
}

// MARK: - PromiseModel Response Status 테스트

@Suite("PromiseModel responseStatus 테스트")
struct PromiseModelResponseStatusTests {

  // MARK: - 불발 (failed) 테스트

  @Test("[P23] 투표 마감 + 미확정이면 불발")
  func responseStatus_whenVotingClosedAndNotConfirmed_returnsFailed() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1"],
      until: Date().addingTimeInterval(-60)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "user2")
    #expect(status == .failed)
  }

  @Test("[P24] 모든 멤버 응답 + 최소 인원 미달이면 불발")
  func responseStatus_whenAllRespondedAndNotConfirmed_returnsFailed() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1"],
      declined: ["user2", "user3"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "user1", totalGroupMembers: 3)
    #expect(status == .failed)
  }

  @Test("[P25] 남은 인원 모두 찬성해도 최소 인원 불가하면 불발")
  func responseStatus_whenCannotReachMinimum_returnsFailed() {
    // 총 4명, 2명 거절, 최소 3명 필요 -> 남은 2명이 다 찬성해도 불가
    let votes = TestFactories.makeVotes(
      accepted: [],
      declined: ["user1", "user2"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "user3", totalGroupMembers: 4)
    #expect(status == .failed)
  }

  // MARK: - 미응답 (needResponse) 테스트

  @Test("[P26] 내가 아직 투표 안 했으면 미응답")
  func responseStatus_whenNotVoted_returnsNeedResponse() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "user2")
    #expect(status == .needResponse)
  }

  // MARK: - 확정 (confirmed) 테스트

  @Test("[P26] 내가 응답했고 약속이 확정되면 confirmed")
  func responseStatus_whenRespondedAndConfirmed_returnsConfirmed() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1", "user2", "user3"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    let status = promise.responseStatus(currentUserId: "user1")
    #expect(status == .confirmed)
  }

  // MARK: - 응답 완료 (responded) 테스트

  @Test("[P26] 내가 응답했지만 미확정이면 responded")
  func responseStatus_whenRespondedButNotConfirmed_returnsResponded() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: "user1")
    #expect(status == .responded)
  }

  @Test("[P26] currentUserId가 nil이고 확정이면 confirmed")
  func responseStatus_whenNilUserAndConfirmed_returnsConfirmed() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1", "user2"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 2, votes: votes)
    let status = promise.responseStatus(currentUserId: nil)
    #expect(status == .confirmed)
  }

  @Test("[P26] currentUserId가 nil이고 미확정이면 responded")
  func responseStatus_whenNilUserAndNotConfirmed_returnsResponded() {
    let votes = TestFactories.makeVotes(
      accepted: ["user1"],
      until: Date().addingTimeInterval(3600)
    )
    let promise = TestFactories.makePromise(minimumParticipants: 3, votes: votes)
    let status = promise.responseStatus(currentUserId: nil)
    #expect(status == .responded)
  }
}

// MARK: - PromiseResponseStatus / PromiseAttendanceStatus 테스트

@Suite("PromiseResponseStatus 및 PromiseAttendanceStatus 테스트")
struct PromiseStatusEnumTests {

  @Test("PromiseResponseStatus rawValue 올바름")
  func responseStatus_rawValues() {
    #expect(PromiseResponseStatus.needResponse.rawValue == "needResponse")
    #expect(PromiseResponseStatus.responded.rawValue == "responded")
    #expect(PromiseResponseStatus.confirmed.rawValue == "confirmed")
    #expect(PromiseResponseStatus.failed.rawValue == "failed")
  }

  @Test("PromiseAttendanceStatus rawValue 올바름")
  func attendanceStatus_rawValues() {
    #expect(PromiseAttendanceStatus.pending.rawValue == "pending")
    #expect(PromiseAttendanceStatus.accepted.rawValue == "accepted")
    #expect(PromiseAttendanceStatus.declined.rawValue == "declined")
  }
}
