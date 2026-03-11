//
//  ScheduleModelValidationTests.swift
//  Clients
//
//  ScheduleModel 유효성 검증 로직 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/ScheduleModel.swift`
//  - 유효성 검증 computed properties
//
//  ## 사용처
//  - **CreateScheduleFeature**: 각 스텝 버튼 활성화 조건
//  - **EditScheduleFeature**: 수정 가능 여부 판단
//
//  ## 테스트 목적
//  - 제목, 시작/종료 시간, 최소 참가 인원 유효성 검증 로직 확인
//  - 경계값 및 예외 케이스 처리 확인
//

import Foundation
import Testing
@testable import Clients

// MARK: - ScheduleModel Validation Tests

@Suite("ScheduleModel 유효성 검증 테스트")
struct ScheduleModelValidationTests {

  // MARK: - Test Helpers

  /// 기본 테스트용 ScheduleModel 생성
  private func makeSchedule(
    title: String = "테스트 일정",
    startAt: Date = Date().addingTimeInterval(3600), // 1시간 후
    endAt: Date? = nil,
    minimumParticipants: Int = 2,
    groupId: String = "group-id",
    group: GroupModel? = nil
  ) -> ScheduleModel {
    ScheduleModel(
      id: "test-id",
      title: title,
      hostId: "host-id",
      groupId: groupId,
      group: group,
      minimumParticipants: minimumParticipants,
      startAt: startAt,
      endAt: endAt
    )
  }

  /// 테스트용 GroupModel 생성
  private func makeGroup(memberIds: [String] = ["user1", "user2"]) -> GroupModel {
    GroupModel(
      id: "group-id",
      name: "테스트 그룹",
      memberIds: memberIds,
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "host-id"
    )
  }

  // MARK: - isTitleValid 테스트

  @Test("[P1] 제목이 있으면 유효")
  func isTitleValid_withValidTitle_returnsTrue() {
    let schedule = makeSchedule(title: "점심 일정")
    #expect(schedule.isTitleValid == true)
  }

  @Test("[P1] 제목이 빈 문자열이면 무효")
  func isTitleValid_withEmptyTitle_returnsFalse() {
    let schedule = makeSchedule(title: "")
    #expect(schedule.isTitleValid == false)
  }

  @Test("[P1] 제목이 공백만 있으면 무효")
  func isTitleValid_withWhitespaceOnly_returnsFalse() {
    let schedule = makeSchedule(title: "   ")
    #expect(schedule.isTitleValid == false)
  }

  @Test("[P1] 제목 앞뒤 공백은 trim 후 검증")
  func isTitleValid_withPaddedTitle_returnsTrue() {
    let schedule = makeSchedule(title: "  점심 일정  ")
    #expect(schedule.isTitleValid == true)
  }

  // MARK: - isStartTimeValid 테스트

  @Test("[P4] 시작 시간이 미래면 유효")
  func isStartTimeValid_withFutureTime_returnsTrue() {
    let futureDate = Date().addingTimeInterval(3600) // 1시간 후
    let schedule = makeSchedule(startAt: futureDate)
    #expect(schedule.isStartTimeValid == true)
  }

  @Test("[P4] 시작 시간이 과거면 무효")
  func isStartTimeValid_withPastTime_returnsFalse() {
    let pastDate = Date().addingTimeInterval(-3600) // 1시간 전
    let schedule = makeSchedule(startAt: pastDate)
    #expect(schedule.isStartTimeValid == false)
  }

  // MARK: - isEndTimeValid 테스트

  @Test("[P5] 종료 시간 없으면(nil) 유효")
  func isEndTimeValid_withNilEndTime_returnsTrue() {
    let schedule = makeSchedule(endAt: nil)
    #expect(schedule.isEndTimeValid == true)
  }

  @Test("[P5] 종료 시간이 시작 시간보다 이후면 유효")
  func isEndTimeValid_withEndTimeAfterStart_returnsTrue() {
    let startAt = Date().addingTimeInterval(3600)
    let endAt = Date().addingTimeInterval(7200) // 시작보다 1시간 후
    let schedule = makeSchedule(startAt: startAt, endAt: endAt)
    #expect(schedule.isEndTimeValid == true)
  }

