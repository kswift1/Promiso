//
//  GroupMainStateTests.swift
//  GroupFeature
//
//  GroupMain.Feature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/GroupMain/GroupMainFeature.swift`
//  - State의 computed properties (필터링, 정렬, 그룹화)
//
//  ## 사용처
//  - **GroupMainView**: 일정 목록 표시, 필터 선택, 그룹 바
//  - **GroupMain**: 일정 필터링 및 정렬 로직
//
//  ## 테스트 목적
//  - 필터별 일정 필터링 로직 검증
//  - 정렬 순서 검증 (시간순, 마감순)
//  - 날짜별 그룹화 로직 검증
//

import Testing
import PromisoShared
@testable import GroupFeature

// MARK: - GroupMain State Tests

@Suite("GroupMain.Feature.State computed properties 테스트")
@MainActor
struct GroupMainStateTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser() -> UserPrivateModel {
    UserPrivateModel(
      userId: "current-user",
      name: "테스트",
      nickname: "테스트",
      email: "test@example.com",
      provider: "iOS",
      metadata: .init()
    )
  }

  /// 테스트용 그룹 생성
  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    memberIds: [String] = ["current-user", "user2", "user3"]
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberIds: memberIds,
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "current-user"
    )
  }

  /// 테스트용 일정 생성
  private func makeSchedule(
    id: String = "schedule-1",
    startAt: Date = Date().addingTimeInterval(3600),
    voteUntil: Date = Date().addingTimeInterval(1800),
    accepted: [String] = [],
    declined: [String] = [],
    minimumParticipants: Int = 2
  ) -> ScheduleModel {
    let votes = ScheduleVotesModel(
      accepted: accepted,
      declined: declined,
      until: voteUntil
    )
    return ScheduleModel(
      id: id,
      title: "테스트 일정 \(id)",
      hostId: "host-id",
      groupId: "group-1",
      minimumParticipants: minimumParticipants,
      votes: votes,
      startAt: startAt
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    schedules: [ScheduleModel] = [],
    selectedFilter: GroupMain.ScheduleFilter = .all,
    currentGroup: GroupModel? = nil
  ) -> GroupMain.Feature.State {
    @Shared(.inMemory("test-current-user")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.schedulesState = schedules.isEmpty ? .idle : .loaded(schedules)
    state.selectedFilter = selectedFilter
    state.currentGroup = currentGroup ?? makeGroup()
    return state
  }

  // MARK: - needResponseSchedules 테스트

  @Test("응답 필요 일정만 필터링 (현재 사용자 미응답)")
  func needResponseSchedules_filtersUnrespondedSchedules() {
    // 현재 사용자가 응답하지 않은 일정
    let needResponse = makeSchedule(id: "need", accepted: [], declined: [])

    // 현재 사용자가 이미 응답한 일정
    let alreadyResponded = makeSchedule(id: "responded", accepted: ["current-user"], declined: [])

    let state = makeState(schedules: [needResponse, alreadyResponded])

    #expect(state.needResponseSchedules.count == 1)
    #expect(state.needResponseSchedules.first?.id == "need")
  }

  @Test("응답 필요 일정 마감 임박순 정렬")
  func needResponseSchedules_sortsByVoteUntil() {
    let laterDeadline = makeSchedule(
      id: "later",
      voteUntil: Date().addingTimeInterval(7200)
    )
    let earlierDeadline = makeSchedule(
      id: "earlier",
      voteUntil: Date().addingTimeInterval(3600)
    )

    let state = makeState(schedules: [laterDeadline, earlierDeadline])

    #expect(state.needResponseSchedules.count == 2)
    #expect(state.needResponseSchedules[0].id == "earlier") // 마감 임박순
    #expect(state.needResponseSchedules[1].id == "later")
  }

  // MARK: - confirmedSchedules 테스트

  @Test("확정된 미래 일정만 필터링")
  func confirmedSchedules_filtersConfirmedFutureOnly() {
    // 확정된 미래 일정
    let confirmedFuture = makeSchedule(
      id: "confirmed-future",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    // 확정되지 않은 일정
    let notConfirmed = makeSchedule(
      id: "not-confirmed",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["user1"],
      minimumParticipants: 2
    )

    // 확정된 과거 일정
    let confirmedPast = makeSchedule(
      id: "confirmed-past",
      startAt: Date().addingTimeInterval(-3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    let state = makeState(schedules: [confirmedFuture, notConfirmed, confirmedPast])

    #expect(state.confirmedSchedules.count == 1)
    #expect(state.confirmedSchedules.first?.id == "confirmed-future")
  }

  @Test("확정 일정 시작 시간순 정렬")
  func confirmedSchedules_sortsByStartTime() {
    let laterStart = makeSchedule(
      id: "later",
      startAt: Date().addingTimeInterval(7200),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )
    let earlierStart = makeSchedule(
      id: "earlier",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    let state = makeState(schedules: [laterStart, earlierStart])

    #expect(state.confirmedSchedules.count == 2)
    #expect(state.confirmedSchedules[0].id == "earlier")
    #expect(state.confirmedSchedules[1].id == "later")
  }

  // MARK: - allSchedules 테스트

  @Test("모든 일정 시작 시간순 정렬")
  func allSchedules_sortsByStartTime() {
    let schedule3 = makeSchedule(id: "3", startAt: Date().addingTimeInterval(10800))
    let schedule1 = makeSchedule(id: "1", startAt: Date().addingTimeInterval(3600))
    let schedule2 = makeSchedule(id: "2", startAt: Date().addingTimeInterval(7200))

    let state = makeState(schedules: [schedule3, schedule1, schedule2])

    #expect(state.allSchedules.count == 3)
    #expect(state.allSchedules[0].id == "1")
    #expect(state.allSchedules[1].id == "2")
    #expect(state.allSchedules[2].id == "3")
  }

  // MARK: - filteredSchedules 테스트

  @Test("필터 변경 시 해당 필터 결과 반환")
  func filteredSchedules_returnsCorrectFilterResults() {
    let confirmedSchedule = makeSchedule(
      id: "confirmed",
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )
    let pendingSchedule = makeSchedule(id: "pending", accepted: [])

    var state = makeState(schedules: [confirmedSchedule, pendingSchedule])

    // 전체 필터
    state.selectedFilter = .all
    #expect(state.filteredSchedules.count == 2)

    // 확정 필터
    state.selectedFilter = .confirmed
    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "confirmed")
  }

  // MARK: - filterCounts 테스트

  @Test("필터별 일정 개수 계산")
  func filterCounts_calculatesCorrectCounts() {
    let confirmed1 = makeSchedule(id: "c1", accepted: ["current-user", "user1", "user2"], minimumParticipants: 2)
    let confirmed2 = makeSchedule(id: "c2", accepted: ["current-user", "user1", "user2"], minimumParticipants: 2)
    let pending = makeSchedule(id: "p1", accepted: [])

    let state = makeState(schedules: [confirmed1, confirmed2, pending])

    #expect(state.filterCounts[.all] == 3)
    #expect(state.filterCounts[.confirmed] == 2)
  }

  // MARK: - groupBarItems 테스트

  @Test("그룹 목록을 GroupBarItem으로 변환")
  func groupBarItems_convertsGroupSummaries() {
    @Shared(.inMemory("test-group-bar")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = [
      UserGroupInfo(id: "g1", name: "그룹1", hasNewActivity: true),
      UserGroupInfo(id: "g2", name: "그룹2", hasNewActivity: false)
    ]
    state.currentGroup = makeGroup(id: "g1", name: "그룹1")

    #expect(state.groupBarItems.count == 2)
    #expect(state.groupBarItems[0].id == "g1")
    #expect(state.groupBarItems[0].isSelected == true)
    #expect(state.groupBarItems[0].hasNewActivity == true)
    #expect(state.groupBarItems[1].id == "g2")
    #expect(state.groupBarItems[1].isSelected == false)
  }

  @Test("그룹 없으면 빈 배열 반환")
  func groupBarItems_whenNoGroups_returnsEmpty() {
    @Shared(.inMemory("test-no-groups-bar")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = []

    #expect(state.groupBarItems.isEmpty == true)
  }

  // MARK: - isPastFilterLoading 테스트

  @Test("과거 필터 + 로딩 중이면 true")
  func isPastFilterLoading_whenPastAndLoading_returnsTrue() {
    @Shared(.inMemory("test-past-loading")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .past
    state.pastSchedulesState = .loading

    #expect(state.isPastFilterLoading == true)
  }

  @Test("과거 필터 + 로딩 완료면 false")
  func isPastFilterLoading_whenPastAndLoaded_returnsFalse() {
    @Shared(.inMemory("test-past-loaded")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .past
    state.pastSchedulesState = .loaded([])

    #expect(state.isPastFilterLoading == false)
  }

  @Test("다른 필터면 false")
  func isPastFilterLoading_whenOtherFilter_returnsFalse() {
    @Shared(.inMemory("test-other-filter")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .all
    state.pastSchedulesState = .loading

    #expect(state.isPastFilterLoading == false)
  }

  // MARK: - filteredSchedules 추가 테스트

  @Test("needResponse 필터 시 미응답 일정만 반환")
  func filteredSchedules_needResponse_returnsUnrespondedOnly() {
    let responded = makeSchedule(id: "responded", accepted: ["current-user"])
    let unresponded = makeSchedule(id: "unresponded", accepted: [])

    var state = makeState(schedules: [responded, unresponded])
    state.selectedFilter = .needResponse

    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "unresponded")
  }
}