  @Test("[P5] 종료 시간이 시작 시간보다 이전이면 무효")
  func isEndTimeValid_withEndTimeBeforeStart_returnsFalse() {
    let startAt = Date().addingTimeInterval(7200)
    let endAt = Date().addingTimeInterval(3600) // 시작보다 1시간 전
    let schedule = makeSchedule(startAt: startAt, endAt: endAt)
    #expect(schedule.isEndTimeValid == false)
  }

  @Test("[P5] 종료 시간이 시작 시간과 같으면 무효")
  func isEndTimeValid_withEndTimeEqualToStart_returnsFalse() {
    let sameTime = Date().addingTimeInterval(3600)
    let schedule = makeSchedule(startAt: sameTime, endAt: sameTime)
    #expect(schedule.isEndTimeValid == false)
  }

  // MARK: - isMinimumParticipantsValid 테스트

  @Test("[P6] 최소 참가 인원 2명 이상이면 유효")
  func isMinimumParticipantsValid_withTwoOrMore_returnsTrue() {
    let schedule = makeSchedule(minimumParticipants: 2)
    #expect(schedule.isMinimumParticipantsValid == true)
  }

  @Test("[P6] 최소 참가 인원 1명이면 유효")
  func isMinimumParticipantsValid_withOne_returnsTrue() {
    let schedule = makeSchedule(minimumParticipants: 1)
    #expect(schedule.isMinimumParticipantsValid == true)
  }

  @Test("[P6] 최소 참가 인원 0명이면 무효")
  func isMinimumParticipantsValid_withZero_returnsFalse() {
    let schedule = makeSchedule(minimumParticipants: 0)
    #expect(schedule.isMinimumParticipantsValid == false)
  }

  @Test("[P6] 최소 참가 인원 음수면 무효")
  func isMinimumParticipantsValid_withNegative_returnsFalse() {
    let schedule = makeSchedule(minimumParticipants: -1)
    #expect(schedule.isMinimumParticipantsValid == false)
  }

  // MARK: - isGroupValid 테스트

  @Test("그룹 ID가 있으면 유효")
  func isGroupValid_withGroupId_returnsTrue() {
    let schedule = makeSchedule(groupId: "group-id", group: nil)
    #expect(schedule.isGroupValid == true)
  }

  @Test("그룹 객체가 있으면 유효")
  func isGroupValid_withGroup_returnsTrue() {
    let group = makeGroup()
    let schedule = makeSchedule(groupId: "", group: group)
    #expect(schedule.isGroupValid == true)
  }

  @Test("그룹 ID와 객체 모두 없으면 무효")
  func isGroupValid_withNeitherIdNorGroup_returnsFalse() {
    let schedule = makeSchedule(groupId: "", group: nil)
    #expect(schedule.isGroupValid == false)
  }

  // MARK: - canCreate 복합 테스트

  @Test("[P7] 모든 조건 충족 시 생성 가능")
  func canCreate_withAllValidConditions_returnsTrue() {
    let group = makeGroup()
    let startAt = Date().addingTimeInterval(3600)
    let endAt = Date().addingTimeInterval(7200)
    let schedule = makeSchedule(
      title: "유효한 일정",
      startAt: startAt,
      endAt: endAt,
      minimumParticipants: 2,
      group: group
    )
    #expect(schedule.canCreate == true)
  }

  @Test("[P7] 제목 무효 시 생성 불가")
  func canCreate_withInvalidTitle_returnsFalse() {
    let group = makeGroup()
    let schedule = makeSchedule(title: "", group: group)
    #expect(schedule.canCreate == false)
  }

  @Test("[P7] 시작 시간 무효 시 생성 불가")
  func canCreate_withInvalidStartTime_returnsFalse() {
    let group = makeGroup()
    let pastDate = Date().addingTimeInterval(-3600)
    let schedule = makeSchedule(startAt: pastDate, group: group)
    #expect(schedule.canCreate == false)
  }

  @Test("[P7] 그룹 없으면 생성 불가")
  func canCreate_withNoGroup_returnsFalse() {
    let schedule = makeSchedule(groupId: "", group: nil)
    #expect(schedule.canCreate == false)
  }
}
